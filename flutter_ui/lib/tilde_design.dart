/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 */
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

const tildeName = 'Tilde';
// Built-in preset IDs are preserved when presets are appended.
const tildeBaseSchemeIds = {-1, -9};
const tildeMono = 'JetBrainsMono';
const tildeNightBackground = Color(0xff0e1216);
const tildeDayBackground = Color(0xfff6f5f0);
const tildeTide = Color(0xff6fd8c4);
const tildeSand = Color(0xffebc37a);
const tildeCoral = Color(0xffff8577);

ThemeData tildeTheme(Brightness brightness, AndroidEngine engine) {
  final dark = brightness == Brightness.dark;
  final profiles = engine.list('profiles');
  final profile = profiles
      .where((p) => p['id'] == engine.preferences['defaultProfileId'])
      .firstOrNull;
  final scheme = engine
      .list('schemes')
      .where((s) => s['id'] == profile?['colorSchemeId'])
      .firstOrNull;
  final custom = scheme != null && !tildeBaseSchemeIds.contains(scheme['id']);
  final palette = (scheme?['palette'] as List? ?? []).cast<num>();
  Color role(String key, Color fallback) {
    if (scheme?['${key}Color'] is num) {
      return Color((scheme!['${key}Color'] as num).toInt());
    }
    final index = (scheme?[key] as num?)?.toInt();
    return index != null && index >= 0 && index < palette.length
        ? Color(palette[index].toInt())
        : fallback;
  }

  final bg = custom
      ? role('background', tildeNightBackground)
      : dark
      ? tildeNightBackground
      : tildeDayBackground;
  final fg = custom
      ? role('foreground', const Color(0xffe4e8eb))
      : dark
      ? const Color(0xffe4e8eb)
      : const Color(0xff242d35);
  final accent = custom
      ? Color(
          (scheme['cursorColor'] as num?)?.toInt() ??
              (palette.length > 6 ? palette[6].toInt() : tildeTide.toARGB32()),
        )
      : dark
      ? tildeTide
      : const Color(0xff0b7566);
  Color mix(double fraction) => Color.lerp(bg, fg, fraction)!;
  final s1 = custom
      ? mix(.04)
      : dark
      ? const Color(0xff151a1f)
      : const Color(0xffecebe4);
  final s2 = custom
      ? mix(.08)
      : dark
      ? const Color(0xff1b2229)
      : const Color(0xffe3e2da);
  final s3 = custom
      ? mix(.13)
      : dark
      ? const Color(0xff242d35)
      : const Color(0xffdad9d1);
  final line = custom
      ? mix(.15)
      : dark
      ? const Color(0xff232b33)
      : const Color(0xffd2d1c9);
  final muted = custom
      ? Color.lerp(bg, fg, .64)!
      : dark
      ? const Color(0xff98a3ad)
      : const Color(0xff626d73);
  final selected = dark ? const Color(0xff12302b) : const Color(0xffd6e9e1);
  final cs = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: accent,
        onPrimary: dark ? const Color(0xff04201b) : Colors.white,
        primaryContainer: selected,
        onPrimaryContainer: accent,
        secondary: accent,
        onSecondary: dark ? const Color(0xff04201b) : Colors.white,
        secondaryContainer: selected,
        onSecondaryContainer: accent,
        tertiary: dark ? tildeSand : const Color(0xff936b24),
        tertiaryContainer: selected,
        onTertiaryContainer: accent,
        error: dark ? tildeCoral : const Color(0xffc2362b),
        surface: bg,
        onSurface: fg,
        onSurfaceVariant: muted,
        surfaceContainerLowest: bg,
        surfaceContainerLow: s1,
        surfaceContainer: s1,
        surfaceContainerHigh: s2,
        surfaceContainerHighest: s3,
        outline: dark ? const Color(0xff6e7983) : muted,
        outlineVariant: line,
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    fontFamily: 'Pretendard',
    fontFamilyFallback: const ['Pretendard'],
  );
  final inputShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge!.copyWith(fontSize: 15, height: 1.4),
      bodyMedium: base.textTheme.bodyMedium!.copyWith(
        fontSize: 13,
        height: 18 / 13,
      ),
      bodySmall: base.textTheme.bodySmall!.copyWith(
        fontSize: 12.5,
        height: 18 / 12.5,
      ),
      titleMedium: base.textTheme.titleMedium!.copyWith(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 56,
      titleTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: fg,
      ),
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: 56,
      titleTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: fg,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        height: 18 / 13,
        color: muted,
      ),
      iconColor: muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      selectedTileColor: selected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    cardTheme: CardThemeData(
      color: s1,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      errorStyle: TextStyle(color: cs.error),
      labelStyle: TextStyle(fontSize: 12.5, color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: inputShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: inputShape,
        side: BorderSide(color: line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: inputShape,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s1,
      modalBackgroundColor: s1,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: s2,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: s2,
      selectedColor: selected,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? selected : s2,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : muted,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: line)),
        shape: WidgetStatePropertyAll(inputShape),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : s3,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? cs.onPrimary : muted,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: cs.onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class TildeMark extends StatelessWidget {
  final double size;
  final bool monochrome;
  const TildeMark({super.key, this.size = 40, this.monochrome = false});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Tilde 홈 디렉터리',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TildeMarkPainter(
          Theme.of(context).colorScheme.onSurface,
          monochrome
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

class _TildeMarkPainter extends CustomPainter {
  final Color foreground, accent;
  _TildeMarkPainter(this.foreground, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 108, size.height / 108);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width <= 28 ? 12 : 10;
    canvas.drawPath(
      Path()
        ..moveTo(24, 59)
        ..cubicTo(27.5, 48, 35.5, 46, 42.5, 54)
        ..cubicTo(49.5, 62, 56.5, 60.5, 60, 50),
      paint..color = accent,
    );
    canvas.drawLine(
      const Offset(69, 72),
      const Offset(82, 36),
      paint..color = foreground,
    );
  }

  @override
  bool shouldRepaint(_TildeMarkPainter old) =>
      old.foreground != foreground || old.accent != accent;
}

class TildeWordmark extends StatelessWidget {
  final double size;
  const TildeWordmark({super.key, this.size = 25});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TildeMark(size: size * 1.5),
      const SizedBox(width: 4),
      Text(
        'tilde',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: -size * .04,
        ),
      ),
    ],
  );
}

