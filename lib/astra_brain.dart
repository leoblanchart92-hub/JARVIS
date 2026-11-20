import 'package:llamadart/llamadart.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local ASTRA brain. The GGUF is downloaded once and cached by llamadart.
class AstraBrain {
  static const modelSource =
      'hf://bartowski/SmolLM2-1.7B-Instruct-GGUF/SmolLM2-1.7B-Instruct-Q4_K_M.gguf';


  static const _memoryKey = 'astra_explicit_memories_v1';

  Future<List<String>> getMemories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_memoryKey) ?? <String>[];
  }

  Future<void> remember(String fact) async {
    final cleaned = fact.trim();
    if (cleaned.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_memoryKey) ?? <String>[];
    if (!list.any((m) => m.toLowerCase() == cleaned.toLowerCase())) {
      list.add(cleaned);
      if (list.length > 40) list.removeAt(0);
      await prefs.setStringList(_memoryKey, list);
    }
  }

  Future<List<String>> relevantMemories(String query) async {
    final list = await getMemories();
    if (list.isEmpty) return const <String>[];
    final stop = <String>{'dans','avec','pour','une','des','les','est','que','qui','quoi','mon','ma','mes','ton','ta','tes','the','and','with','from','this','that'};
    final words = query.toLowerCase().split(RegExp(r'[^a-zà-ÿ0-9]+')).where((w) => w.length > 2 && !stop.contains(w)).toSet();
    if (words.isEmpty) return list.take(5).toList();
    final scored = list.map((m) {
      final lower = m.toLowerCase();
      final score = words.where((w) => lower.contains(w)).length;
      return (memory: m, score: score);
    }).where((x) => x.score > 0).toList()..sort((a,b) => b.score.compareTo(a.score));
    return scored.take(5).map((x) => x.memory).toList();
  }

  Future<int> forget(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_memoryKey) ?? <String>[];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return 0;
    final before = list.length;
    list.removeWhere((m) => m.toLowerCase().contains(q));
    await prefs.setStringList(_memoryKey, list);
    return before - list.length;
  }

  Future<void> clearMemories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_memoryKey);
  }

  LlamaEngine? _engine;
  ChatSession? _chat;
  ModelDownloadCancelToken? _cancelToken;

  bool get isLoaded => _engine != null;
  bool get isDownloading => _cancelToken != null;

  Future<void> load({void Function(double)? onProgress}) async {
    if (_engine != null) return;
    final cancelToken = ModelDownloadCancelToken();
    _cancelToken = cancelToken;
    try {
      final engine = await LlamaEngine.load(
        LlamaModel(ModelSource.parse(modelSource)),
        params: const ModelParams(contextSize: 2048, gpuLayers: 0),
        download: ModelLoadOptions(cancelToken: cancelToken, resume: true),
        onProgress: (progress) {
          final fraction = progress.fraction;
          if (fraction != null) onProgress?.call(fraction.clamp(0.0, 1.0));
        },
      );
      _engine = engine;
      _chat = ChatSession(
        engine,
        maxContextTokens: 1536,
        systemPrompt:
            'Tu es ASTRA, une assistante IA utile, claire et amicale. Réponds en français par défaut, '
            'avec des réponses concises et honnêtes. Tu es exécutée localement sur un téléphone. '
            'Si tu ne sais pas, dis-le clairement. N’invente pas de faits.',
      );
    } finally {
      _cancelToken = null;
    }
  }

  void cancelDownload() => _cancelToken?.cancel();

  Stream<String> replyStream(String prompt) async* {
    final chat = _chat;
    if (chat == null) throw StateError('Le cerveau ASTRA n’est pas chargé.');
    await for (final chunk in chat.create([LlamaTextContent(prompt)])) {
      if (chunk.text.isNotEmpty) yield chunk.text;
    }
  }

  Future<void> unload() async {
    _chat = null;
    final engine = _engine;
    _engine = null;
    if (engine != null) await engine.dispose();
  }
}
