/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';
import 'tilde_design.dart';

EngineRecord defaultProfile(AndroidEngine engine) =>
    engine
        .list('profiles')
        .where((p) => p['id'] == engine.preferences['defaultProfileId'])
        .firstOrNull ??
    {};

String formatCount(String value) => value.replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);

Widget settingsNote(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
  child: Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
);

Widget settingsSection(
  BuildContext context,
  String title,
  List<Widget> children,
) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    if (title.isNotEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    if (title.isEmpty) const SizedBox(height: 20),
    Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1),
              ),
            children[i],
          ],
        ],
      ),
    ),
  ],
);

Color paletteColor(EngineRecord scheme, String role) {
  if (scheme['${role}Color'] is num) {
    return Color((scheme['${role}Color'] as num).toInt());
  }
  final palette = (scheme['palette'] as List? ?? []).cast<num>();
  final index = (scheme[role] as num?)?.toInt();
  if (index != null && index >= 0 && index < palette.length) {
    return Color(palette[index].toInt());
  }
  return role == 'background' ? Colors.black : const Color(0xffcccccc);
}

class TerminalPreview extends StatefulWidget {
  final AndroidEngine engine;
  final EngineRecord overrides;
  final bool framed;
  const TerminalPreview({
    super.key,
    required this.engine,
    this.overrides = const {},
    this.framed = true,
  });
  @override
  State<TerminalPreview> createState() => _TerminalPreviewState();
}

class _TerminalPreviewState extends State<TerminalPreview> {
  String? _fontName;
  Future<String>? _font;
  @override
  Widget build(BuildContext context) {
    final preferences = widget.engine.preferences;
    final profile = widget.overrides['profile'] is Map
        ? row(widget.overrides['profile'])
        : defaultProfile(widget.engine);
    final scheme =
        widget.engine
            .list('schemes')
            .where((s) => s['id'] == profile['colorSchemeId'])
            .firstOrNull ??
        const <String, dynamic>{};
    final name =
        '${widget.overrides['fontFamily'] ?? profile['fontFamily'] ?? preferences['fontFamily'] ?? 'JETBRAINS_MONO'}';
    if (name != _fontName) {
      _fontName = name;
      _font = widget.engine.terminalFont(name);
    }
    Color color(String role, Color fallback) =>
        widget.overrides['${role}Color'] is num
        ? Color((widget.overrides['${role}Color'] as num).toInt())
        : scheme.isEmpty
        ? fallback
        : paletteColor(scheme, role);
    final foreground = color('foreground', const Color(0xffeae9e7));
    final background = color('background', tildeNightBackground);
    final palette = (scheme['palette'] as List? ?? []).cast<num>();
    Color ansi(int index, Color fallback) =>
        palette.length > index ? Color(palette[index].toInt()) : fallback;
    final sample = widget.overrides['sampleText'] as String?;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            widget.overrides['compact'] == true ||
            constraints.hasBoundedHeight && constraints.maxHeight <= 56;
        final preview = Semantics(
          label: '색상 테마·글꼴·여백 미리보기',
          child: Container(
            padding: EdgeInsets.all(widget.framed ? 16 : 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(widget.framed ? 12 : 6),
            ),
            alignment: Alignment.topLeft,
            child: FutureBuilder<String>(
              future: _font,
              builder: (context, snapshot) => Text.rich(
                TextSpan(
                  children: sample != null
                      ? [TextSpan(text: sample)]
                      : [
                          TextSpan(
                            text: '~ \$ ls',
                            style: TextStyle(color: color('cursor', tildeTide)),
                          ),
                          TextSpan(
                            text: compact ? '  Aa' : '\nsrc  build  한글.md',
                          ),
                          if (!compact) ...[
                            const TextSpan(text: '\n'),
                            TextSpan(
                              text: 'err ',
                              style: TextStyle(color: ansi(1, tildeCoral)),
                            ),
                            TextSpan(
                              text: 'ok ',
                              style: TextStyle(
                                color: ansi(2, const Color(0xffa8d68f)),
                              ),
                            ),
                            TextSpan(
                              text: 'warn',
                              style: TextStyle(color: ansi(3, tildeSand)),
                            ),
                          ],
                        ],
                ),
                maxLines: compact ? 1 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: snapshot.data ?? tildeMono,
                  fontFamilyFallback: tildeMonoFallback,
                  fontSize: compact
                      ? 12
                      : (profile['fontSize'] as num? ?? 14).toDouble(),
                  height: 1.6,
                  color: foreground,
                ),
              ),
            ),
          ),
        );
        return compact
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: preview,
              )
            : preview;
      },
    );
  }
}

class TerminalBarPreview extends StatefulWidget {
  final List<String> order;
  final Set<String> hidden;
  final int height;
  final bool group;
  final List<EngineRecord> keys;
  const TerminalBarPreview({
    super.key,
    required this.order,
    required this.hidden,
    required this.height,
    required this.group,
    required this.keys,
  });
  @override
  State<TerminalBarPreview> createState() => _TerminalBarPreviewState();
}

class _TerminalBarPreviewState extends State<TerminalBarPreview> {
  bool functions = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFn =
        !widget.hidden.contains('FUNCTION_KEYS') &&
        widget.order.contains('FUNCTION_KEYS') &&
        widget.group;
    Widget key(String label, {bool selected = false, VoidCallback? onTap}) =>
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Material(
            color: selected ? cs.secondaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: switch (label) {
                    '⇥' || 'Tab' || 'tab' => 56,
                    '↑' || '↓' || '←' || '→' => 38,
                    '⌨' || 'Fn' => 40,
                    _ => 44,
                  },
                  minHeight: widget.height.toDouble(),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: switch (label) {
                      '⌨' || '↑' || '↓' || '←' || '→' => Icon(
                        switch (label) {
                          '↑' => Icons.keyboard_arrow_up,
                          '↓' => Icons.keyboard_arrow_down,
                          '←' => Icons.keyboard_arrow_left,
                          '→' => Icons.keyboard_arrow_right,
                          _ => Icons.keyboard_outlined,
                        },
                        size: 20,
                        color: cs.onSurface,
                      ),
                      _ => Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? cs.onSecondaryContainer
                              : cs.onSurface,
                        ),
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        );
    final visible = widget.order.where((k) => !widget.hidden.contains(k));
    final labels = <String>[];
    if (hasFn && functions) {
      labels.addAll([for (var i = 1; i <= 12; i++) 'F$i']);
    } else {
      for (final k in visible) {
        if (k == 'FUNCTION_KEYS') {
          if (!widget.group) {
            labels.addAll([for (var i = 1; i <= 12; i++) 'F$i']);
          }
        } else {
          labels.add(
            '${widget.keys.where((item) => item['name'] == k).firstOrNull?['label'] ?? k}',
          );
        }
      }
    }
    final bar = Semantics(
      label: '특수키 바 미리보기',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            key('Esc'),
            key('Ctrl'),
            Container(width: 1, height: 22, color: cs.outlineVariant),
            const SizedBox(width: 4),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: labels.map((l) => key(l)).toList()),
              ),
            ),
            const SizedBox(width: 4),
            key('⌨'),
            if (hasFn)
              key(
                'Fn',
                selected: functions,
                onTap: () => setState(() => functions = !functions),
              ),
            key('Tab'),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(
            300 * math.max(1, MediaQuery.textScalerOf(context).scale(13) / 13),
            constraints.maxWidth,
          ),
          child: bar,
        ),
      ),
    );
  }
}
