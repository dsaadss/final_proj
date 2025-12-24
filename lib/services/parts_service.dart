import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/part.dart';

class PartsService {
  // ⚠️ YOUR PC IP
  static const String baseUrl = "http://192.168.1.32:8000";

  static Future<List<AssemblyPart>> scanCroppedTable(File croppedImage) async {
    final uri = Uri.parse("$baseUrl/analyze_parts_page");

    var request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('file', croppedImage.path),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['parts'] == null) return [];

        final List<dynamic> partsJson = data['parts'];

        return partsJson.map((json) {
          return AssemblyPart(
            id: json['part_id'] ?? "UNKNOWN",
            totalQuantity: json['quantity'] ?? 1,
            imageBase64: json['image_base64'] ?? "",
            // ⚠️ FIX: Provide default values for required fields
            imageFileName: "",
            localDirectory: "",
          );
        }).toList();
      } else {
        print("Server Error: ${response.body}");
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Connection Error: $e");
      return []; // Return empty list on error instead of crashing
    }
  }
}
