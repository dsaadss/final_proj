// lib/screens/test_screen.dart

import 'package:flutter/material.dart';
// This is the package we just installed.
import 'package:model_viewer_plus/model_viewer_plus.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  // This list holds the names of all your models.
  // Make sure these *exactly* match your file names.
  final List<String> modelNames = [
    'lack_1',
    'lack_2',
    'lack_3',
    'lack_4',
    'lack_5',
    'lack_6',
    'lack_7',
    'fast_finish',
  ];

  // This is the "state variable" that tracks which model is visible.
  int _currentIndex = 0;

  // Helper function to get the full path for the current model.
  String get _currentModelPath {
    return 'assets/models/${modelNames[_currentIndex]}.glb';
  }

  // Helper function to get the name of the current model.
  String get _currentModelName {
    return modelNames[_currentIndex];
  }

  // This function is called by the "next" arrow.
  void _nextModel() {
    // We use setState() to tell Flutter to rebuild the UI.
    setState(() {
      // We add 1 to the index, and use the modulo (%) operator
      // to "wrap around" to 0 if we go past the end of the list.
      _currentIndex = (_currentIndex + 1) % modelNames.length;
    });
  }

  // This function is called by the "previous" arrow.
  void _previousModel() {
    setState(() {
      // This logic is for "wrapping around" to the end of the list
      // if we are at the beginning (index 0).
      if (_currentIndex == 0) {
        _currentIndex = modelNames.length - 1;
      } else {
        _currentIndex = _currentIndex - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GLB Model Test Screen')),
      body: Column(
        // 'Column' stacks its children vertically.
        children: [
          // 'Expanded' tells its child (the ModelViewer)
          // to fill all available vertical space.
          Expanded(
            // This is the 3D model viewer widget.
            child: ModelViewer(
              // 'key' is important. By giving it a *unique* key,
              // we force Flutter to reload the widget when the model changes.
              key: ValueKey(_currentModelPath),

              // This is the "not camera" view.
              // It loads the 3D model from our assets.
              src: _currentModelPath,

              // This enables the "in the camera" (AR) view.
              // It will automatically show an AR button on supported devices.
              ar: true,

              // This adds user controls to spin the model.
              cameraControls: true,
              // This makes the model spin automatically.
              autoRotate: true,
            ),
          ),

          // This section is for the controls (arrows and text).
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // This Text widget displays the name of the current model.
                Text(
                  _currentModelName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // 'Row' stacks its children horizontally.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // This is the "previous" button.
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 32),
                      onPressed: _previousModel, // Calls our function.
                    ),

                    // This is the "next" button.
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 32),
                      onPressed: _nextModel, // Calls our function.
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
