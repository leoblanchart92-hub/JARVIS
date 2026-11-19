import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'update_service.dart';

void main() => runApp(const AstraApp());

const cyan = Color(0xFF54E8FF);
const blue = Color(0xFF168DFF);
const bg = Color(0xFF050B13);

class AstraApp extends StatelessWidget {
  const AstraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'ASTRA',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark), useMaterial3: true),
    home: const AssistantHome(),
  );
}

class AssistantHome extends StatefulWidget {
  const AssistantHome({super.key});
  @override
  State<AssistantHome> createState() => _AssistantHomeState();
}

class _AssistantHomeState extends State<AssistantHome> with TickerProviderStateMixin {
  late final AnimationController pulse;
  late final AnimationController orbit;
  final message = TextEditingController();
  final scroll = ScrollController();
  final messages = <ChatMessage>[ChatMessage('ASTRA', 'Bonjour. Je suis prête. Comment puis-je vous aider ?', false)];
  bool showChat = true, listening = false, checking = false, downloading = false, voiceReady = false, wakeMode = false, wakeSession = false;
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  double progress = 0;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    orbit = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    initVoice();
  }


  Future<void> initVoice() async {
    try {
      voiceReady = await speech.initialize(onStatus: (status) { if (mounted && status == 'done') { setState(() => listening = false); if (wakeMode && !wakeSession) restartWakeListening(); } }, onError: (_) { if (mounted) setState(() => listening = false); });
      await tts.setLanguage('fr-FR');
      await tts.setSpeechRate(0.48);
      await tts.setVolume(1.0);
      if (mounted) setState(() {});
    } catch (_) { voiceReady = false; if (mounted) setState(() {}); }
  }


  Future<void> toggleListening() async {
    if (!voiceReady) { await initVoice(); }
    if (!voiceReady) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reconnaissance vocale indisponible. Vérifie les permissions du microphone.'))); return; }
    if (wakeMode) { await toggleWakeMode(); return; }
    if (listening) { await speech.stop(); if (mounted) setState(() => listening = false); return; }
    setState(() => listening = true);
    await speech.listen(localeId: 'fr_FR', listenFor: const Duration(seconds: 30), pauseFor: const Duration(seconds: 3), onResult: (result) {
      if (!mounted) return;
      message.text = result.recognizedWords;
      message.selection = TextSelection.collapsed(offset: message.text.length);
      if (result.finalResult) { setState(() => listening = false); send(); }
      else setState(() {});
    });
  }


  // Wake-word prototype: listens for "ASTRA" while the app is open.
  Future<void> startWakeListening() async {
    if (!wakeMode || !voiceReady || listening || wakeSession) return;
    try {
      listening = true;
      await speech.listen(
        localeId: 'fr_FR',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        onResult: (result) {
          if (!mounted || !wakeMode || wakeSession) return;
          final heard = result.recognizedWords.trim();
          if (RegExp(r'\bastra\b', caseSensitive: false).hasMatch(heard)) {
            wakeSession = true;
            speech.stop();
            final command = heard.replaceFirst(RegExp(r'\bastra\b', caseSensitive: false), '').trim();
            if (command.isNotEmpty) {
              message.text = command;
              setState(() { listening = false; });
              send();
              wakeSession = false;
              restartWakeListening();
            } else {
              setState(() { listening = false; });
              speak('Oui, je vous écoute.');
              startCommandListening();
            }
          }
        },
      );
    } catch (_) {
      listening = false;
    }
  }

  Future<void> startCommandListening() async {
    if (!wakeMode || !voiceReady) return;
    try {
      listening = true;
      await speech.listen(
        localeId: 'fr_FR',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          if (!mounted || !wakeSession) return;
          message.text = result.recognizedWords;
          message.selection = TextSelection.collapsed(offset: message.text.length);
          setState(() {});
          if (result.finalResult) {
            setState(() { listening = false; });
            send();
            wakeSession = false;
            restartWakeListening();
          }
        },
      );
    } catch (_) {
      listening = false;
      wakeSession = false;
      restartWakeListening();
    }
  }

  void restartWakeListening() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && wakeMode && !wakeSession) startWakeListening();
    });
  }

  Future<void> toggleWakeMode() async {
    if (!voiceReady) await initVoice();
    if (!voiceReady) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone indisponible. Vérifie la permission.')));
      return;
    }
    setState(() { wakeMode = !wakeMode; wakeSession = false; });
    if (wakeMode) {
      await speech.stop();
      listening = false;
      restartWakeListening();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Écoute du mot ASTRA activée tant que l’application reste ouverte.')));
    } else {
      await speech.stop();
      setState(() { listening = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Écoute vocale désactivée.')));
    }
  }

  Future<void> speak(String text) async { try { await tts.stop(); await tts.speak(text); } catch (_) {} }

  Future<void> checkUpdates() async {
    if (checking || downloading) return;
    setState(() => checking = true);
    try {
      final update = await AppUpdate.check();
      if (!mounted) return;
      if (update == null || !update.isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune mise à jour disponible.')));
        return;
      }
      await showDialog<void>(context: context, builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF10202D),
        title: const Text('Mise à jour disponible', style: TextStyle(color: cyan)),
        content: Text('Version actuelle : ${update.currentVersion}\nNouvelle version : ${update.latestVersion}\n\n${update.releaseNotes}',
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Plus tard')),
          FilledButton(onPressed: () { Navigator.pop(d); downloadUpdate(update); }, child: const Text('Télécharger et installer')),
        ],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vérification impossible : $e')));
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> downloadUpdate(AppUpdate update) async {
    setState(() { downloading = true; progress = 0; });
    try {
      await update.downloadAndInstall((v) { if (mounted) setState(() => progress = v); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('APK téléchargé. Suivez les étapes Android pour installer la mise à jour.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Installation impossible : $e')));
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  void send() {
    final value = message.text.trim();
    if (value.isEmpty) return;
    setState(() {
      messages.add(ChatMessage('VOUS', value, true));
      messages.add(ChatMessage('ASTRA', 'Le module IA n’est pas encore connecté. Ton message est conservé dans cette conversation.', false));
      message.clear(); showChat = true;
    });
    speak('Message reçu. Mon module intelligence artificielle n’est pas encore connecté.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() { pulse.dispose(); orbit.dispose(); message.dispose(); scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: Drawer(backgroundColor: const Color(0xFF081521), child: SafeArea(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(22, 30, 22, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cyan, width: 1.5)),
            child: const Icon(Icons.blur_on, color: cyan, size: 32)),
          const SizedBox(height: 14),
          const Text('ASTRA', style: TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 5)),
          const Text('ASSISTANT IA', style: TextStyle(color: cyan, fontSize: 9, letterSpacing: 2)),
        ])),
        const Divider(color: Color(0x3354E8FF)),
        ListTile(leading: const Icon(Icons.forum_outlined, color: cyan), title: const Text('Conversation'),
          onTap: () { setState(() => showChat = true); Navigator.pop(context); }),
        ListTile(leading: const Icon(Icons.visibility_off_outlined, color: cyan), title: const Text('Masquer la conversation'),
          onTap: () { setState(() => showChat = false); Navigator.pop(context); }),
        ListTile(
          leading: Icon(wakeMode ? Icons.hearing : Icons.hearing_disabled, color: cyan),
          title: Text(wakeMode ? 'Écoute ASTRA activée' : 'Activer le mot ASTRA'),
          subtitle: const Text('Écoute seulement quand ASTRA est ouvert'),
          trailing: Switch(value: wakeMode, onChanged: (_) => toggleWakeMode(), activeColor: cyan),
          onTap: toggleWakeMode,
        ),
        ListTile(leading: const Icon(Icons.system_update_alt, color: cyan),
          title: Text(checking ? 'Vérification…' : 'Mises à jour'),
          onTap: () { Navigator.pop(context); checkUpdates(); }),
        const Spacer(),
        const Padding(padding: EdgeInsets.all(20), child: Text('ASTRA • Interface holographique', style: TextStyle(color: Colors.white38, fontSize: 10))),
      ],
    ))),
    body: Stack(children: [
      const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
        center: Alignment(0, -.15), radius: 1.15, colors: [Color(0xFF10283A), bg, Color(0xFF02050A)], stops: [0, .58, 1])))),
      Positioned.fill(child: CustomPaint(painter: GridPainter())),
      SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 6, 18, 2), child: Row(children: [
          Builder(builder: (c) => IconButton(onPressed: () => Scaffold.of(c).openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: cyan, size: 27), tooltip: 'Menu')),
          const SizedBox(width: 5),
          const Text('ASTRA', style: TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 4, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (checking) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cyan)),
        ])),
        Expanded(child: Column(children: [
          Expanded(flex: showChat ? 5 : 10, child: Center(child: reactor())),
          if (showChat) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: Row(children: [
              Text('CONVERSATION', style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
              SizedBox(width: 8), Expanded(child: Divider(color: Color(0x3354E8FF))),
            ])),
            Expanded(flex: 4, child: ListView.builder(controller: scroll, padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              itemCount: messages.length, itemBuilder: (c, i) {
                final m = messages[i];
                return Padding(padding: const EdgeInsets.only(bottom: 9), child: Align(
                  alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(constraints: const BoxConstraints(maxWidth: 290), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(color: m.user ? blue.withOpacity(.18) : cyan.withOpacity(.08),
                      borderRadius: BorderRadius.circular(14), border: Border.all(color: cyan.withOpacity(.18))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.sender, style: const TextStyle(color: cyan, fontSize: 9, letterSpacing: 1.5)),
                      const SizedBox(height: 4), Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
                    ]),
                  ),
                ));
              })),
          ],
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: Row(children: [
          Material(color: const Color(0xFF102638), shape: const CircleBorder(),
            child: IconButton(onPressed: toggleListening, tooltip: listening ? 'Arrêter l’écoute' : 'Parler à ASTRA',
              icon: Icon(listening ? Icons.mic : Icons.mic_none, color: listening ? cyan : Colors.white70))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: message, onSubmitted: (_) => send(), style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(hintText: 'Écrire à ASTRA…', hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              filled: true, fillColor: const Color(0xFF10202D), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: cyan.withOpacity(.18))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: cyan.withOpacity(.18))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: cyan))))),
          const SizedBox(width: 8),
          Material(color: blue.withOpacity(.25), shape: const CircleBorder(),
            child: IconButton(onPressed: send, icon: const Icon(Icons.arrow_upward, color: cyan))),
        ])),
      ])),
      if (downloading) Positioned(left: 24, right: 24, bottom: 90, child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF10202D), borderRadius: BorderRadius.circular(14), border: Border.all(color: cyan.withOpacity(.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Téléchargement de la mise à jour…', style: TextStyle(color: cyan)),
          const SizedBox(height: 9), LinearProgressIndicator(value: progress > 0 ? progress : null),
        ]))),
    ]),
  );

  Widget reactor() => SizedBox(width: 280, height: 280, child: AnimatedBuilder(
    animation: Listenable.merge([pulse, orbit]), builder: (c, _) => Stack(alignment: Alignment.center, children: [
      Container(width: 224, height: 224, decoration: BoxDecoration(shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: cyan.withOpacity(.10 + pulse.value * .12), blurRadius: 45, spreadRadius: 8)])),
      Transform.rotate(angle: orbit.value * 2 * math.pi, child: CustomPaint(size: const Size(250, 250), painter: OrbitPainter())),
      Container(width: 174, height: 174, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cyan.withOpacity(.34)),
        gradient: RadialGradient(colors: [const Color(0xFF1B5975).withOpacity(.34), const Color(0xFF071522).withOpacity(.7), Colors.transparent]))),
      Container(width: 132, height: 132, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cyan.withOpacity(.65), width: 1.4),
        boxShadow: [BoxShadow(color: blue.withOpacity(.22 + pulse.value * .18), blurRadius: 24, spreadRadius: 3)])),
      Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: RadialGradient(colors: [cyan.withOpacity(.30), blue.withOpacity(.12), Colors.transparent]), border: Border.all(color: Colors.white.withOpacity(.45))),
        child: const Icon(Icons.all_inclusive, size: 54, color: cyan)),
      for (final a in const [Alignment(0, -1), Alignment(0, 1), Alignment(-1, 0), Alignment(1, 0)])
        Align(alignment: a, child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: cyan, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: cyan, blurRadius: 8, spreadRadius: 2)]))),
    ])),
  );
}

class ChatMessage {
  final String sender, text;
  final bool user;
  ChatMessage(this.sender, this.text, this.user);
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = cyan.withOpacity(.035)..strokeWidth = .5;
    for (double x = 0; x < size.width; x += 28) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), p); }
    for (double y = 0; y < size.height; y += 28) { canvas.drawLine(Offset(0, y), Offset(size.width, y), p); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final p = Paint()..color = cyan.withOpacity(.35)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawCircle(center, 112, p); p.color = cyan.withOpacity(.18); canvas.drawCircle(center, 100, p);
    final tick = Paint()..color = cyan.withOpacity(.65)..strokeWidth = 2;
    for (int i = 0; i < 48; i++) {
      final a = i * math.pi / 24, r = i % 4 == 0 ? 108.0 : 110.0;
      canvas.drawLine(Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r),
        Offset(center.dx + math.cos(a) * 115, center.dy + math.sin(a) * 115), tick);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
