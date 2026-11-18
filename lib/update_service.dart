import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdate {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final Uri releaseUrl;

  const AppUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.releaseUrl,
  });

  bool get isAvailable =>
      _compareVersions(latestVersion, currentVersion) > 0;

  static Future<AppUpdate?> check() async {
    final response = await http.get(
      Uri.parse(
        'https://api.github.com/repos/leoblanchart92-hub/Jarvis/releases/latest',
      ),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('GitHub a répondu avec le code ${response.statusCode}.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final package = await PackageInfo.fromPlatform();
    final tag = (data['tag_name'] as String? ?? '').replaceFirst(
      RegExp(r'^[vV]'),
      '',
    );
    final url = Uri.tryParse(data['html_url'] as String? ?? '');
    if (tag.isEmpty || url == null || !url.hasScheme) return null;

    return AppUpdate(
      currentVersion: package.version,
      latestVersion: tag,
      releaseNotes: data['body'] as String? ?? 'Aucune note de version.',
      releaseUrl: url,
    );
  }

  Future<bool> openRelease() => launchUrl(
        releaseUrl,
        mode: LaunchMode.externalApplication,
      );

  static int _compareVersions(String a, String b) {
    final left = a.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    final right = b.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final x = i < left.length ? left[i] : 0;
      final y = i < right.length ? right[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}
