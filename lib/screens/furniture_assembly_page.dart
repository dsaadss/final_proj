// lib/screens/furniture_assembly_page.dart

import 'dart:io';
import 'dart:convert'; // For JSON decoding
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

// Imports for parts logic
import '../models/part.dart';
import '../widgets/parts_tracker_sheet.dart';

class FurnitureAssemblyPage extends StatefulWidget {
  final Directory folder;

  const FurnitureAssemblyPage({super.key, required this.folder});

  @override
  State<FurnitureAssemblyPage> createState() => _FurnitureAssemblyPageState();
}

class _FurnitureAssemblyPageState extends State<FurnitureAssemblyPage> {
  List<File> _steps = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  // --- NEW: List of hardware parts ---
  List<AssemblyPart> _projectParts = [];

  Color _currentBackgroundColor = Colors.grey.shade200;

  final List<Color> _palette = [
    Colors.grey.shade200,
    Colors.white,
    Colors.black,
    const Color(0xFF1A1A1A),
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.orange.shade100,
    Colors.purple.shade100,
  ];

  @override
  void initState() {
    super.initState();
    _loadAssemblySteps();
    _loadParts(); // <--- NEW: Load hardware list
  }

  // --- NEW: Load parts from JSON ---
// Inside _FurnitureAssemblyPageState

  Future<void> _loadParts() async {
    try {
      final partsFile = File('${widget.folder.path}/parts.json');
      if (await partsFile.exists()) {
        final String content = await partsFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);

        setState(() {
          _projectParts = jsonList.map((j) {
            final part = AssemblyPart.fromJson(j);
            // ⚠️ CRITICAL: Tell the part where the images are stored!
            part.localDirectory = widget.folder.path;
            return part;
          }).toList();
        });
      }
    } catch (e) {
      print("Error loading parts.json: $e");
    }
  }

  Future<void> _loadAssemblySteps() async {
    try {
      final List<FileSystemEntity> entities = widget.folder.listSync();
      final List<File> glbFiles = entities
          .where((e) => e is File && e.path.endsWith('.glb'))
          .cast<File>()
          .toList();

      glbFiles.sort((a, b) => a.path.compareTo(b.path));

      setState(() {
        _steps = glbFiles;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading steps: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextStep() {
    setState(() {
      if (_currentIndex < _steps.length - 1) {
        _currentIndex++;
      }
    });
  }

  void _previousStep() {
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
      }
    });
  }

  // --- NEW: Open the tracker sheet ---
  void _openPartsTracker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow it to be taller if needed
      builder: (context) => PartsTrackerSheet(
        parts: _projectParts,
        onUpdate: () {
          // You could save progress to disk here if you want
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.folder.path.split('/').last;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(
          child: Text("No assembly steps found in this folder."),
        ),
      );
    }

    final File currentFile = _steps[_currentIndex];
    final String currentStepName =
        "Step ${_currentIndex + 1} of ${_steps.length}";

    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _currentBackgroundColor.computeLuminance() > 0.5
              ? Colors.black
              : Colors.white,
        ),
        titleTextStyle: TextStyle(
          color: _currentBackgroundColor.computeLuminance() > 0.5
              ? Colors.black
              : Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // --- NEW: FLOATING ACTION BUTTON FOR TOOLBOX ---
     floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,

      floatingActionButton: _projectParts.isEmpty
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.red[700],
              onPressed: _openPartsTracker,
              child: const Icon(Icons.handyman, color: Colors.white),
            ),

      body: Stack(
        children: [
          // 1. BACKGROUND
          Container(
            color: _currentBackgroundColor,
            width: double.infinity,
            height: double.infinity,
          ),

          // 2. MODEL VIEWER
          ModelViewer(
            key: ValueKey(currentFile.path),
            src: 'file://${currentFile.path}',
            ar: true,
            cameraControls: true,
            autoRotate: false,
            backgroundColor: Colors.transparent,
          ),

          // 3. COLOR PALETTE (Top)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _palette.length,
                itemBuilder: (context, index) {
                  final color = _palette[index];
                  final isSelected = _currentBackgroundColor == color;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentBackgroundColor = color;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.grey.shade400,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 20,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. CONTROLS OVERLAY (Lifted High for AR Button Space)
          Positioned(
            left: 20,
            right: 20,
            bottom: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30), // Pill shape
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Step Counter Title
                  Text(
                    currentStepName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // PREV BUTTON
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(), // Rounded ends
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _currentIndex > 0 ? _previousStep : null,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text("Prev"),
                      ),

                      const SizedBox(width: 10),

                      // NEXT BUTTON
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(), // Rounded ends
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _currentIndex < _steps.length - 1
                            ? _nextStep
                            : null,
                        child: Row(
                          children: const [
                            Text("Next"),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
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
