import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'update_service.dart';

void main() => runApp(const JarvisApp());

const cyan = Color(0xFF54E8FF);
const blue = Color(0xFF168DFF);
const bg = Color(0xFF050B13);

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ASTRA',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const AssistantHome(),
    );
  }
}

class AssistantHome extends StatefulWidget {
  const AssistantHome({super.key});

  @override
  State<AssistantHome> createState() => _AssistantHomeState();
}

class _AssistantHomeState extends State<AssistantHome> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _orbit;
  final TextEditingController _message = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage('ASTRA', 'Bonjour. Tous les systèmes sont prêts. Comment puis-je vous aider ?', false),
  ];
  bool _listening = false;
  bool _showChat = false;
  String _clock = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _updateClock();
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateClock();
    });
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final update = await AppUpdate.check();
      if (!mounted) return;
      if (update == null || !update.isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ASTRA est déjà à jour, ou aucune version n’est publiée.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF10202D),
          title: const Text('Mise à jour disponible', style: TextStyle(color: cyan)),
          content: Text(
            'Version actuelle : ' + update.currentVersion + '\nNouvelle version : ' + update.latestVersion + '\n\n' + update.releaseNotes,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Plus tard')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await update.openRelease();
              },
              child: const Text('Télécharger'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vérification impossible : ' + error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() => _clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
  }

  void _send() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage('VOUS', text, true));
      _messages.add(ChatMessage('ASTRA', 'Message reçu. Mon module de conversation sera connecté dans une prochaine étape.', false));
      _message.clear();
      _showChat = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _orbit.dispose();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: DecoratedBox(
          decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.25), radius: 1.15,
            colors: [Color(0xFF10283A), bg, Color(0xFF02050A)], stops: [0, .58, 1])),
        )),
        Positioned.fill(child: CustomPaint(painter: GridPainter())),
        SafeArea(child: Column(children: [
          _topBar(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(children: [
              const SizedBox(height: 12),
              Text(_clock, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w200, letterSpacing: 5)),
              const SizedBox(height: 4),
              const Text('MERCREDI • SYSTÈME EN LIGNE', style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2.4)),
              const SizedBox(height: 12),
              _reactor(),
              const SizedBox(height: 8),
              const Text('ASTRA', style: TextStyle(fontSize: 30, letterSpacing: 9, fontWeight: FontWeight.w300, color: Colors.white)),
              const SizedBox(height: 5),
              Text(_listening ? 'JE VOUS ÉCOUTE…' : 'INTELLIGENCE ARTIFICIELLE • EN ATTENTE',
                style: const TextStyle(color: cyan, fontSize: 10, letterSpacing: 1.8)),
              const SizedBox(height: 24),
              _statusPanel(),
              const SizedBox(height: 18),
              if (_showChat) _chatPanel(),
              const SizedBox(height: 18),
            ]),
          )),
          _composer(),
        ])),
      ]),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    child: Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(border: Border.all(color: cyan.withOpacity(.55)), shape: BoxShape.circle),
        child: const Icon(Icons.blur_on, color: cyan, size: 21)),
      const SizedBox(width: 10),
      const Text('J.A.R.V.I.S', style: TextStyle(color: Colors.white, fontSize: 13, letterSpacing: 3, fontWeight: FontWeight.w600)),
      const Spacer(),
      _tinyTag('ONLINE'),
      const SizedBox(width: 4),
      IconButton(
        onPressed: _checkingUpdate ? null : _checkForUpdates,
        tooltip: 'Vérifier les mises à jour',
        icon: _checkingUpdate
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cyan))
            : const Icon(Icons.system_update_alt, color: cyan),
      ),
      IconButton(onPressed: () => setState(() => _showChat = !_showChat),
        icon: const Icon(Icons.forum_outlined, color: cyan), tooltip: 'Afficher la conversation'),
    ]),
  );

  Widget _reactor() => SizedBox(
    width: 260, height: 260,
    child: AnimatedBuilder(animation: Listenable.merge([_pulse, _orbit]), builder: (context, _) {
      return Stack(alignment: Alignment.center, children: [
        Container(width: 224, height: 224, decoration: BoxDecoration(shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: cyan.withOpacity(.10 + _pulse.value * .12), blurRadius: 45, spreadRadius: 8)])),
        Transform.rotate(angle: _orbit.value * 2 * math.pi, child: CustomPaint(size: const Size(240, 240), painter: OrbitPainter())),
        Container(width: 174, height: 174, decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: cyan.withOpacity(.34), width: 1.2),
          gradient: RadialGradient(colors: [const Color(0xFF1B5975).withOpacity(.34), const Color(0xFF071522).withOpacity(.7), Colors.transparent]))),
        Container(width: 132, height: 132, decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: cyan.withOpacity(.65), width: 1.4),
          boxShadow: [BoxShadow(color: blue.withOpacity(.22 + _pulse.value * .18), blurRadius: 24, spreadRadius: 3)])),
        Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [cyan.withOpacity(.30), blue.withOpacity(.12), Colors.transparent]),
          border: Border.all(color: Colors.white.withOpacity(.45))),
          child: const Icon(Icons.all_inclusive, size: 54, color: cyan)),
        Positioned(top: 8, child: _dot()),
        Positioned(bottom: 8, child: _dot()),
        Positioned(left: 8, child: _dot()),
        Positioned(right: 8, child: _dot()),
      ]);
    }),
  );

  Widget _dot() => Container(width: 5, height: 5, decoration: const BoxDecoration(color: cyan, shape: BoxShape.circle,
    boxShadow: [BoxShadow(color: cyan, blurRadius: 8, spreadRadius: 2)]));

  Widget _statusPanel() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF0B1B29).withOpacity(.78),
      border: Border.all(color: cyan.withOpacity(.20)), borderRadius: BorderRadius.circular(18)),
    child: Column(children: [
      Row(children: [const Text('ÉTAT DU SYSTÈME', style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
        const Spacer(), Icon(Icons.shield_outlined, color: cyan.withOpacity(.8), size: 16)]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _metric(Icons.memory, 'IA', 'EN VEILLE')),
        Expanded(child: _metric(Icons.wifi, 'RÉSEAU', 'À CONNECTER')),
        Expanded(child: _metric(Icons.mic_none, 'AUDIO', _listening ? 'ACTIF' : 'PRÊT')),
      ]),
      const SizedBox(height: 15),
      Row(children: [const Text('SIGNAL SYSTÈME', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.5)), const Spacer(),
        const Text('STABLE', style: TextStyle(color: cyan, fontSize: 9, letterSpacing: 1.5))]),
      const SizedBox(height: 7),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: .86, minHeight: 3,
        backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(cyan))),
    ]),
  );

  Widget _metric(IconData icon, String label, String value) => Column(children: [
    Icon(icon, color: cyan, size: 19), const SizedBox(height: 7),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
  ]);

  Widget _chatPanel() => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF0B1B29).withOpacity(.8),
      borderRadius: BorderRadius.circular(16), border: Border.all(color: cyan.withOpacity(.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('CONVERSATION', style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2)),
      const SizedBox(height: 10),
      ..._messages.map((m) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Align(
        alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(constraints: const BoxConstraints(maxWidth: 270), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: m.isUser ? blue.withOpacity(.18) : cyan.withOpacity(.08),
            borderRadius: BorderRadius.circular(12), border: Border.all(color: cyan.withOpacity(.14))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.sender, style: const TextStyle(color: cyan, fontSize: 9, letterSpacing: 1.5)),
            const SizedBox(height: 4), Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
          ]),
        ),
      ))),
    ]),
  );

  Widget _composer() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
    child: Row(children: [
      Material(color: _listening ? cyan.withOpacity(.22) : const Color(0xFF102638), shape: const CircleBorder(),
        child: IconButton(onPressed: () => setState(() => _listening = !_listening),
          icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: cyan))),
      const SizedBox(width: 9),
      Expanded(child: TextField(controller: _message, onSubmitted: (_) => _send(),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(hintText: 'Écrire à ASTRA…', hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          filled: true, fillColor: const Color(0xFF10202D), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: cyan.withOpacity(.18))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: cyan.withOpacity(.18))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: cyan))))),
      const SizedBox(width: 8),
      Material(color: blue.withOpacity(.25), shape: const CircleBorder(),
        child: IconButton(onPressed: _send, icon: const Icon(Icons.arrow_upward, color: cyan))),
    ]),
  );

  Widget _tinyTag(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(border: Border.all(color: cyan.withOpacity(.5)), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(color: cyan, fontSize: 9, letterSpacing: 1.3)));
}

class ChatMessage {
  final String sender;
  final String text;
  final bool isUser;
  ChatMessage(this.sender, this.text, this.isUser);
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
    canvas.drawCircle(center, 112, p);
    p.color = cyan.withOpacity(.18);
    canvas.drawCircle(center, 100, p);
    final tick = Paint()..color = cyan.withOpacity(.65)..strokeWidth = 2;
    for (int i = 0; i < 48; i++) {
      final a = i * math.pi / 24;
      final r1 = i % 4 == 0 ? 108.0 : 110.0;
      final r2 = 115.0;
      canvas.drawLine(Offset(center.dx + math.cos(a) * r1, center.dy + math.sin(a) * r1),
        Offset(center.dx + math.cos(a) * r2, center.dy + math.sin(a) * r2), tick);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
