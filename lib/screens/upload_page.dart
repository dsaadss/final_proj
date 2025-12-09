// lib/screens/upload_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'furniture_assembly_page.dart';
import 'annotate_pdf_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  // ⚠️ YOUR PC IP
  final String _uploadUrl = "http://192.168.1.32:8000/upload_image";

  final TextEditingController _furnitureNameController =
      TextEditingController();

  // --- CHANGE 1: List of files instead of single file ---
  List<File> _pickedFiles = [];

  bool _isUploading = false;
  String _responseMessage = "";

  // Track upload progress (e.g., "Uploading 1 of 3...")
  int _currentUploadIndex = 0;

  // --- PICK IMAGE (Single add) ---
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

  // --- PICK PDF (Batch add) ---
  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File pdfFile = File(result.files.single.path!);

      // Expect a LIST of files back
      final List<File>? croppedImages = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnnotatePdfPage(pdfFile: pdfFile),
        ),
      );

      if (croppedImages != null && croppedImages.isNotEmpty) {
        setState(() {
          _pickedFiles.addAll(croppedImages);
          _responseMessage = "";
        });
      }
    }
  }

  // --- UPLOAD LOGIC (Sequential) ---
  Future<void> _uploadAllFiles() async {
    if (_pickedFiles.isEmpty) return;

    final String furnitureName = _furnitureNameController.text.trim();
    if (furnitureName.isEmpty) {
      setState(() {
        _responseMessage = "Error: Please enter a furniture name.";
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _currentUploadIndex = 0;
    });

    try {
      // Loop through all files in order
      for (int i = 0; i < _pickedFiles.length; i++) {
        setState(() {
          _responseMessage =
              "Processing Step ${i + 1} of ${_pickedFiles.length}...";
          _currentUploadIndex = i;
        });

        File fileToUpload = _pickedFiles[i];

        // 1. Prepare Request
        var request = http.MultipartRequest("POST", Uri.parse(_uploadUrl));
        request.files.add(
          await http.MultipartFile.fromPath('file', fileToUpload.path),
        );

        print("Uploading file $i...");
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          // 2. Save with INDEX in filename (model_00.glb, model_01.glb)
          // This ensures the Assembly Player plays them in correct order.
          await _saveGlbToFolder(response.bodyBytes, furnitureName, i);
        } else {
          throw Exception("Server Error on file $i: ${response.statusCode}");
        }
      }

      // Done!
      setState(() {
        _isUploading = false;
        _responseMessage = "Success! Generated ${_pickedFiles.length} models.";
        _pickedFiles.clear(); // Clear list after success
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
    if (!await furnitureDir.exists()) {
      await furnitureDir.create(recursive: true);
    }

    // Naming convention: model_00_timestamp.glb
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String indexPrefix = index.toString().padLeft(2, '0'); // "00", "01", "02"
    String fileName = "model_${indexPrefix}_$timestamp.glb";

    final File localFile = File("${furnitureDir.path}/$fileName");
    await localFile.writeAsBytes(bytes);
    print("Saved: ${localFile.path}");
  }

  // --- REORDER LOGIC ---
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
          // Top Section: Inputs
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
                        label: const Text("Add Image"),
                        onPressed: _pickImage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text("Add PDF"),
                        onPressed: _pickPdf,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(),

          // Middle Section: Reorderable List
          Expanded(
            child: _pickedFiles.isEmpty
                ? const Center(
                    child: Text(
                      "No images selected.\nAdd images to create steps.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ReorderableListView.builder(
                    header: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Drag to reorder • Swipe right to delete",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    itemCount: _pickedFiles.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final file = _pickedFiles[index];

                      // We wrap the ListTile in a Dismissible widget
                      return Dismissible(
                        // Key must be unique for every file path
                        key: ValueKey(file.path),

                        // Allow swiping only from Left to Right (Start to End)
                        direction: DismissDirection.startToEnd,

                        // What happens when you swipe
                        onDismissed: (direction) {
                          setState(() {
                            _pickedFiles.removeAt(index);
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Step ${index + 1} deleted"),
                            ),
                          );
                        },

                        // The red background behind the item
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),

                        // The actual list item
                        child: ListTile(
                          key: ValueKey(file.path), // Provide key here too
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                              image: DecorationImage(
                                image: FileImage(file),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text("Step ${index + 1}"),
                          // We remove the drag handle icon because the whole tile is draggable,
                          // and it looks cleaner with the swipe action.
                          trailing: const Icon(
                            Icons.drag_handle,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Section: Upload Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
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
                      textAlign: TextAlign.center,
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
                              strokeWidth: 2,
                            ),
                          )
                        : Text("Generate ${_pickedFiles.length} Models"),
                  ),
                ),

                // View Button (Only if done uploading and name is filled)
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
