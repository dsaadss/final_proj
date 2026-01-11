import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/part.dart';

class PartsService {
  // 🛡️ Dynamic Config: No more hardcoded strings.

  static Future<List<AssemblyPart>> scanCroppedTable(File croppedImage) async {
    // 1. Fetch current settings from the Gear Menu
    final prefs = await SharedPreferences.getInstance();
    final String ip = prefs.getString('server_ip') ?? "100.x.x.x";
    final String port = prefs.getString('server_port') ?? "8000";

    // 2. Build the dynamic URI
    final String baseUrl = "http://$ip:$port";
    final uri = Uri.parse("$baseUrl/analyze_parts_page");

    var request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('file', croppedImage.path),
    );

    try {
      // 3. Send request with a generous timeout for OCR processing
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['parts'] == null) return [];

        final List<dynamic> partsJson = data['parts'];

        // 4. Map the JSON to your AssemblyPart model
        return partsJson.map((json) {
          return AssemblyPart(
            id: json['part_id'] ?? "UNKNOWN",
            totalQuantity: json['quantity'] ?? 1,
            imageBase64: json['image_base64'] ?? "",
            imageFileName: "",
            localDirectory: "",
          );
        }).toList();
      } else {
        print("❌ Server Error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("⚠️ Connection Error (PartsService): $e");
      return [];
    }
  }
}
