import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use your computer's IP address if testing on a real phone
  static const String baseUrl = "http://localhost:3000/api";
Future<void> createFarmer(Map<String, dynamic> farmerData) async {
  final response = await http.post(
    Uri.parse('$baseUrl/farmers'),
    headers: {"Content-Type": "application/json"},
    body: json.encode(farmerData), // Convert Dart Map to JSON String
  );

  if (response.statusCode != 201) {
    throw Exception("Failed to sync with API");
  }
}

}
