import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🆕 Import

import 'furniture_assembly_page.dart';
import 'annotate_pdf_page.dart';
import 'part_selection_page.dart';
import '../models/part.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final TextEditingController _furnitureNameController =
      TextEditingController();

  List<AssemblyStep> _pickedSteps = [];
  List<AssemblyPart> _detectedParts = [];
  File? _originalPdfFile;

  bool _isUploading = false;
  String _responseMessage = "";

  // --- 🪄 PDF WIZARD FLOW (Unchanged) ---
  Future<void> _pickPdfAndStartWizard() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      _originalPdfFile = File(result.files.single.path!);
      final List<AssemblyPart>? scannedParts = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PartSelectionPage(pdfFile: _originalPdfFile!),
        ),
      );
      if (scannedParts != null) setState(() => _detectedParts = scannedParts);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Hardware saved! Now crop the Assembly Steps."),
          backgroundColor: Colors.blue,
        ),
      );

      final List<AssemblyStep>? croppedSteps = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnnotatePdfPage(pdfFile: _originalPdfFile!),
        ),
      );

      if (croppedSteps != null && croppedSteps.isNotEmpty) {
        setState(() {
          _pickedSteps.addAll(croppedSteps);
          _responseMessage = "";
        });
      }
    }
  }

  // --- 🚀 DYNAMIC UPLOAD LOGIC ---
  Future<void> _uploadAllFiles() async {
    if (_pickedSteps.isEmpty) return;

    final String furnitureName = _furnitureNameController.text.trim();
    if (furnitureName.isEmpty) {
      setState(
        () => _responseMessage = "Error: Please enter a furniture name.",
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 🆕 FETCH SAVED CONFIG
      final prefs = await SharedPreferences.getInstance();
      final String ip = prefs.getString('server_ip') ?? "192.168.1.32";
      final String port = prefs.getString('server_port') ?? "8000";
      final String uploadUrl =
          "http://$ip:$port/upload_image"; // 👈 Dynamic URL

      for (int i = 0; i < _pickedSteps.length; i++) {
        setState(
          () => _responseMessage =
              "Processing Step ${i + 1} of ${_pickedSteps.length}...",
        );

        File fileToUpload = _pickedSteps[i].imageFile;
        var request = http.MultipartRequest(
          "POST",
          Uri.parse(uploadUrl),
        ); // 👈 Use dynamic URL
        request.files.add(
          await http.MultipartFile.fromPath('file', fileToUpload.path),
        );

        var streamedResponse = await request.send().timeout(
          const Duration(seconds: 60),
        );
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          await _unzipAndSaveModels(response.bodyBytes, furnitureName, i);
        } else {
          throw Exception("Server Error on step $i: ${response.statusCode}");
        }
      }

      if (_detectedParts.isNotEmpty)
        await _savePartsJsonToFolder(furnitureName);
      if (_originalPdfFile != null) await _savePdfAndMap(furnitureName);

      setState(() {
        _isUploading = false;
        _responseMessage = "Success! Guide Created.";
        _pickedSteps.clear();
        _detectedParts.clear();
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _responseMessage = "Error: $e";
      });
    }
  }

  // --- 📦 UNZIP HELPER (Unchanged) ---
  Future<void> _unzipAndSaveModels(
    List<int> zipBytes,
    String folderName,
    int stepIndex,
  ) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory furnitureDir = Directory("${appDir.path}/$folderName");
    if (!await furnitureDir.exists())
      await furnitureDir.create(recursive: true);

    final Directory tempDir = await getTemporaryDirectory();
    final File tempZipFile = File('${tempDir.path}/temp_step_$stepIndex.zip');
    await tempZipFile.writeAsBytes(zipBytes);

    final Directory tempExtractDir = Directory(
      '${tempDir.path}/temp_extract_$stepIndex',
    );
    if (await tempExtractDir.exists())
      await tempExtractDir.delete(recursive: true);
    await tempExtractDir.create();

    try {
      await ZipFile.extractToDirectory(
        zipFile: tempZipFile,
        destinationDir: tempExtractDir,
      );
      String indexPrefix = stepIndex.toString().padLeft(2, '0');
      final List<FileSystemEntity> extractedFiles = tempExtractDir.listSync();

      for (var file in extractedFiles) {
        if (file is File) {
          String fileName = file.path.split(Platform.pathSeparator).last;
          String newFileName = "step_${indexPrefix}_$fileName";
          await file.copy('${furnitureDir.path}/$newFileName');
        }
      }
    } finally {
      if (await tempZipFile.exists()) await tempZipFile.delete();
      if (await tempExtractDir.exists())
        await tempExtractDir.delete(recursive: true);
    }
  }

  // --- 💾 DATA PERSISTENCE (Unchanged) ---
  Future<void> _savePartsJsonToFolder(String folderName) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory furnitureDir = Directory("${appDir.path}/$folderName");
    List<Map<String, dynamic>> cleanPartsList = [];
    for (int i = 0; i < _detectedParts.length; i++) {
      AssemblyPart part = _detectedParts[i];
      String partFileName = "part_${i}_${part.id}.png";
      if (part.imageBytes.isNotEmpty)
        await File(
          "${furnitureDir.path}/$partFileName",
        ).writeAsBytes(part.imageBytes);
      cleanPartsList.add({
        "id": part.id,
        "totalQuantity": part.totalQuantity,
        "usedQuantity": 0,
        "imageFileName": partFileName,
      });
    }
    await File(
      '${furnitureDir.path}/parts.json',
    ).writeAsString(jsonEncode(cleanPartsList));
  }

  Future<void> _savePdfAndMap(String folderName) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory furnitureDir = Directory("${appDir.path}/$folderName");
    await _originalPdfFile!.copy("${furnitureDir.path}/guide.pdf");
    List<Map<String, dynamic>> stepMap = [];
    for (int i = 0; i < _pickedSteps.length; i++) {
      stepMap.add({"stepIndex": i, "pdfPage": _pickedSteps[i].pageNumber});
    }
    await File(
      "${furnitureDir.path}/steps.json",
    ).writeAsString(jsonEncode(stepMap));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pickedSteps.removeAt(oldIndex);
      _pickedSteps.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA),
      appBar: AppBar(
        title: const Text('Create Assembly Guide'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _furnitureNameController,
                            decoration: const InputDecoration(
                              labelText: "Furniture Name",
                              prefixIcon: Icon(Icons.inventory_2),
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text("Scan PDF Guide & Start Wizard"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isUploading
                                ? null
                                : _pickPdfAndStartWizard,
                          ),
                          if (_detectedParts.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Hardware List: ${_detectedParts.length} items detected",
                                    style: TextStyle(
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (_pickedSteps.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(
                              Icons.auto_awesome_motion,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No steps created yet.\nUse the 'Scan PDF' button to begin.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        header: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text(
                            "Drag to Reorder Steps",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        itemCount: _pickedSteps.length,
                        onReorder: _onReorder,
                        itemBuilder: (context, index) {
                          final step = _pickedSteps[index];
                          return ListTile(
                            key: ValueKey(step.imageFile.path),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(
                                step.imageFile,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              "Step ${index + 1}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text("Manual Page: ${step.pageNumber}"),
                            trailing: const Icon(Icons.drag_handle),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_responseMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _responseMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isUploading ? Colors.blue : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_pickedSteps.isEmpty || _isUploading)
                          ? null
                          : _uploadAllFiles,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE67E22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "Generate Full 3D Guide (${_pickedSteps.length} Steps)",
                            ),
                    ),
                  ),
                  if (!_isUploading && _responseMessage.contains("Success"))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.view_in_ar),
                          label: const Text("Launch Assembly Guide"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            final Directory appDir =
                                await getApplicationDocumentsDirectory();
                            final Directory furnitureDir = Directory(
                              "${appDir.path}/${_furnitureNameController.text.trim()}",
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FurnitureAssemblyPage(folder: furnitureDir),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
