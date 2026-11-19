import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdate {
  final String currentVersion, latestVersion, releaseNotes;
  final Uri apkUrl;
  final String expectedSha256;
  const AppUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkUrl,
    required this.expectedSha256,
  });

  bool get isAvailable => _compareVersions(latestVersion, currentVersion) > 0;

  static const String _manifestUrl =
      'https://raw.githubusercontent.com/leoblanchart92-hub/Jarvis/main/updates/latest.json';

  static Future<AppUpdate?> check() async {
    try {
      final response = await http.get(Uri.parse(_manifestUrl),
          headers: {'Cache-Control': 'no-cache'}).timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw Exception('Serveur de mise à jour indisponible (HTTP ${response.statusCode}).');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final package = await PackageInfo.fromPlatform();
      final version = data['version'] as String? ?? '';
      final url = Uri.tryParse(data['apk_url'] as String? ?? '');
      final hash = (data['sha256'] as String? ?? '').toLowerCase();
      if (!_validVersion(version) || url == null || url.scheme != 'https' ||
          url.host != 'github.com' || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw Exception('Le manifeste de mise à jour est invalide.');
      }

      return AppUpdate(
        currentVersion: package.version,
        latestVersion: version,
        releaseNotes: data['notes'] as String? ?? 'Mise à jour ASTRA.',
        apkUrl: url,
        expectedSha256: hash,
      );
    } on SocketException {
      throw Exception('Connexion Internet indisponible. Vérifie ton réseau puis réessaie.');
    } on http.ClientException {
      throw Exception('Impossible de joindre le serveur de mises à jour.');
    } on FormatException {
      throw Exception('Le manifeste de mise à jour est illisible.');
    }
  }

  Future<void> downloadAndInstall(void Function(double) onProgress) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', apkUrl)..headers['Accept'] = 'application/octet-stream';
      final response = await client.send(request).timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) {
        throw Exception('Téléchargement impossible (HTTP ${response.statusCode}).');
      }

      final builder = BytesBuilder(copy: false);
      var received = 0;
      final total = response.contentLength ?? 0;
      await for (final chunk in response.stream.timeout(const Duration(seconds: 45))) {
        builder.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0).toDouble());
      }
      final bytes = builder.takeBytes();
      if (bytes.length < 100 * 1024) {
        throw Exception('Le fichier APK semble incomplet.');
      }
      final actualHash = sha256.convert(bytes).toString();
      if (actualHash != expectedSha256) {
        throw Exception('Vérification SHA-256 échouée : APK rejeté.');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ASTRA-$latestVersion.apk');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        throw Exception(result.message.isEmpty ? 'Android n’a pas pu ouvrir l’installateur.' : result.message);
      }
    } on SocketException {
      throw Exception('Connexion interrompue pendant le téléchargement.');
    } finally {
      client.close();
    }
  }

  static bool _validVersion(String v) => RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v);

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
