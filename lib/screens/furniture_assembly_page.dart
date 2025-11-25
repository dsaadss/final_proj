// lib/screens/furniture_assembly_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class FurnitureAssemblyPage extends StatefulWidget {
  final Directory folder; // We pass the specific furniture folder here

  const FurnitureAssemblyPage({super.key, required this.folder});

  @override
  State<FurnitureAssemblyPage> createState() => _FurnitureAssemblyPageState();
}

class _FurnitureAssemblyPageState extends State<FurnitureAssemblyPage> {
  List<File> _steps = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssemblySteps();
  }

  // Scan the folder and find all GLB files
  Future<void> _loadAssemblySteps() async {
    try {
      final List<FileSystemEntity> entities = widget.folder.listSync();
      
      // Filter for only .glb files
      final List<File> glbFiles = entities
          .where((e) => e is File && e.path.endsWith('.glb'))
          .cast<File>()
          .toList();

      // Sort them by name (or date) so Step 1 comes before Step 2
      // Since we named them with timestamps (model_123...), sorting by name works perfectly.
      glbFiles.sort((a, b) => a.path.compareTo(b.path));

      setState(() {
        _steps = glbFiles;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading steps: $e");
      setState(() { _isLoading = false; });
    }
  }

  void _nextStep() {
    setState(() {
      // Stop at the last step
      if (_currentIndex < _steps.length - 1) {
        _currentIndex++;
      }
    });
  }

  void _previousStep() {
    setState(() {
      // Stop at the first step
      if (_currentIndex > 0) {
        _currentIndex--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get the folder name for the title (e.g., "IKEA Table")
    final String title = widget.folder.path.split('/').last;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text("No assembly steps found in this folder.")),
      );
    }

    // Get current file
    final File currentFile = _steps[_currentIndex];
    final String currentStepName = "Step ${_currentIndex + 1} of ${_steps.length}";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent, // Transparent for AR feel
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black), // Dark icons
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      extendBodyBehindAppBar: true, // Body goes behind AppBar

      // Use STACK to layer UI on top of AR
      body: Stack(
        children: [
          // BOTTOM LAYER: The AR Model Viewer
          ModelViewer(
            // Key forces reload when step changes
            key: ValueKey(currentFile.path), 
            src: 'file://${currentFile.path}', // Load local file
            ar: true,
            cameraControls: true,
            autoRotate: false, // User controls rotation
          ),

          // TOP LAYER: The Controls Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6), // Semi-transparent dark background
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Step Counter Title
                  Text(
                    currentStepName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // File name (optional, smaller text)
                  Text(
                    currentFile.path.split('/').last,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  
                  const SizedBox(height: 20),

                  // Control Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // PREVIOUS BUTTON
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _currentIndex > 0 ? _previousStep : null, // Disable if at start
                        icon: const Icon(Icons.arrow_back),
                        label: const Text("Previous"),
                      ),

                      // NEXT BUTTON
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange, // Highlight "Next"
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        // If at end, show "Finish" or disable
                        onPressed: _currentIndex < _steps.length - 1 ? _nextStep : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text("Next"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}