import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:pdfx/pdfx.dart';

import '../models/part.dart';
import '../widgets/parts_tracker_sheet.dart';

class FurnitureAssemblyPage extends StatefulWidget {
  final Directory folder;

  const FurnitureAssemblyPage({super.key, required this.folder});

  @override
  State<FurnitureAssemblyPage> createState() => _FurnitureAssemblyPageState();
}

class _FurnitureAssemblyPageState extends State<FurnitureAssemblyPage> {
  // --- 3D DATA ---
  List<File> _steps = []; // Only stores the "White" (default) files
  int _currentIndex = 0;
  bool _isLoading = true;

  // 🆕 COLOR VARIANT STATE
  String _selectedVariant = "white"; // "white", "black", "wood"

  // --- HARDWARE & PDF DATA ---
  List<AssemblyPart> _projectParts = [];
  PdfController? _pdfController;
  Map<int, int> _stepToPageMap = {};

  // State flags
  bool _isPdfVisible = false;
  bool _hasPdf = false;
  bool _isSplitMode = false;

  bool get _isPdfReady => _hasPdf && _pdfController != null;

  // --- VISUALS ---
  Color _currentBackgroundColor = Colors.grey.shade200;
  final List<Color> _palette = [
    Colors.grey.shade200,
    Colors.white,
    Colors.black,
    const Color(0xFF1A1A1A), // Dark Grey
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.orange.shade100,
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadAssemblySteps();
    await _loadParts();
    await _loadPdfAndMetadata();
  }

  Future<void> _loadAssemblySteps() async {
    try {
      final List<FileSystemEntity> entities = widget.folder.listSync();

      // 🆕 FILTER: Only load the 'white' (default) models into the list
      // We will infer the names of black/wood models from these.
      final List<File> glbFiles = entities
          .where((e) => e is File && e.path.endsWith('_white.glb'))
          .cast<File>()
          .toList();

      glbFiles.sort((a, b) => a.path.compareTo(b.path));

      setState(() {
        _steps = glbFiles;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading steps: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadParts() async {
    try {
      final partsFile = File('${widget.folder.path}/parts.json');
      if (await partsFile.exists()) {
        final String content = await partsFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        setState(() {
          _projectParts = jsonList.map((j) {
            final part = AssemblyPart.fromJson(j);
            part.localDirectory = widget.folder.path;
            return part;
          }).toList();
        });
      }
    } catch (e) {
      print("Error parts: $e");
    }
  }

  Future<void> _loadPdfAndMetadata() async {
    final pdfFile = File('${widget.folder.path}/guide.pdf');
    if (await pdfFile.exists()) {
      setState(() {
        _pdfController = PdfController(
          document: PdfDocument.openFile(pdfFile.path),
        );
        _hasPdf = true;
      });
    }
    final metaFile = File('${widget.folder.path}/steps.json');
    if (await metaFile.exists()) {
      try {
        final content = await metaFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        final Map<int, int> tempMap = {};
        for (var item in jsonList) {
          if (item['stepIndex'] != null && item['pdfPage'] != null) {
            tempMap[item['stepIndex']] = item['pdfPage'];
          }
        }
        setState(() => _stepToPageMap = tempMap);
      } catch (e) {
        print("Error steps.json: $e");
      }
    }
  }

  void _jumpPdfToCurrentStep() {
    final int? page = _stepToPageMap[_currentIndex];
    if (page == null || _pdfController == null) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _pdfController!.jumpToPage(page);
    });
  }

  void _jumpToStep(int index) {
    setState(() => _currentIndex = index);
    if (_isPdfVisible) _jumpPdfToCurrentStep();
  }

  void _nextStep() {
    if (_currentIndex < _steps.length - 1) _jumpToStep(_currentIndex + 1);
  }

  void _previousStep() {
    if (_currentIndex > 0) _jumpToStep(_currentIndex - 1);
  }

  void _openPartsTracker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          PartsTrackerSheet(parts: _projectParts, onUpdate: () {}),
    );
  }

  // 🆕 HELPER: Get correct file based on color selection
  File _getCurrentVariantFile() {
    final File baseFile = _steps[_currentIndex];
    // Replace "_white.glb" with "_black.glb" or "_wood.glb"
    String newPath = baseFile.path.replaceAll(
      '_white.glb',
      '_$_selectedVariant.glb',
    );

    File variantFile = File(newPath);
    // Fallback to base file if variant doesn't exist
    return variantFile.existsSync() ? variantFile : baseFile;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_steps.isEmpty)
      return const Scaffold(body: Center(child: Text("No steps found.")));

