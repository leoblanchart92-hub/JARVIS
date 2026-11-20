import 'package:llamadart/llamadart.dart';

/// Local ASTRA brain. The GGUF is downloaded once and cached by llamadart.
class AstraBrain {
  static const modelSource =
      'hf://bartowski/SmolLM2-1.7B-Instruct-GGUF/SmolLM2-1.7B-Instruct-Q4_K_M.gguf';

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
