// lib/screens/upload_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; 
import 'package:model_viewer_plus/model_viewer_plus.dart'; 
import 'furniture_assembly_page.dart';
class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  // ⚠️ YOUR PC IP
  final String _uploadUrl = "http://192.168.1.32:8000/upload_image";

  final TextEditingController _furnitureNameController = TextEditingController();
  File? _pickedFile;
  bool _isUploading = false;
  String _responseMessage = "";
  String? _localModelPath;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _responseMessage = "";
        _localModelPath = null;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_pickedFile == null) return;
    
    final String furnitureName = _furnitureNameController.text.trim();
    if (furnitureName.isEmpty) {
      setState(() { _responseMessage = "Error: Please enter a furniture name."; });
      return;
    }

    setState(() {
      _isUploading = true;
      _responseMessage = "Generating 3D model...";
      _localModelPath = null;
    });

    try {
      // 1. Prepare Request
      var request = http.MultipartRequest("POST", Uri.parse(_uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('file', _pickedFile!.path));

      print("Sending to $_uploadUrl...");
      
      // 2. Send and Get Response
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        // --- SUCCESS: The body IS the GLB file ---
        print("Received GLB file (${response.bodyBytes.length} bytes)");

        // 3. Save to Phone Storage
        await _saveGlbToFolder(response.bodyBytes, furnitureName);

      } else {
        print("Server Error: ${response.statusCode}");
        setState(() {
          _isUploading = false;
          _responseMessage = "Server Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      print("Network Error: $e");
      setState(() {
        _isUploading = false;
        _responseMessage = "Network Error: Check IP or Server.";
      });
    }
  }

  // --- NEW SAVING LOGIC ---
  Future<void> _saveGlbToFolder(List<int> bytes, String folderName) async {
    try {
      // 1. Get Documents Directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      
      // 2. Create Furniture Folder (e.g., "IKEA Table")
      final Directory furnitureDir = Directory("${appDir.path}/$folderName");
      if (!await furnitureDir.exists()) {
        await furnitureDir.create(recursive: true);
      }

      // 3. Generate a Filename (Timestamped)
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = "model_$timestamp.glb";
      
      // 4. Write File
      final File localFile = File("${furnitureDir.path}/$fileName");
      await localFile.writeAsBytes(bytes);

      print("Saved locally: ${localFile.path}");

      setState(() {
        _isUploading = false;
        _localModelPath = localFile.path;
        _responseMessage = "Saved to folder: '$folderName'";
      });
      
    } catch (e) {
      print("Save Error: $e");
      setState(() {
        _isUploading = false;
        _responseMessage = "Error saving file: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Image')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _furnitureNameController,
              decoration: const InputDecoration(
                labelText: "Furniture Name (Folder Name)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text("Pick Image"),
              onPressed: _pickFile,
            ),
            Center(
              child: Text(_pickedFile != null 
                  ? "Selected: ${_pickedFile!.path.split('/').last}" 
                  : "No file selected"),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: (_pickedFile == null || _isUploading) ? null : _uploadFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Generate & Save"),
            ),
            const SizedBox(height: 20),
            Text(_responseMessage, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            
            // VIEW BUTTON
            if (_localModelPath != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.view_in_ar),
                label: const Text("View in AR"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
onPressed: () async {
  // We need to recreate the Directory object for the current furniture
  final Directory appDir = await getApplicationDocumentsDirectory();
  final Directory furnitureDir = Directory("${appDir.path}/${_furnitureNameController.text.trim()}");

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FurnitureAssemblyPage(folder: furnitureDir),
    ),
  );
},
              ),
          ],
        ),
      ),
    );
  }
}