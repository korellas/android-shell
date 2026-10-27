/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 */
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tilde_design.dart';
import 'settings_widgets.dart' show formatCount;

Future<(Object?, String)?> pickTildeOption(
  BuildContext context,
  String title,
  List<(Object?, String)> values,
  Object? current,
) => Navigator.push<(Object?, String)>(
  context,
  MaterialPageRoute(
    builder: (_) =>
        TildeChoicePage(title: title, values: values, current: current),
  ),
);

class TildeChoicePage extends StatefulWidget {
  final String title;
  final List<(Object?, String)> values;
  final Object? current;
  const TildeChoicePage({
    super.key,
    required this.title,
    required this.values,
    this.current,
  });
  @override
  State<TildeChoicePage> createState() => _TildeChoicePageState();
}

class _TildeChoicePageState extends State<TildeChoicePage> {
  String search = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '검색',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final option in widget.values.where(
                (v) => v.$2.toLowerCase().contains(search),
              ))
                ListTile(
                  title: Text(option.$2),
                  leading: Icon(
                    option.$1 == widget.current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: option.$1 == widget.current
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget tildeSegments(
  BuildContext context,
  String label,
  List<(Object?, String)> options,
  Object? value,
  ValueChanged<Object?>? onChanged, {
  Map<Object?, Widget> labels = const {},
}) {
  final values = [...options];
  if (!values.any((v) => v.$1 == value)) values.add((value, '$value (현재 값)'));
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final vertical =
                MediaQuery.textScalerOf(context).scale(14) > 21 ||
                c.maxWidth < values.length * 68;
            return SegmentedButton<Object?>(
              key: ValueKey(vertical),
              segments: [
                for (final v in values)
                  ButtonSegment(value: v.$1, label: labels[v.$1] ?? Text(v.$2)),
              ],
              selected: {value},
              direction: vertical ? Axis.vertical : Axis.horizontal,
              showSelectedIcon: false,
              expandedInsets: vertical ? null : EdgeInsets.zero,
              onSelectionChanged: onChanged == null
                  ? null
                  : (v) => onChanged(v.first),
            );
          },
        ),
      ],
    ),
  );
}

Widget tildeRadioOptions(
  BuildContext context,
  List<(Object?, String)> options,
  Object? value,
  ValueChanged<Object?>? onChanged, {
  Map<Object?, String> subtitles = const {},
}) => Column(
  children: [
    for (final option in options)
      ListTile(
        leading: Icon(
          option.$1 == value
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: option.$1 == value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(option.$2),
        subtitle: subtitles[option.$1] == null
            ? null
            : Text(
                subtitles[option.$1]!,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontFamilyFallback: ['Pretendard'],
                  fontSize: 12.5,
                ),
              ),
        selected: false,
        onTap: onChanged == null ? null : () => onChanged(option.$1),
      ),
  ],
);

class TildeSaveBar extends StatelessWidget {
  final int changes;
  final bool busy;
  final VoidCallback cancel, save;
  final String saveLabel;
  const TildeSaveBar({
    super.key,
    required this.changes,
    required this.busy,
    required this.cancel,
    required this.save,
    this.saveLabel = '저장',
  });
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final bar = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: busy
                ? const TildeProgress.circular(label: '저장 중')
                : Text(
                    '$changes개 변경됨',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
          ),
          TextButton(
            onPressed: busy ? null : cancel,
            child: const Text('되돌리기'),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: busy ? null : save, child: Text(saveLabel)),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.bottomRight,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 420 : double.infinity),
            child: bar,
          ),
        ),
      ),
    );
  }
}

class TildeStepper extends StatefulWidget {
  final String title, unit;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;
  const TildeStepper({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.unit = '',
    this.min = 0,
    this.max = 100000,
    this.step = 1,
  });
  @override
  State<TildeStepper> createState() => _TildeStepperState();
}

