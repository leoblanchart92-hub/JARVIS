import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdate {
  final String currentVersion, latestVersion, releaseNotes;
  final Uri apkUrl;
  const AppUpdate({required this.currentVersion, required this.latestVersion, required this.releaseNotes, required this.apkUrl});
  bool get isAvailable => _compareVersions(latestVersion, currentVersion) > 0;

  static Future<AppUpdate?> check() async {
    final response = await http.get(Uri.parse('https://api.github.com/repos/leoblanchart92-hub/Jarvis/releases/latest'),
      headers: const {'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'})
      .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw Exception('GitHub a répondu avec le code ${response.statusCode}.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final package = await PackageInfo.fromPlatform();
    final tag = (data['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^[vV]'), '');
    final assets = data['assets'] as List<dynamic>? ?? [];
    Map<String, dynamic>? apk;
    for (final item in assets) {
      if (item is Map<String, dynamic> && (item['name'] as String? ?? '').toLowerCase().endsWith('.apk')) {
        apk = item; break;
      }
    }
    final url = Uri.tryParse(apk?['browser_download_url'] as String? ?? '');
    if (tag.isEmpty || url == null || url.scheme != 'https') {
      throw Exception('La Release GitHub ne contient pas de fichier APK valide.');
    }
    return AppUpdate(currentVersion: package.version, latestVersion: tag,
      releaseNotes: data['body'] as String? ?? 'Aucune note de version.', apkUrl: url);
  }

  Future<void> downloadAndInstall(void Function(double) onProgress) async {
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', apkUrl)).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) throw Exception('Téléchargement impossible (HTTP ${response.statusCode}).');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ASTRA-$latestVersion.apk');
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength ?? 0;
      await for (final chunk in response.stream) {
        sink.add(chunk); received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
      }
      await sink.flush(); await sink.close();
      if (await file.length() < 100 * 1024) throw Exception('Le fichier APK semble incomplet.');
      final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) throw Exception(result.message.isEmpty ? 'Android n’a pas pu ouvrir l’installateur.' : result.message);
    } finally { client.close(); }
  }

  static int _compareVersions(String a, String b) {
    final left = a.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    final right = b.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final x = i < left.length ? left[i] : 0, y = i < right.length ? right[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}
