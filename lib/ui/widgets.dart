import 'dart:math' as math;
import 'package:flutter/material.dart';

const ink = Color(0xff0b1222),
    panel = Color(0xff151f34),
    muted = Color(0xffa1adc3);
const orange = Color(0xffff833d),
    cream = Color(0xfffff3dc),
    cyan = Color(0xff57dcec);

TextStyle display(double size, {Color color = cream, double spacing = .5}) =>
    TextStyle(
      fontFamily: 'RushDisplay',
      fontSize: size,
      color: color,
      height: .96,
      letterSpacing: spacing,
    );
TextStyle body(double size, {Color color = cream, double spacing = .3}) =>
    TextStyle(
      fontFamily: 'RushBody',
      fontSize: size,
      color: color,
      letterSpacing: spacing,
    );

class RushButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary, compact;
  final Color? color;
  const RushButton(
    this.text, {
    super.key,
    this.icon,
    this.onTap,
    this.primary = false,
    this.compact = false,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: text,
    child: Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Material(
        color: color ?? (primary ? orange : const Color(0xff22304a)),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 22,
              vertical: compact ? 11 : 15,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: primary
                    ? color == null
                          ? const Color(0xffffb46a)
                          : Color.lerp(color, cream, .35)!
                    : const Color(0xff34435d),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: compact ? 18 : 23,
                    color: primary ? ink : cream,
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: display(
                      compact ? 17 : 24,
                      color: primary ? ink : cream,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class RushBadge extends StatelessWidget {
  final String text;
  final Color color;
  const RushBadge(this.text, {super.key, this.color = cyan});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Text(text, style: body(10, color: color, spacing: 1.4)),
  );
}

class StatBar extends StatelessWidget {
  final String name;
  final double value;
  final Color color;
  const StatBar(this.name, this.value, {super.key, this.color = orange});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 98,
          child: Text(name, style: body(11, color: muted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 5,
              color: color,
              backgroundColor: const Color(0xff2d3951),
            ),
          ),
        ),
      ],
    ),
  );
}

class TechBackground extends CustomPainter {
  final double phase;
  TechBackground(this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff16223a), Color(0xff0c1324), Color(0xff131a2e)],
        ).createShader(Offset.zero & size),
    );
    final grid = Paint()
      ..color = const Color(0xff1d2a42)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width + size.height; x += 48) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x + size.height * .25, size.height),
        grid,
      );
    }
    for (var y = 0; y < size.height; y += 48) {
      canvas.drawLine(
        Offset(0, y.toDouble()),
        Offset(size.width, y.toDouble()),
        grid,
      );
    }
    final path = Path()
      ..moveTo(size.width * .48, size.height * 1.2)
      ..cubicTo(
        size.width * 1.1,
        size.height * .55,
        size.width * .4,
        -size.height * .1,
        size.width * 1.15,
        size.height * .22,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 56
        ..color = const Color(0xff823f2c),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 43
        ..color = const Color(0xffc26130),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xffe89952),
    );
    canvas.drawCircle(
      Offset(size.width * .78, size.height * .4),
      100 + math.sin(phase) * 3,
      Paint()..color = const Color(0x0affbc73),
    );
  }

  @override
  bool shouldRepaint(covariant TechBackground old) => false;
}

class SectionHeader extends StatelessWidget {
  final String eyebrow, title;
  final VoidCallback onBack;
  final Widget? trailing;
  const SectionHeader(
    this.eyebrow,
    this.title,
    this.onBack, {
    super.key,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_rounded, color: cream),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow, style: body(9, color: orange, spacing: 2.5)),
              const SizedBox(height: 3),
              Text(title, style: display(34)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}
