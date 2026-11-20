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
  );  Widget reactor() => SizedBox(width: 300, height: 320, child: AnimatedBuilder(
    animation: Listenable.merge([pulse, orbit]), builder: (c, _) => Stack(alignment: Alignment.center, children: [
      Container(width: 245, height: 245, decoration: BoxDecoration(shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: cyan.withOpacity(.12 + pulse.value * .15), blurRadius: 48, spreadRadius: 10)])),
      Positioned(bottom: 14, child: Container(width: 108, height: 18, decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50), gradient: RadialGradient(colors: [cyan.withOpacity(.35), Colors.transparent]),
        border: Border.all(color: cyan.withOpacity(.4))))),
      Transform.rotate(angle: orbit.value * 2 * math.pi, child: CustomPaint(size: const Size(270, 270), painter: OrbitPainter())),
      Transform.rotate(angle: -orbit.value * 1.6 * math.pi, child: CustomPaint(size: const Size(224, 224), painter: HoloRingPainter())),
      Container(width: 200, height: 246, decoration: BoxDecoration(gradient: RadialGradient(
        colors: [cyan.withOpacity(.10), blue.withOpacity(.05), Colors.transparent], stops: [0, .5, 1]))),
      CustomPaint(size: const Size(205, 245), painter: HologramFigurePainter(glow: pulse.value)),
      CustomPaint(size: const Size(205, 245), painter: HoloScanPainter(progress: pulse.value)),
      Positioned(top: 18, child: Text('HOLOGRAMME IA', style: TextStyle(color: cyan.withOpacity(.7), fontSize: 8, letterSpacing: 3))),
      Positioned(bottom: 0, child: Text('ASTRA  •  ONLINE', style: TextStyle(color: cyan.withOpacity(.85), fontSize: 9, letterSpacing: 2))),
    ])),
  );\nclass HoloRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      p.color = cyan.withOpacity(.13 + i * .06);
      canvas.drawOval(Rect.fromCenter(center: c, width: size.width - i * 20, height: 50 + i * 13), p);
    }
    p.color = cyan.withOpacity(.45); p.strokeWidth = 1.4;
    canvas.drawArc(Rect.fromCenter(center: c, width: size.width - 10, height: size.height - 45), .3, 1.1, false, p);
    canvas.drawArc(Rect.fromCenter(center: c, width: size.width - 10, height: size.height - 45), 3.4, 1.1, false, p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HologramFigurePainter extends CustomPainter {
  final double glow;
  HologramFigurePainter({required this.glow});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final p = Paint()..color = cyan.withOpacity(.65 + glow * .2)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final fill = Paint()..shader = RadialGradient(colors: [cyan.withOpacity(.16), blue.withOpacity(.05), Colors.transparent]).createShader(Offset.zero & size);
    // Head and neck
    final head = Rect.fromCenter(center: Offset(center, 70), width: 54, height: 66);
    canvas.drawOval(head, fill); canvas.drawOval(head, p);
    canvas.drawLine(Offset(center - 15, 106), Offset(center - 13, 126), p);
    canvas.drawLine(Offset(center + 15, 106), Offset(center + 13, 126), p);
    // Upper torso silhouette
    final bust = Path()
      ..moveTo(center - 13, 122)
      ..quadraticBezierTo(center - 38, 125, center - 50, 142)
      ..lineTo(center - 63, 176)
      ..quadraticBezierTo(center - 68, 192, center - 48, 197)
      ..lineTo(center - 39, 187)
      ..lineTo(center - 30, 165)
      ..lineTo(center - 30, 222)
      ..quadraticBezierTo(center, 234, center + 30, 222)
      ..lineTo(center + 30, 165)
      ..lineTo(center + 39, 187)
      ..lineTo(center + 48, 197)
      ..quadraticBezierTo(center + 68, 192, center + 63, 176)
      ..lineTo(center + 50, 142)
      ..quadraticBezier(center + 38, 125, center + 13, 122)
      ..close();
    canvas.drawPath(bust, fill); canvas.drawPath(bust, p);
    // Minimal facial contour and HUD accents
    p.color = cyan.withOpacity(.42); p.strokeWidth = 1;
    canvas.drawLine(Offset(center - 18, 68), Offset(center - 7, 68), p);
    canvas.drawLine(Offset(center + 7, 68), Offset(center + 18, 68), p);
    canvas.drawLine(Offset(center, 72), Offset(center - 3, 86), p);
    canvas.drawLine(Offset(center - 8, 94), Offset(center + 8, 94), p);
    canvas.drawLine(Offset(center - 26, 143), Offset(center + 26, 143), p);
    canvas.drawLine(Offset(center - 35, 155), Offset(center + 35, 155), p);
    p.color = cyan.withOpacity(.75); p.strokeWidth = 2;
    canvas.drawCircle(Offset(center - 8, 69), 2, p); canvas.drawCircle(Offset(center + 8, 69), 2, p);
  }
  @override
  bool shouldRepaint(covariant HologramFigurePainter oldDelegate) => oldDelegate.glow != glow;
}

class HoloScanPainter extends CustomPainter {
  final double progress;
  HoloScanPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = cyan.withOpacity(.11)..strokeWidth = 1;
    for (double y = 12; y < size.height - 12; y += 5) {
      canvas.drawLine(Offset(22, y), Offset(size.width - 22, y), p);
    }
    final scanY = 25 + progress * (size.height - 50);
    p.color = cyan.withOpacity(.55); p.strokeWidth = 1.2;
    canvas.drawLine(Offset(28, scanY), Offset(size.width - 28, scanY), p);
    p.color = cyan.withOpacity(.12);
    canvas.drawRect(Rect.fromLTWH(28, scanY - 5, size.width - 56, 10), p..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(covariant HoloScanPainter oldDelegate) => oldDelegate.progress != progress;
}
