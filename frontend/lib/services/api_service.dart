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
      return "http://127.0.0.1:8000";
    }
    return "http://127.0.0.1:8000";
  }

  static Stream<ChatResponse> streamMessage(String message) async* {
    final url = Uri.parse('$baseUrl/chat');

    final request = http.Request('POST', url)
      ..headers.addAll({"Content-Type": "application/json"})
      ..body = jsonEncode({"message": message});

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
