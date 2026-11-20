import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lightweight web lookup via DuckDuckGo Instant Answer API.
/// Internet lookup is optional; the local model remains usable offline.
class AstraWebSearch {
  static Future<String> search(String query) async {
    final uri = Uri.https('api.duckduckgo.com', '/', {
      'q': query,
      'format': 'json',
      'no_html': '1',
      'skip_disambig': '1',
    });
    final response = await http.get(uri, headers: {
      'User-Agent': 'ASTRA-Android/1.0',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Recherche Internet indisponible (HTTP ${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = <String>[];
    final abstractText = (data['AbstractText'] as String? ?? '').trim();
    final abstractUrl = (data['AbstractURL'] as String? ?? '').trim();
    if (abstractText.isNotEmpty) {
      results.add('Résumé: $abstractText\nSource: $abstractUrl');
    }
    void addTopics(dynamic raw) {
      if (raw is! List) return;
      for (final topic in raw) {
        if (results.length >= 6) break;
        if (topic is Map<String, dynamic>) {
          final text = (topic['Text'] as String? ?? '').trim();
          final url = (topic['FirstURL'] as String? ?? '').trim();
          if (text.isNotEmpty) results.add('$text\nSource: $url');
          addTopics(topic['Topics']);
        }
      }
    }
    addTopics(data['RelatedTopics']);
    if (results.isEmpty) return 'Aucun résultat de recherche exploitable n’a été retourné.';
    return results.take(6).join('\n\n');
  }
}
