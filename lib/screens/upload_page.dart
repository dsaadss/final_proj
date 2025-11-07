// lib/screens/upload_page.dart
import 'package:flutter/material.dart';

class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload PDF or Image'),
        backgroundColor: Colors.white, // Example styling
        elevation: 1,
      ),
      body: Center(
        // We will build the UI from fig 14 here later.
        child: Text('Upload Page - Coming Soon!'),
      ),
    );
  }
}
