import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentService {
  static const String _midtransBaseUrl =
      "https://app.midtrans.com/snap/v1/transactions";

  static Future<String?> createTransaction(
      Map<String, dynamic> transactionData) async {
    try {
      final url = Uri.parse(_midtransBaseUrl);
      final serverKey = dotenv.env['MIDTRANS_SERVER_KEY'] ?? '';
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$serverKey:'))}';

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": basicAuth,
      };

      print("Request Body: ${jsonEncode(transactionData)}");

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(transactionData),
      );

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['redirect_url'] != null) {
          return responseBody['redirect_url'];
        } else if (responseBody['token'] != null) {
          return 'https://app.midtrans.com/snap/v4/redirection/${responseBody['token']}';
        }
      }

      throw Exception('Failed to get valid response from Midtrans');
    } catch (e) {
      print("Payment Service Error: $e");
      rethrow;
    }
  }
}
