import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// Ensure these imports match your actual file structure
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
  // ⚠️ YOUR PC IP (Check if this changed)
  final String _uploadUrl = "http://192.168.1.32:8000/upload_image";

  final TextEditingController _furnitureNameController =
      TextEditingController();

  List<File> _pickedFiles = []; // Assembly steps
  List<AssemblyPart> _detectedParts = []; // Hardware

  bool _isUploading = false;
  String _responseMessage = "";
  int _currentUploadIndex = 0;

  // --- 1. PICK IMAGE ---
  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null) {
      setState(() {
        _pickedFiles.add(File(result.files.single.path!));
        _responseMessage = "";
      });
    }
  }

  // --- 2. WIZARD FLOW ---
  Future<void> _pickPdfAndStartWizard() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File pdfFile = File(result.files.single.path!);

      // PHASE 1: HARDWARE SCANNING
      final List<AssemblyPart>? scannedParts = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PartSelectionPage(pdfFile: pdfFile),
        ),
      );

      if (scannedParts != null) {
        setState(() => _detectedParts = scannedParts);
      }

      // PHASE 2: ASSEMBLY STEPS
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Hardware saved! Now crop the Assembly Steps."),
        ),
      );

      final List<File>? croppedSteps = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnnotatePdfPage(pdfFile: pdfFile),
        ),
      );

      if (croppedSteps != null && croppedSteps.isNotEmpty) {
        setState(() {
          _pickedFiles.addAll(croppedSteps);
          _responseMessage = "";
        });
      }
    }
  }

  // --- UPLOAD LOGIC ---
  Future<void> _uploadAllFiles() async {
    if (_pickedFiles.isEmpty) return;

    final String furnitureName = _furnitureNameController.text.trim();
    if (furnitureName.isEmpty) {
      setState(
        () => _responseMessage = "Error: Please enter a furniture name.",
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _currentUploadIndex = 0;
    });

    try {
      // 1. Generate Models (GLB)
      for (int i = 0; i < _pickedFiles.length; i++) {
        setState(() {
          _responseMessage =
              "Processing Step ${i + 1} of ${_pickedFiles.length}...";
          _currentUploadIndex = i;
        });

        File fileToUpload = _pickedFiles[i];
        var request = http.MultipartRequest("POST", Uri.parse(_uploadUrl));
        request.files.add(
          await http.MultipartFile.fromPath('file', fileToUpload.path),
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          await _saveGlbToFolder(response.bodyBytes, furnitureName, i);
        } else {
          throw Exception("Server Error on file $i: ${response.statusCode}");
        }
      }

      // 2. Save Hardware List
      if (_detectedParts.isNotEmpty) {
        await _savePartsJsonToFolder(furnitureName);
      }

      setState(() {
        _isUploading = false;
        _responseMessage = "Success! Guide Created.";
        _pickedFiles.clear();
        _detectedParts.clear();
      });
    } catch (e) {
      print("Error: $e");
      setState(() {
        _isUploading = false;
        _responseMessage = "Error: $e";
      });
    }
  }

  Future<void> _saveGlbToFolder(
    List<int> bytes,
    String folderName,
    int index,
  ) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory furnitureDir = Directory("${appDir.path}/$folderName");
    if (!await furnitureDir.exists())
      await furnitureDir.create(recursive: true);

    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String indexPrefix = index.toString().padLeft(2, '0');
    String fileName = "model_${indexPrefix}_$timestamp.glb";

    final File localFile = File("${furnitureDir.path}/$fileName");
    await localFile.writeAsBytes(bytes);
  }

  Future<void> _savePartsJsonToFolder(String folderName) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory furnitureDir = Directory("${appDir.path}/$folderName");
      if (!await furnitureDir.exists())
        await furnitureDir.create(recursive: true);

      List<Map<String, dynamic>> cleanPartsList = [];

      for (int i = 0; i < _detectedParts.length; i++) {
        AssemblyPart part = _detectedParts[i];

        // Save Image File
        String partFileName = "part_${i}_${part.id}.png";
        File partImageFile = File("${furnitureDir.path}/$partFileName");

        // ⚠️ FIXED: Now uses the new .imageBytes getter we added to the model
        if (part.imageBytes.isNotEmpty) {
          await partImageFile.writeAsBytes(part.imageBytes);
        }

        // Save Metadata
        cleanPartsList.add({
          "id": part.id,
          "totalQuantity": part.totalQuantity,
          "usedQuantity": 0,
          "imageFileName": partFileName,
        });
      }

      final partsFile = File('${furnitureDir.path}/parts.json');
      await partsFile.writeAsString(jsonEncode(cleanPartsList));
    } catch (e) {
      print("Error saving parts: $e");
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final File item = _pickedFiles.removeAt(oldIndex);
      _pickedFiles.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Assembly Guide')),
      body: Column(
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
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text("Add Single Image"),
                        onPressed: _pickImage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text("Scan PDF Guide"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _pickPdfAndStartWizard,
                      ),
                    ),
                  ],
                ),
                if (_detectedParts.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
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
                          "Hardware List: ${_detectedParts.length} items ready",
                          style: TextStyle(color: Colors.green.shade900),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _pickedFiles.isEmpty
                ? const Center(
                    child: Text(
                      "No steps yet.\nTap 'Scan PDF Guide' to start.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ReorderableListView.builder(
                    header: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Assembly Steps Order",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    itemCount: _pickedFiles.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final file = _pickedFiles[index];
                      return ListTile(
                        key: ValueKey(file.path),
                        leading: Image.file(
                          file,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                        title: Text("Step ${index + 1}"),
                        trailing: const Icon(Icons.drag_handle),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_responseMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _responseMessage,
                      style: TextStyle(
                        color: _isUploading ? Colors.blue : Colors.green,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_pickedFiles.isEmpty || _isUploading)
                        ? null
                        : _uploadAllFiles,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE67E22),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : Text("Generate Guide (${_pickedFiles.length} Steps)"),
                  ),
                ),
                if (!_isUploading && _responseMessage.contains("Success"))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.view_in_ar),
                        label: const Text("View Assembly Guide"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }
}
