import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class AssemblyPart {
  final String id;
  final int totalQuantity;
  int usedQuantity; // Mutable
  final String imageBase64;
  final String imageFileName;
  // Non-final so we can set it after loading from JSON
  String localDirectory;
  Uint8List? _cachedBytes;

  AssemblyPart({
    required this.id,
    required this.totalQuantity,
    this.usedQuantity = 0,
    required this.imageBase64,
    required this.imageFileName,
    required this.localDirectory,
    Uint8List? explicitBytes,
  }) {
    if (explicitBytes != null) {
      _cachedBytes = explicitBytes;
    }
  }

  // ⚠️ NEW: Factory to load from JSON (Fixes FurnitureAssemblyPage error)
  factory AssemblyPart.fromJson(Map<String, dynamic> json) {
    return AssemblyPart(
      id: json['id'] ?? "UNKNOWN",
      totalQuantity: json['totalQuantity'] ?? 0,
      usedQuantity: json['usedQuantity'] ?? 0,
      // Handle cases where these might be missing in old JSON
      imageBase64: json['imageBase64'] ?? "",
      imageFileName: json['imageFileName'] ?? "",
      localDirectory: "", // We will set this manually after loading
    );
  }

  // Getter for image bytes
  Uint8List get imageBytes => memoryBytes ?? Uint8List(0);

  bool get isComplete => usedQuantity >= totalQuantity;
  bool get isFileBased => imageFileName.isNotEmpty && localDirectory.isNotEmpty;

  File? get fileOnDisk {
    if (!isFileBased) return null;
    return File('$localDirectory/$imageFileName');
  }

  Uint8List? get memoryBytes {
    if (_cachedBytes != null) return _cachedBytes;
    if (imageBase64.isNotEmpty) {
      try {
        _cachedBytes = base64Decode(imageBase64);
        return _cachedBytes;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
