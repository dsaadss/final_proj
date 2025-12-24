import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crop_image/crop_image.dart';
import 'package:image/image.dart' as img;

import '../models/part.dart';
import '../services/parts_service.dart';

class PartSelectionPage extends StatefulWidget {
  final File pdfFile;
  const PartSelectionPage({super.key, required this.pdfFile});

  @override
  State<PartSelectionPage> createState() => _PartSelectionPageState();
}

class _PartSelectionPageState extends State<PartSelectionPage> {
  PdfController? _pdfController;
  List<AssemblyPart> _collectedParts = [];
  bool _isAnalyzing = false; // To show loading spinner during OCR

  @override
  void initState() {
    super.initState();
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.pdfFile.path),
    );
  }

  // --- HELPER: Prepare Image for Cropping ---
  Future<Uint8List?> _renderPdfPageForCropping() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pageNum = _pdfController!.page;
      final doc = await PdfDocument.openFile(widget.pdfFile.path);
      final page = await doc.getPage(pageNum);

      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();

      if (!mounted) return null;
      Navigator.pop(context); // Close loading

      if (pageImage == null) return null;

      // Add white background (PDFs are often transparent)
      final img.Image? original = img.decodeImage(pageImage.bytes);
      if (original == null) return pageImage.bytes;

      final whiteBg = img.Image(width: original.width, height: original.height);
      img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(whiteBg, original);

      return img.encodePng(whiteBg);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print("Error rendering: $e");
      return null;
    }
  }

  // --- 1. LOGIC: SCAN FULL TABLE (Original) ---
  Future<void> _scanFullTable() async {
    final imageBytes = await _renderPdfPageForCropping();
    if (imageBytes == null) return;

    if (!mounted) return;

    // Open Cropper
    final File? croppedFile = await showDialog(
      context: context,
      builder: (context) => CropDialog(imageBytes: imageBytes),
    );

    if (croppedFile == null) return;

    // Send to Server
    setState(() => _isAnalyzing = true);
    try {
      List<AssemblyPart> newParts = await PartsService.scanCroppedTable(
        croppedFile,
      );

      setState(() {
        _collectedParts.insertAll(0, newParts); // Add to top
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Detected ${newParts.length} parts.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Scan failed.")));
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // --- 2. LOGIC: ADD SINGLE MANUAL ITEM (New) ---
  Future<void> _addSingleManualItem() async {
    final imageBytes = await _renderPdfPageForCropping();
    if (imageBytes == null) return;

    if (!mounted) return;

    // Open Cropper
    final File? croppedFile = await showDialog(
      context: context,
      builder: (context) => CropDialog(imageBytes: imageBytes),
    );

    if (croppedFile == null) return;

    setState(() => _isAnalyzing = true);

    String detectedId = "";
    int detectedQty = 1;

    try {
      // 1. Try to detect text in this specific crop
      List<AssemblyPart> results = await PartsService.scanCroppedTable(
        croppedFile,
      );

      // 2. If OCR found something, use its text data
      if (results.isNotEmpty) {
        detectedId = results.first.id; // Use best guess
        detectedQty = results.first.totalQuantity;
      }

      // 3. REGARDLESS of OCR, use the USER'S CROP as the image
      // This ensures the image matches exactly what they cropped.
      final userCropBytes = await croppedFile.readAsBytes();

      setState(() {
        _collectedParts.insert(
          0,
          AssemblyPart(
            id: detectedId,
            totalQuantity: detectedQty,
            imageBase64: "", // We provide explicit bytes below
            imageFileName:
                "manual_${DateTime.now().millisecondsSinceEpoch}.png",
            localDirectory: "",
            explicitBytes: userCropBytes, // ✅ Use User's Crop
          ),
        );
      });

      if (!mounted) return;
      if (detectedId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Part added. Please fill in ID.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Part added & Text detected!")),
        );
      }
    } catch (e) {
      // Even if OCR fails, add the part with the image
      final userCropBytes = await croppedFile.readAsBytes();
      setState(() {
        _collectedParts.insert(
          0,
          AssemblyPart(
            id: "",
            totalQuantity: 1,
            imageBase64: "",
            imageFileName: "manual_err.png",
            localDirectory: "",
            explicitBytes: userCropBytes,
          ),
        );
      });
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Hardware"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _collectedParts),
            child: const Text(
              "DONE",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---------------------------------------------------------
          // 1. TOP LIST (Horizontal)
          // ---------------------------------------------------------
          Container(
            height: 160,
            color: Colors.blue.shade50,
            child: _collectedParts.isEmpty && !_isAnalyzing
                ? const Center(
                    child: Text(
                      "No parts yet.\nUse buttons below to add.",
                      textAlign: TextAlign.center,
                    ),
                  )
                : _isAnalyzing
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _collectedParts.length,
                    padding: const EdgeInsets.all(10),
                    itemBuilder: (context, index) {
                      final part = _collectedParts[index];
                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            // Image & Delete
                            Expanded(
                              child: Stack(
                                children: [
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: part.imageBytes.isNotEmpty
                                          ? Image.memory(
                                              part.imageBytes,
                                              fit: BoxFit.contain,
                                            )
                                          : const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => _collectedParts.removeAt(index),
                                      ),
                                      child: const Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            // ID Input
                            SizedBox(
                              height: 30,
                              child: TextField(
                                controller: TextEditingController(
                                  text: part.id,
                                ),
                                decoration: const InputDecoration(
                                  labelText: "ID",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (v) =>
                                    _collectedParts[index] = AssemblyPart(
                                      id: v,
                                      totalQuantity: part.totalQuantity,
                                      imageBase64: "",
                                      imageFileName: "",
                                      localDirectory: "",
                                      explicitBytes: part.memoryBytes,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Qty Input
                            SizedBox(
                              height: 30,
                              child: TextField(
                                controller: TextEditingController(
                                  text: part.totalQuantity.toString(),
                                ),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Qty",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 12),
                                onChanged: (v) {
                                  int q = int.tryParse(v) ?? part.totalQuantity;
                                  _collectedParts[index] = AssemblyPart(
                                    id: part.id,
                                    totalQuantity: q,
                                    imageBase64: "",
                                    imageFileName: "",
                                    localDirectory: "",
                                    explicitBytes: part.memoryBytes,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ---------------------------------------------------------
          // 2. PDF VIEWER
          // ---------------------------------------------------------
          Expanded(
            child: PdfView(
              controller: _pdfController!,
              backgroundDecoration: const BoxDecoration(color: Colors.white),
            ),
          ),
        ],
      ),

      // ---------------------------------------------------------
      // 3. BOTTOM BUTTONS ROW
      // ---------------------------------------------------------
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // BUTTON 1: Add Manual Item
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _addSingleManualItem,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text("Add Item"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // BUTTON 2: Scan Full Table
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _scanFullTable,
                icon: const Icon(Icons.crop_free),
                label: const Text("Scan Table"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// REUSABLE CROP DIALOG (Returns File only)
// ==================================================================
class CropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const CropDialog({super.key, required this.imageBytes});

  @override
  State<CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<CropDialog> {
  final CropController _controller = CropController();
  bool _isProcessing = false;

  Future<void> _confirmCrop() async {
    setState(() => _isProcessing = true);
    try {
      final image = await _controller.croppedBitmap();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/temp_crop_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context, file); // Return the file to parent
    } catch (e) {
      print("Crop error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Crop Selection"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _confirmCrop,
              child: const Text(
                "USE THIS",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: CropImage(
        controller: _controller,
        image: Image.memory(widget.imageBytes),
        alwaysMove: true,
      ),
    );
  }
}
