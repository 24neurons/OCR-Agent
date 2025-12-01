// lib/services/chatgpt_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'secret_config.dart';

class ChatGPTService {
  final String _apiKey = openAIApiKey;

  /// Gửi danh sách messages tới OpenAI. Messages now support List<Map<String, dynamic>>
  /// messages: [{ 'role': 'user' | 'assistant' | 'system', 'content': String | List<Map<String, dynamic>> }, ...]
  Future<String> sendChat(List<Map<String, dynamic>> messages) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final body = {
      // NOTE: gpt-4o-mini supports vision inputs
      'model': 'gpt-4o-mini',
      'messages': messages,
      'temperature': 0.7,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>;
    if (choices.isEmpty) {
      throw Exception('No choices returned from OpenAI');
    }

    final msg = choices[0]['message'] as Map<String, dynamic>;
    final content = msg['content'];

    if (content is String) {
      return content;
    }

    // Fallback for non-string content
    return content.toString();
  }
}
