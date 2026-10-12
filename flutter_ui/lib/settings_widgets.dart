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

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'engine.dart';

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
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
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
  Object? requestKey;
  Future<EngineRecord>? image;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final p = widget.engine.preferences;
      final profile = widget.overrides['profile'] is Map
          ? row(widget.overrides['profile'])
          : defaultProfile(widget.engine);
      final scheme = widget.engine
          .list('schemes')
          .where((s) => s['id'] == profile['colorSchemeId'])
          .firstOrNull;
      final density = MediaQuery.devicePixelRatioOf(context);
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final nextKey = (
        constraints.maxWidth,
        density,
        scale,
        p['fontFamily'],
        profile.toString(),
        scheme.toString(),
        p['terminalMargin'],
        widget.overrides.toString(),
      );
      if (requestKey != nextKey) {
        requestKey = nextKey;
        image = widget.engine
            .query('settings.preview', {
              'width': constraints.maxWidth,
              'scale': density,
              'textScale': scale,
              ...widget.overrides,
            })
            .then(row);
      }
      return Semantics(
        label: '색상 테마·글꼴·여백 미리보기',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.framed ? 16 : 0),
            border: widget.framed
                ? Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  )
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<EngineRecord>(
            future: image,
            builder: (context, snapshot) {
              if (snapshot.data?['png'] is Uint8List) {
                return Image.memory(
                  snapshot.data!['png'] as Uint8List,
                  width: constraints.maxWidth,
                  height: (snapshot.data!['height'] as num).toDouble(),
                  fit: BoxFit.fitWidth,
                  gaplessPlayback: true,
                );
              }
              return SizedBox(
                height: widget.framed ? 100 : 30,
                child: Align(
                  alignment: widget.framed
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: Text(
                    widget.overrides['sampleText'] is String
                        ? widget.overrides['sampleText'] as String
                        : snapshot.connectionState == ConnectionState.waiting
                        ? '미리보기 불러오는 중…'
                        : '미리보기를 표시할 수 없어요',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
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
          padding: const EdgeInsets.only(right: 3),
          child: Material(
            color: selected ? cs.secondaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: switch (label) {
                  '⇥' => 34,
                  '↑' || '↓' || '←' || '→' => 32,
                  '⌨' || 'Fn' => 36,
                  'Home' || 'PgUp' || 'PgDn' => 44,
                  _ => 40,
                },
                height: widget.height.toDouble(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: label == '⌨'
                          ? Icon(
                              Icons.keyboard_outlined,
                              size: 18,
                              color: cs.onSurface,
                            )
                          : Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected
                                    ? cs.onSecondaryContainer
                                    : cs.onSurface,
                              ),
                            ),
                    ),
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
    return Semantics(
      label: '특수키 바 미리보기',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            key('Esc'),
            key('⇥'),
            key('Ctrl'),
            Container(width: 1, height: 18, color: cs.outlineVariant),
            const SizedBox(width: 3),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: labels.map((l) => key(l)).toList()),
              ),
            ),
            const SizedBox(width: 3),
            key('⌨'),
            if (hasFn)
              key(
                'Fn',
                selected: functions,
                onTap: () => setState(() => functions = !functions),
              ),
          ],
        ),
      ),
    );
  }
}