class _TildeStepperState extends State<TildeStepper> {
  bool editing = false;
  String? error;
  late final controller = TextEditingController(text: '${widget.value}');
  @override
  void didUpdateWidget(TildeStepper old) {
    super.didUpdateWidget(old);
    if (!editing) controller.text = '${widget.value}';
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void apply(String raw) {
    final n = int.tryParse(raw.replaceAll(',', ''));
    if (n == null || n < widget.min || n > widget.max) {
      setState(() => error = '${widget.min}–${widget.max} 사이로 입력하세요');
      return;
    }
    setState(() {
      editing = false;
      error = null;
    });
    widget.onChanged(n);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title),
                  if (widget.unit.isNotEmpty)
                    Text(
                      widget.unit,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: '${widget.title} 줄이기',
              onPressed: widget.value <= widget.min
                  ? null
                  : () => widget.onChanged(
                      (widget.value - widget.step).clamp(
                        widget.min,
                        widget.max,
                      ),
                    ),
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 92,
              child: editing
                  ? TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      onSubmitted: apply,
                      onTapOutside: (_) => apply(controller.text),
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontFamily: 'Pretendard'),
                    )
                  : TextButton(
                      onPressed: () => setState(() {
                        editing = true;
                        controller.text = '${widget.value}';
                      }),
                      child: Text(
                        formatCount('${widget.value}'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
            ),
            IconButton(
              tooltip: '${widget.title} 늘리기',
              onPressed: widget.value >= widget.max
                  ? null
                  : () => widget.onChanged(
                      (widget.value + widget.step).clamp(
                        widget.min,
                        widget.max,
                      ),
                    ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}

Future<bool> discardTildeChanges(BuildContext context) async =>
    await showTildeSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('변경 사항 버리기', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text('저장하지 않은 변경 사항이 사라집니다.'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('계속 편집'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(c).colorScheme.error,
                    ),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('버리기'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ??
    false;

Future<Color?> pickTildeColor(
  BuildContext context,
  Color initial, {
  String title = '색상 선택',
  ValueChanged<Color>? onPreview,
}) => showTildeSheet<Color>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      TildeColorSheet(initial: initial, title: title, onPreview: onPreview),
);

class TildeColorSheet extends StatefulWidget {
  final Color initial;
  final String title;
  final ValueChanged<Color>? onPreview;
  const TildeColorSheet({
    super.key,
    required this.initial,
    required this.title,
    this.onPreview,
  });
  @override
  State<TildeColorSheet> createState() => _TildeColorSheetState();
}

class _TildeColorSheetState extends State<TildeColorSheet> {
  late HSVColor hsv = HSVColor.fromColor(widget.initial);
  late final hex = TextEditingController(
    text: widget.initial
        .toARGB32()
        .toRadixString(16)
        .substring(2)
        .toUpperCase(),
  );
  String? error;
  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  void setColor(HSVColor v) {
    setState(() {
      hsv = v;
      hex.text = v
          .toColor()
          .toARGB32()
          .toRadixString(16)
          .substring(2)
          .toUpperCase();
      error = null;
    });
    widget.onPreview?.call(v.toColor());
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Center(
              child: SizedBox.square(
                dimension: 180,
                child: GestureDetector(
                  onPanDown: (d) => wheel(d.localPosition),
                  onPanUpdate: (d) => wheel(d.localPosition),
                  child: CustomPaint(
                    painter: _ColorWheelPainter(hsv),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Slider(
              value: hsv.value,
              onChanged: (v) => setColor(hsv.withValue(v)),
              label: '밝기',
            ),
            TextField(
              controller: hex,
              decoration: InputDecoration(
                labelText: '16진 색상',
                prefixText: '#',
                errorText: error,
                errorMaxLines: 3,
              ),
              maxLength: 6,
              onChanged: (raw) {
                final n = int.tryParse(raw, radix: 16);
                if (raw.length == 6 && n != null) {
                  setState(() {
                    hsv = HSVColor.fromColor(Color(0xff000000 | n));
                    error = null;
                  });
                  widget.onPreview?.call(hsv.toColor());
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hsv.toColor(),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    final n = int.tryParse(hex.text, radix: 16);
                    if (hex.text.length != 6 || n == null) {
                      setState(() => error = '6자리 색상을 입력하세요');
                      return;
                    }
                    Navigator.pop(context, Color(0xff000000 | n));
                  },
                  child: const Text('사용'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  void wheel(Offset p) {
    final dx = p.dx - 90, dy = p.dy - 90;
    setColor(
      hsv
          .withHue((math.atan2(dy, dx) * 180 / 3.141592653589793 + 360) % 360)
          .withSaturation(
            (p - const Offset(90, 90)).distance / 90 > 1
                ? 1
                : (p - const Offset(90, 90)).distance / 90,
          ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final HSVColor hsv;
  _ColorWheelPainter(this.hsv);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), r = size.width / 2;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xffff0000),
            Color(0xffffff00),
            Color(0xff00ff00),
            Color(0xff00ffff),
            Color(0xff0000ff),
            Color(0xffff00ff),
            Color(0xffff0000),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0x00ffffff)],
        ).createShader(Offset.zero & size),
    );
    final a = hsv.hue * math.pi / 180;
    canvas.drawCircle(
      center + Offset(math.cos(a), math.sin(a)) * r * hsv.saturation,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_ColorWheelPainter old) => old.hsv != hsv;
}

class TildeItemMenu<T> extends StatelessWidget {
  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T>? onSelected;
  final String tooltip;
  const TildeItemMenu({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.tooltip = '메뉴',
  });
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: const Icon(Icons.more_vert),
    onPressed: () async {
      final selected = await showTildeSheet<T>(
        context: context,
        builder: (c) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in itemBuilder(c))
                  if (item is PopupMenuItem<T>)
                    ListTile(
                      enabled: item.enabled,
                      title: item.child,
                      onTap: !item.enabled
                          ? null
                          : () {
                              item.onTap?.call();
                              Navigator.pop(c, item.value);
                            },
                    )
                  else if (item is PopupMenuDivider)
                    const Divider(),
              ],
            ),
          ),
        ),
      );
      if (selected != null) onSelected?.call(selected);
    },
  );
}
