// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'engine.dart';
import 'l10n/strings.dart';

class WindowsWindowFrame extends StatefulWidget {
  const WindowsWindowFrame({
    super.key,
    required this.titleBar,
    required this.child,
  });
  final Widget Function(Widget dragRegion) titleBar;
  final Widget child;
  @override
  State<WindowsWindowFrame> createState() => _WindowsWindowFrameState();
}

class _WindowsWindowFrameState extends State<WindowsWindowFrame> {
  static const channel = MethodChannel('dev.korellas.tilde/windows');
  final drag = GlobalKey(), maximize = GlobalKey();
  bool maximized = false,
      active = true,
      fullscreen = false,
      maximizeHovered = false;
  bool ready = false, regionsPending = false;
  String? hovered;
  List<int>? lastRegions;

  @override
  void initState() {
    super.initState();
    channel.setMethodCallHandler((call) async {
      if (call.method == 'window.state' && mounted) {
        updateState(row(call.arguments));
      }
    });
    unawaited(configure());
  }

  Future<void> configure() async {
    final state = await channel.invokeMethod<Object?>('window.configure', {
      'enabled': true,
    });
    if (!mounted) return;
    ready = true;
    updateState(row(state));
  }

  void updateState(EngineRecord state) => setState(() {
    maximized = state['maximized'] == true;
    active = state['active'] != false;
    fullscreen = state['fullscreen'] == true;
    maximizeHovered = state['maximizeHovered'] == true;
  });

  void scheduleRegions() {
    if (regionsPending || !ready) return;
    regionsPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      regionsPending = false;
      if (!mounted) return;
      List<int> rect(GlobalKey key) {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || fullscreen) return [0, 0, 0, 0];
        final origin = box.localToGlobal(Offset.zero);
        final ratio = MediaQuery.devicePixelRatioOf(context);
        return [
          origin.dx,
          origin.dy,
          origin.dx + box.size.width,
          origin.dy + box.size.height,
        ].map((value) => (value * ratio).round()).toList();
      }

      final dragRect = rect(drag), maximizeRect = rect(maximize);
      final regions = [...dragRect, ...maximizeRect];
      if (listEquals(regions, lastRegions)) return;
      lastRegions = regions;
      unawaited(
        channel.invokeMethod<void>('window.hitTestRegions', {
          'drag': dragRect,
          'maximize': maximizeRect,
        }),
      );
    });
  }

  @override
  void dispose() {
    channel.setMethodCallHandler(null);
    super.dispose();
  }

  Widget caption(String command, String label, {GlobalKey? key}) {
    final colors = Theme.of(context).colorScheme;
    final hover = command == 'toggleMaximize'
        ? maximizeHovered || hovered == command
        : hovered == command;
    final close = command == 'close';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: MouseRegion(
          onEnter: (_) => setState(() => hovered = command),
          onExit: (_) => setState(() => hovered = null),
          child: Material(
            color: hover
                ? (close
                      ? const Color(0xffc42b1c)
                      : colors.onSurface.withValues(alpha: .08))
                : Colors.transparent,
            child: InkWell(
              onTap: () =>
                  unawaited(channel.invokeMethod<void>('window.$command')),
              child: SizedBox(
                key: key,
                width: 46,
                height: 40,
                child: CustomPaint(
                  painter: _CaptionPainter(
                    command,
                    maximized,
                    hover && close
                        ? Colors.white
                        : active
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    scheduleRegions();
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: widget.titleBar(SizedBox(key: drag, height: 40)),
                ),
                if (!fullscreen) ...[
                  caption('minimize', context.l10n.minimize),
                  caption(
                    'toggleMaximize',
                    maximized ? context.l10n.restore : context.l10n.maximize,
                    key: maximize,
                  ),
                  caption('close', context.l10n.closeWindow),
                ],
              ],
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class _CaptionPainter extends CustomPainter {
  _CaptionPainter(this.command, this.maximized, this.color);
  final String command;
  final bool maximized;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate((size.width - 10) / 2, (size.height - 10) / 2);
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    if (command == 'minimize') {
      canvas.drawLine(const Offset(0, 5), const Offset(10, 5), pen);
    } else if (command == 'close') {
      canvas.drawLine(Offset.zero, const Offset(10, 10), pen);
      canvas.drawLine(const Offset(10, 0), const Offset(0, 10), pen);
    } else if (!maximized) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 10, 10), pen);
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(2, 2)
          ..lineTo(2, 0)
          ..lineTo(10, 0)
          ..lineTo(10, 8)
          ..lineTo(8, 8),
        pen,
      );
      canvas.drawRect(const Rect.fromLTWH(0, 2, 8, 8), pen);
    }
  }

  @override
  bool shouldRepaint(_CaptionPainter old) =>
      old.command != command ||
      old.maximized != maximized ||
      old.color != color;
}
