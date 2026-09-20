import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      return "http://127.0.0.1:8000";
    }
    return "http://127.0.0.1:8000";
  }

  static Future<bool> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {"username": username, "password": password},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      return true;
    }
    return false;
  }

  static Future<bool> register(String username, String password) async {
    final url = Uri.parse('$baseUrl/register');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"username": username, "password": password}),
    );
    return response.statusCode == 200;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  static Stream<ChatResponse> streamMessage(String message) async* {
    final url = Uri.parse('$baseUrl/chat');

    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('llm_provider') ?? 'gemini';
    final apiKey = prefs.getString('api_key') ?? '';
    final token = prefs.getString('jwt_token') ?? '';

    final request = http.Request('POST', url)
      ..headers.addAll({
        "Content-Type": "application/json",
        if (apiKey.isNotEmpty) "X-API-Key": apiKey,
        if (token.isNotEmpty) "Authorization": "Bearer $token",
      })
      ..body = jsonEncode({
        "message": message,
        "provider": provider,
      });

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      throw Exception("Server Error: ${streamedResponse.statusCode}");
    }

    final stream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      if (line.trim().isEmpty) continue;
      
      try {
        final data = jsonDecode(line);
        if (data.containsKey('error')) {
          throw Exception(data['error']);
        }
        
        yield ChatResponse(
          reply: data['chunk'] ?? '',
          toolUsed: data['tool_used'],
        );
      } catch (e) {
        // Skip malformed JSON lines
        continue;
      }
    }
  }
}
