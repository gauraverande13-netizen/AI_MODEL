import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ChatResponse {
  final String reply;
  final String? toolUsed;

  ChatResponse({required this.reply, this.toolUsed});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      reply: json['reply'] ?? '',
      toolUsed: json['tool_used'],
    );
  }
}

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://127.0.0.1:8000";
    }
    if (Platform.isAndroid || Platform.isIOS) {
      // Physical mobile device (aur emulator dono) ke liye PC ka Local IP
      return "http://172.16.21.161:8000";
    }
    return "http://127.0.0.1:8000";
  }

  static Future<ChatResponse> sendMessage(String message) async {
    final url = Uri.parse('$baseUrl/chat');

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"message": message}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ChatResponse.fromJson(data);
    } else {
      throw Exception("Server Error: ${response.statusCode}");
    }
  }
}