class TildeProgress extends StatefulWidget {
  final String? label;
  const TildeProgress({super.key, this.label});
  @override
  State<TildeProgress> createState() => _TildeProgressState();
}

class _TildeProgressState extends State<TildeProgress>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label ?? '진행 중',
    value: '진행 중',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 12,
          width: 160,
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, _) => CustomPaint(
              painter: _WavePainter(
                controller.value,
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(widget.label!),
          ),
      ],
    ),
  );
}

class _WavePainter extends CustomPainter {
  final double phase;
  final Color color;
  _WavePainter(this.phase, this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Path();
    for (var x = 0.0; x <= s.width; x += 2) {
      final y =
          s.height / 2 + math.sin((x / s.width * 4 - phase * 2) * math.pi) * 3;
      if (x == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    c.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.color != color;
}

class TildeHostTile extends StatelessWidget {
  final EngineRecord host;
  final double size;
  const TildeHostTile({super.key, required this.host, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final name = '${host['nickname'] ?? host['hostname'] ?? ''}'.trim();
    final parts = name
        .split(RegExp(r'[\s._-]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final initials = parts.length > 1
        ? '${parts.first.characters.first}${parts[1].characters.first}'
        : name.isEmpty
        ? '~/'
        : name.characters.take(2).toString();
    final raw = '${host['color'] ?? ''}'.replaceFirst('#', '');
    final parsed = (raw.length == 6 || raw.length == 8)
        ? int.tryParse(raw, radix: 16)
        : null;
    final color = parsed == null
        ? Color(
            (host['iconArgb'] as num?)?.toInt() ??
                Theme.of(context).colorScheme.primary.toARGB32(),
          )
        : Color(0xff000000 | parsed);
    final status = host['connectionState'];
    final dot = switch (status) {
      'CONNECTED' => const Color(0xff8fd694),
      'UNREAD_OUTPUT' => tildeSand,
      'ERROR' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Semantics(
      label:
          '$name ${switch (status) {
            'CONNECTED' => '연결됨',
            'UNREAD_OUTPUT' => '새 출력',
            'ERROR' => '오류',
            'DISCONNECTED' => '연결 안 됨',
            _ => '',
          }}',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                initials.toLowerCase(),
                style: TextStyle(
                  fontFamily: tildeMono,
                  fontSize: size * .36,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (status != null && status != 'UNKNOWN')
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