    final File currentFile = _getCurrentVariantFile();

    // THE RELIABLE GOOGLE VIEWER
    Widget modelView = ModelViewer(
      key: ValueKey(currentFile.path), // Forces reload when file changes
      src: 'file://${currentFile.path}',
      ar: true,
      cameraControls: true,
      autoRotate: false,
      backgroundColor: Colors.transparent, // Let container color show through
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Step ${_currentIndex + 1} of ${_steps.length}"),
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
      body: Stack(
        children: [
          // 1. BACKGROUND LAYER (Controls the contrast)
          Positioned.fill(child: Container(color: _currentBackgroundColor)),

          // 2. MAIN CONTENT (Split Logic)
          Positioned.fill(
            child: _isSplitMode
                ? Column(
                    children: [
                      // TOP: 3D MODEL
                      Expanded(flex: 1, child: modelView),
                      // BOTTOM: PDF PANEL
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: Colors.white,
                          child: PdfView(
                            controller: _pdfController!,
                            scrollDirection: Axis.vertical,
                          ),
                        ),
                      ),
                    ],
                  )
                : modelView, // Full screen model
          ),

          // 3. COLOR PALETTE (Background) - Top Left
          if (!_isSplitMode)
            Positioned(
              top: 110,
              left: 0,
              right: 80, // Leave space for variant buttons on right
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
                      onTap: () =>
                          setState(() => _currentBackgroundColor = color),
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
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
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

          // 🆕 4. VARIANT SELECTOR (Wood/White/Black) - Top Right
          if (!_isSplitMode)
            Positioned(
              top: 110,
              right: 16,
              child: Column(
                children: [
                  _variantButton("white", Colors.white, "Original"),
                  const SizedBox(height: 10),
                  _variantButton("wood", const Color(0xFF8B4513), "Wood"),
                  const SizedBox(height: 10),
                  _variantButton("black", const Color(0xFF282828), "Black"),
                ],
              ),
            ),

          // 5. NAVIGATION ARROWS
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _currentIndex > 0 ? _previousStep : null,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 40),
                ElevatedButton(
                  onPressed: _currentIndex < _steps.length - 1
                      ? _nextStep
                      : null,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.orange,
                  ),
                  child: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),

          // 6. ACTION BUTTONS (Compact Round Icons)
          Positioned(
            left: 20,
            bottom: 20,
            child: Row(
              children: [
                if (_hasPdf && !_isSplitMode) ...[
                  FloatingActionButton(
                    heroTag: "pdf_btn",
                    mini: true,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    onPressed: () {
                      if (!_isPdfReady) return;
                      setState(() => _isPdfVisible = !_isPdfVisible);
                      if (_isPdfVisible) _jumpPdfToCurrentStep();
                    },
                    child: Icon(
                      _isPdfVisible ? Icons.visibility_off : Icons.menu_book,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (_hasPdf) ...[
                  FloatingActionButton(
                    heroTag: "split_btn",
                    mini: true,
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      if (!_isPdfReady) return;
                      setState(() {
                        _isSplitMode = !_isSplitMode;
                        _isPdfVisible = _isSplitMode;
                      });
                      if (_isSplitMode) _jumpPdfToCurrentStep();
                    },
                    child: Icon(
                      _isSplitMode
                          ? Icons.close_fullscreen
                          : Icons.vertical_split,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (_projectParts.isNotEmpty)
                  FloatingActionButton(
                    heroTag: "parts_btn",
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    onPressed: _openPartsTracker,
                    child: const Icon(Icons.handyman),
                  ),
              ],
            ),
          ),

          // 7. POPUP MANUAL (Non-Split Mode)
          if (_isPdfReady && _isPdfVisible && !_isSplitMode)
            Positioned.fill(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isPdfVisible = false),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                  Center(
                    child: Material(
                      elevation: 16,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 300,
                        height: 450,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Manual Page",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      setState(() => _isPdfVisible = false),
                                ),
                              ],
                            ),
                            const Divider(),
                            Expanded(
                              child: PdfView(controller: _pdfController!),
                            ),
                          ],
                        ),
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

  // 🆕 BUTTON HELPER
  Widget _variantButton(String variant, Color color, String tooltip) {
    bool isSelected = _selectedVariant == variant;
    return GestureDetector(
      onTap: () => setState(() => _selectedVariant = variant),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.grey.shade400,
              width: isSelected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 4,
                color: Colors.black26,
                offset: Offset(0, 2),
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
      ),
    );
  }
}
