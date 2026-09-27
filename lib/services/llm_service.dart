import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/llm_config.dart';

class LlmException implements Exception {
  final String message;
  LlmException(this.message);
  @override
  String toString() => message;
}

class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  LlmService._internal();

  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 30);

  Uri resolveEndpoint(String baseUrl) {
    var b = baseUrl.trim();
    if (b.isEmpty) b = 'https://api.openai.com';
    if (!b.startsWith('http://') && !b.startsWith('https://')) b = 'https://$b';
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.endsWith('/chat/completions')) return Uri.parse(b);
    if (b.endsWith('/v1')) return Uri.parse('$b/chat/completions');
    return Uri.parse('$b/v1/chat/completions');
  }

  Future<String> complete({
    required LlmConfig config,
    required String prompt,
    String system = 'You are a helpful assistant.',
    double temperature = 0.4,
    int maxTokens = 1600,
  }) async {
    if (!config.isConfigured) {
      throw LlmException('LLM is not configured. Set the API URL and model in Settings.');
    }
    final uri = resolveEndpoint(config.baseUrl);
    final body = jsonEncode({
      'model': config.model.trim(),
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    HttpClientResponse resp;
    try {
      final req = await _client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (config.apiKey.trim().isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${config.apiKey.trim()}');
      }
      req.write(body);
      resp = await req.close().timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw LlmException('LLM request timed out');
    } on SocketException catch (e) {
      throw LlmException('Cannot reach LLM endpoint: ${e.message}');
    } on HttpException catch (e) {
      throw LlmException('Invalid LLM URL: ${e.message}');
    }

    final text = await resp.transform(utf8.decoder).join();

    if (resp.statusCode != 200) {
      String detail = 'HTTP ${resp.statusCode}';
      try {
        final j = jsonDecode(text);
        final err = j is Map ? j['error'] : null;
        if (err is Map && err['message'] is String) {
          detail = err['message'] as String;
        } else if (text.trim().isNotEmpty && text.length < 400) {
          detail = text.trim();
        }
      } catch (_) {}
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw LlmException('Authentication failed: $detail');
      }
      if (resp.statusCode == 404) {
        throw LlmException('Endpoint not found: $detail');
      }
      throw LlmException('LLM error: $detail');
    }

    try {
      final j = jsonDecode(text);
      String? content;
      if (j is Map && j['choices'] is List && (j['choices'] as List).isNotEmpty) {
        final first = (j['choices'] as List).first;
        if (first is Map && first['message'] is Map) {
          final msg = first['message'] as Map;
          if (msg['content'] is String) content = msg['content'] as String;
        }
      }
      if (content != null && content.trim().isNotEmpty) return content.trim();
      throw LlmException('LLM returned an empty response');
    } on LlmException {
      rethrow;
    } catch (_) {
      throw LlmException('Could not parse LLM response');
    }
  }

  Future<bool> testConnection(LlmConfig config) async {
    final reply = await complete(
      config: config,
      prompt: 'Reply with the single word: OK',
      system: 'You are a connection test.',
      temperature: 0,
      maxTokens: 8,
    );
    return reply.isNotEmpty;
  }
}
