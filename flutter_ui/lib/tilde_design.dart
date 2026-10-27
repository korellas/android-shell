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
const tildeNightBackground = Color(0xff13110f);
const tildeDayBackground = Color(0xfff6f5f0);
const tildeTide = Color(0xff6fd8c4);
const tildeSand = Color(0xffebc37a);
const tildeCoral = Color(0xffff8577);

ThemeData tildeTheme(
  Brightness brightness,
  AndroidEngine engine, {
  EngineRecord? terminalScheme,
}) {
  final dark = brightness == Brightness.dark;
  final profiles = engine.list('profiles');
  final profile = profiles
      .where((p) => p['id'] == engine.preferences['defaultProfileId'])
      .firstOrNull;
  final scheme =
      terminalScheme ??
      engine
          .list('schemes')
          .where((s) => s['id'] == profile?['colorSchemeId'])
          .firstOrNull;
  final custom =
      scheme != null &&
      (terminalScheme != null || !tildeBaseSchemeIds.contains(scheme['id']));
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
      ? role('foreground', const Color(0xffeae9e7))
      : dark
      ? const Color(0xffeae9e7)
      : const Color(0xff2e2b25);
  final accent = custom
      ? Color(
          (scheme['cursorColor'] as num?)?.toInt() ??
              (palette.length > 6 ? palette[6].toInt() : tildeTide.toARGB32()),
        )
      : dark
      ? tildeTide
      : const Color(0xff006e5f);
  Color mix(double fraction) => Color.lerp(bg, fg, fraction)!;
  final s1 = custom
      ? mix(.04)
      : dark
      ? const Color(0xff1c1b18)
      : const Color(0xffecebe4);
  final s2 = custom
      ? mix(.08)
      : dark
      ? const Color(0xff262421)
      : const Color(0xffe3e2da);
  final s3 = custom
      ? mix(.13)
      : dark
      ? const Color(0xff312f2b)
      : const Color(0xffdad9d1);
  final line = custom
      ? mix(.19)
      : dark
      ? const Color(0xff383633)
      : const Color(0xffceccc4);
  final muted = custom
      ? Color.lerp(bg, fg, .64)!
      : dark
      ? const Color(0xffaaa7a2)
      : const Color(0xff67635c);
  final selected = dark ? const Color(0xff0c3a32) : const Color(0xffcfeae3);
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
        tertiary: dark ? tildeSand : const Color(0xff8a5f18),
        tertiaryContainer: selected,
        onTertiaryContainer: accent,
        error: dark ? tildeCoral : const Color(0xffb8372c),
        surface: bg,
        onSurface: fg,
        onSurfaceVariant: muted,
        surfaceContainerLowest: bg,
        surfaceContainerLow: s1,
        surfaceContainer: s1,
        surfaceContainerHigh: s2,
        surfaceContainerHighest: s3,
        outline: dark ? const Color(0xff767470) : const Color(0xff898680),
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
    borderRadius: BorderRadius.circular(12),
  );
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge!.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.textTheme.headlineMedium!.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.textTheme.titleLarge!.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
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
        fontSize: 17,
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
      fillColor: s2,
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
        minimumSize: const Size(0, 48),
        shape: inputShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: inputShape,
        side: BorderSide(color: line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
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
      showCheckmark: false,
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
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: s3,
      contentTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        color: fg,
        fontSize: 13,
      ),
      actionTextColor: accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

class TildeProgress extends StatelessWidget {
  final String? label;
  final bool circular;
  const TildeProgress({super.key, this.label}) : circular = false;
  const TildeProgress.circular({super.key, this.label}) : circular = true;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label ?? '진행 중',
    value: '진행 중',
    child: circular
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 2,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label!),
                ),
            ],
          ),
  );
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
    final sourceColor = parsed == null
        ? Color(
            (host['iconArgb'] as num?)?.toInt() ??
                Theme.of(context).colorScheme.primary.toARGB32(),
          )
        : Color(0xff000000 | parsed);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark
        ? sourceColor
        : switch (sourceColor.toARGB32()) {
            0xff6fd8c4 => const Color(0xff006e5f),
            0xffebc37a => const Color(0xff8a5f18),
            0xffff8577 => const Color(0xffb8372c),
            _ => _dayHostColor(sourceColor),
          };
    final status = host['connectionState'];
    final dot = switch (status) {
      'CONNECTED' => Theme.of(context).colorScheme.primary,
      'UNREAD_OUTPUT' => Theme.of(context).colorScheme.tertiary,
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
                color: color.withValues(alpha: dark ? .16 : .13),
                borderRadius: BorderRadius.circular(size >= 72 ? 20 : 16),
              ),
              child: Text(
                initials.toLowerCase(),
                style: TextStyle(
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
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 3,
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

Color _dayHostColor(Color color) {
  double linear(double value) => value <= .04045
      ? value / 12.92
      : math.pow((value + .055) / 1.055, 2.4).toDouble();
  double srgb(double value) =>
      (value <= .0031308
              ? value * 12.92
              : 1.055 * math.pow(value, 1 / 2.4) - .055)
          .clamp(0, 1)
          .toDouble();
  final r = linear(color.r), g = linear(color.g), b = linear(color.b);
  final l = math
      .pow(.4122214708 * r + .5363325363 * g + .0514459929 * b, 1 / 3)
      .toDouble();
  final m = math
      .pow(.2119034982 * r + .6806995451 * g + .1073969566 * b, 1 / 3)
      .toDouble();
  final s = math
      .pow(.0883024619 * r + .2817188376 * g + .6299787005 * b, 1 / 3)
      .toDouble();
  final a = 1.9779984951 * l - 2.4285922050 * m + .4505937099 * s;
  final bb = .0259040371 * l + .7827717662 * m - .8086757660 * s;
  final ll = math.pow(.5 + .3963377774 * a + .2158037573 * bb, 3).toDouble();
  final mm = math.pow(.5 - .1055613458 * a - .0638541728 * bb, 3).toDouble();
  final ss = math.pow(.5 - .0894841775 * a - 1.2914855480 * bb, 3).toDouble();
  return Color.from(
    alpha: 1,
    red: srgb(4.0767416621 * ll - 3.3077115913 * mm + .2309699292 * ss),
    green: srgb(-1.2684380046 * ll + 2.6097574011 * mm - .3413193965 * ss),
    blue: srgb(-.0041960863 * ll - .7034186147 * mm + 1.7076147010 * ss),
  );
}

Future<T?> showTildeSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool showDragHandle = true,
  double maxWidth = 440,
}) {
  if (MediaQuery.sizeOf(context).width < 840) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (c) => Dialog(
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: builder(c),
      ),
    ),
  );
}

EdgeInsets tildeToastInsets(double width) =>
    EdgeInsets.fromLTRB(16, 0, width >= 840 ? width - 436 : 16, 16);
