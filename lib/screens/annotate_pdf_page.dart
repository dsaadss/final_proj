import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

enum AnnotationTool { rectangle, freehand }

class AnnotatePdfPage extends StatefulWidget {
  final File pdfFile;

  const AnnotatePdfPage({super.key, required this.pdfFile});

  @override
  State<AnnotatePdfPage> createState() => _AnnotatePdfPageState();
}

class _AnnotatePdfPageState extends State<AnnotatePdfPage> {
  Uint8List? _pageBytes;
  Rect? _selection;
  Offset? _dragStart;
  Uint8List? _croppedBytes;
  Size? _imageDisplaySize;

  AnnotationTool _currentTool = AnnotationTool.rectangle;
  List<Offset> _freehandPoints = [];

  final List<Uint8List> _savedCrops = [];

  PdfDocument? _pdfDoc;
  int _currentPage = 1;
  int _pageCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      final fileBytes = await widget.pdfFile.readAsBytes();
      final doc = await PdfDocument.openData(fileBytes);
      _pdfDoc = doc;
      _pageCount = doc.pagesCount;
      _currentPage = 1;
      await _renderCurrentPage();
    } catch (e) {
      print("Error opening PDF: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pdfDoc?.close();
    super.dispose();
  }

  Future<void> _renderCurrentPage() async {
    if (_pdfDoc == null) return;
    setState(() => _isLoading = true);

    final page = await _pdfDoc!.getPage(_currentPage);
    final imgPage = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.png,
    );

    await page.close();

    if (mounted && imgPage != null) {
      setState(() {
        _pageBytes = imgPage.bytes;
        _selection = null;
        _croppedBytes = null;
        _freehandPoints = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _goToPage(int newPage) async {
    if (newPage < 1 || newPage > _pageCount) return;
    _currentPage = newPage;
    await _renderCurrentPage();
  }

  bool _pointInPolygon(double x, double y, List<Offset> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;
      final intersect =
          ((yi > y) != (yj > y)) &&
          (x <
              (xj - xi) *
                      (y - yi) /
                      ((yj - yi).abs() < 1e-9 ? 1e-9 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  Future<void> _cropSelection() async {
    if (_pageBytes == null || _imageDisplaySize == null) return;

    Rect selectionRect;
    if (_currentTool == AnnotationTool.rectangle) {
      if (_selection == null) return;
      selectionRect = _selection!;
    } else {
      if (_freehandPoints.isEmpty) return;
      double minX = _freehandPoints.first.dx, maxX = minX;
      double minY = _freehandPoints.first.dy, maxY = minY;
      for (final p in _freehandPoints) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      selectionRect = Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    final original = img.decodeImage(_pageBytes!);
    if (original == null) return;

    final display = _imageDisplaySize!;
    final scaleX = original.width / display.width;
    final scaleY = original.height / display.height;

    int left = (selectionRect.left * scaleX).round().clamp(
      0,
      original.width - 1,
    );
    int top = (selectionRect.top * scaleY).round().clamp(
      0,
      original.height - 1,
    );
    int right = (selectionRect.right * scaleX).round().clamp(
      left + 1,
      original.width,
    );
    int bottom = (selectionRect.bottom * scaleY).round().clamp(
      top + 1,
      original.height,
    );

    final width = right - left;
    final height = bottom - top;
    if (width <= 0 || height <= 0) return;

    img.Image cropped = img.copyCrop(
      original,
      x: left,
      y: top,
      width: width,
      height: height,
    );

    if (_currentTool == AnnotationTool.freehand && _freehandPoints.isNotEmpty) {
      final polygon = _freehandPoints.map((p) {
        final px = p.dx * scaleX - left;
        final py = p.dy * scaleY - top;
        return Offset(px, py);
      }).toList();

      for (int y = 0; y < cropped.height; y++) {
        for (int x = 0; x < cropped.width; x++) {
          if (!_pointInPolygon(x + 0.5, y + 0.5, polygon)) {
            cropped.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
      }
    }

    // --- GREY BACKGROUND FIX ---
    // Create new image and fill with Grey (127,127,127) to fix AI alpha issues
    final flattened = img.Image(width: cropped.width, height: cropped.height);
    img.fill(flattened, color: img.ColorRgb8(127, 127, 127));
    img.compositeImage(flattened, cropped);
    // ---------------------------

    final bytes = Uint8List.fromList(img.encodePng(flattened));
    setState(() {
      _croppedBytes = bytes;
      _savedCrops.add(bytes);
    });
  }

  Future<void> _confirmCrops() async {
    if (_savedCrops.isEmpty) {
      Navigator.pop(context, <File>[]);
      return;
    }

    List<File> resultFiles = [];
    final dir = await getTemporaryDirectory();

    for (int i = 0; i < _savedCrops.length; i++) {
      final bytes = _savedCrops[i];
      final file = File(
        '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}_$i.png',
      );
      await file.writeAsBytes(bytes);
      resultFiles.add(file);
    }

    if (mounted) Navigator.pop(context, resultFiles);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Parts'),
        actions: [
          IconButton(
            tooltip: "Rectangle Tool",
            icon: Icon(
              Icons.crop_square,
              color: _currentTool == AnnotationTool.rectangle
                  ? Colors.orange
                  : null,
            ),
            onPressed: () =>
                setState(() => _currentTool = AnnotationTool.rectangle),
          ),
          IconButton(
            tooltip: "Freehand Tool",
            icon: Icon(
              Icons.edit,
              color: _currentTool == AnnotationTool.freehand
                  ? Colors.orange
                  : null,
            ),
            onPressed: () =>
                setState(() => _currentTool = AnnotationTool.freehand),
          ),

          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          const SizedBox(width: 8),

          IconButton(
            tooltip: "Confirm Selection",
            icon: const Icon(Icons.check, color: Colors.blue),
            onPressed: _cropSelection,
          ),

          if (_savedCrops.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.check_circle, color: Colors.green),
                label: Text(
                  "FINISH (${_savedCrops.length})",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _confirmCrops,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_pageCount > 1)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _currentPage > 1
                              ? () => _goToPage(_currentPage - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page $_currentPage / $_pageCount'),
                        IconButton(
                          onPressed: _currentPage < _pageCount
                              ? () => _goToPage(_currentPage + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _pageBytes != null ? 1 / 1.414 : 1,
                              child: _pageBytes == null
                                  ? const SizedBox()
                                  : LayoutBuilder(
                                      builder: (context, innerConstraints) {
                                        _imageDisplaySize = Size(
                                          innerConstraints.maxWidth,
                                          innerConstraints.maxHeight,
                                        );
                                        return GestureDetector(
                                          onPanStart: (details) {
                                            final local = details.localPosition;
                                            setState(() {
                                              if (_currentTool ==
                                                  AnnotationTool.rectangle) {
                                                _dragStart = local;
                                                _selection = Rect.fromPoints(
                                                  local,
                                                  local,
                                                );
                                              } else {
                                                _freehandPoints = [local];
                                              }
                                            });
                                          },
                                          onPanUpdate: (details) {
                                            final local = details.localPosition;
                                            setState(() {
                                              if (_currentTool ==
                                                  AnnotationTool.rectangle) {
                                                _selection = Rect.fromPoints(
                                                  _dragStart!,
                                                  local,
                                                );
                                              } else {
                                                // --- 1. SMOOTHING FIX ---
                                                // Don't record tiny movements (< 5 pixels)
                                                if (_freehandPoints.isEmpty ||
                                                    (local -
                                                                _freehandPoints
                                                                    .last)
                                                            .distance >
                                                        5.0) {
                                                  _freehandPoints.add(local);
                                                }
                                              }
                                            });
                                          },
                                          onPanEnd: (details) {
                                            _dragStart = null;
                                            // --- 2. AUTO-CLOSE FIX ---
                                            // Connect end back to start
                                            if (_currentTool ==
                                                    AnnotationTool.freehand &&
                                                _freehandPoints.isNotEmpty) {
                                              setState(() {
                                                _freehandPoints.add(
                                                  _freehandPoints.first,
                                                );
                                              });
                                            }
                                          },
                                          child: Stack(
                                            children: [
                                              Image.memory(
                                                _pageBytes!,
                                                fit: BoxFit.fill,
                                              ),
                                              CustomPaint(
                                                painter: _SelectionPainter(
                                                  rect: _selection,
                                                  freehandPoints:
                                                      _freehandPoints,
                                                  tool: _currentTool,
                                                ),
                                                size: Size.infinite,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                if (_savedCrops.isNotEmpty)
                  Container(
                    height: 100,
                    color: Colors.grey.shade100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 16, top: 8),
                          child: Text(
                            "Parts Extracted:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(8),
                            scrollDirection: Axis.horizontal,
                            itemCount: _savedCrops.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 1,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        _savedCrops[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _savedCrops.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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

class _SelectionPainter extends CustomPainter {
  final Rect? rect;
  final List<Offset> freehandPoints;
  final AnnotationTool tool;

  _SelectionPainter({
    required this.rect,
    required this.freehandPoints,
    required this.tool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // --- 3. VISUAL STYLE FIX ---
    // Smoother, thicker lines
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.redAccent;

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.redAccent.withOpacity(0.2);

    if (tool == AnnotationTool.rectangle && rect != null) {
      canvas.drawRect(rect!, fill);
      canvas.drawRect(rect!, border);
    } else if (tool == AnnotationTool.freehand && freehandPoints.isNotEmpty) {
      final path = Path()
        ..moveTo(freehandPoints.first.dx, freehandPoints.first.dy);

      for (final p in freehandPoints.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }

      // Visually close the path
      path.close();

      canvas.drawPath(path, fill);
      canvas.drawPath(path, border);
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => true;
}
