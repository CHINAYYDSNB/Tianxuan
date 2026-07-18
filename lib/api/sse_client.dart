import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class SseClient {
  /// Connect to an SSE endpoint and stream data lines.
  /// [path] is relative to /api/v2/, e.g. "/containers/search/log".
  /// [queryParams] are appended as query string.
  /// Returns a Stream of data lines (without "data: " prefix).
  static Stream<String> connect(String path,
      {Map<String, String>? queryParams}) async* {
    final serverUrl = kIsWeb
        ? 'http://localhost:25568'
        : (await StorageService.instance.getServerUrl() ?? '');
    if (serverUrl.isEmpty) throw Exception('Server URL not configured');

    final apiKey = await StorageService.instance.getApiKey() ?? '';
    if (apiKey.isEmpty) throw Exception('API Key not configured');

    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000)
        .floor()
        .toString();
    final raw = '1panel$apiKey$timestamp';
    final token = md5.convert(utf8.encode(raw)).toString();

    final uri = Uri.parse('$serverUrl/api/v2$path')
        .replace(queryParameters: queryParams);

    var retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        final request = http.Request('GET', uri);
        request.headers['1Panel-Token'] = token;
        request.headers['1Panel-Timestamp'] = timestamp;

        final response = await http.Client().send(request);
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          for (final line in chunk.split('\n')) {
            if (line.startsWith('data: ')) {
              yield line.substring(6);
            }
          }
        }
        break; // stream ended normally
      } catch (e) {
        retries++;
        if (retries >= maxRetries) {
          throw Exception('SSE connection failed after $maxRetries retries: $e');
        }
        await Future.delayed(Duration(seconds: retries * 2));
      }
    }
  }
}
