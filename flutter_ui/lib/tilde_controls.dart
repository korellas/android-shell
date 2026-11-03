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
  Object? current, {
  bool navigation = false,
  Map<Object?, String> subtitles = const {},
}) {
  if (tildePointer(context)) {
    final items = values.length <= 8
        ? <PopupMenuEntry<(Object?, String)>>[
            for (final option in values)
              PopupMenuItem(
                value: option,
                height: subtitles.isEmpty ? 32 : 48,
                child: Row(
                  children: [
                    Expanded(child: Text(option.$2)),
                    if (navigation)
                      const Icon(Icons.chevron_right, size: 18)
                    else if (option.$1 == current)
                      Icon(
                        Icons.check,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
          ]
        : <PopupMenuEntry<(Object?, String)>>[
            PopupMenuItem(
              enabled: false,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 320,
                child: TildeChoicePage(
                  title: title,
                  values: values,
                  current: current,
                  embedded: true,
                  navigation: navigation,
                  subtitles: subtitles,
                  showTitle: false,
                ),
              ),
            ),
          ];
    return showMenu<(Object?, String)>(
      context: context,
      position: _tildeMenuPosition(context),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      items: items,
    );
  }
  return showTildeSheet<(Object?, String)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TildeChoicePage(
      title: title,
      values: values,
      current: current,
      embedded: true,
      navigation: navigation,
      subtitles: subtitles,
    ),
  );
}

RelativeRect _tildeMenuPosition(BuildContext context, [Offset? position]) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final target = context.findRenderObject();
  final rect = target is RenderBox && target.hasSize
      ? target.localToGlobal(Offset.zero, ancestor: overlay) & target.size
      : const Rect.fromLTWH(16, 16, 0, 0);
  final point = position == null
      ? (rect.height > 100 ? const Offset(16, 56) : rect.bottomLeft)
      : overlay.globalToLocal(position);
  return RelativeRect.fromRect(
    Rect.fromLTWH(point.dx, point.dy, rect.height > 100 ? 0 : rect.width, 0),
    Offset.zero & overlay.size,
  );
}

String tildeShortFingerprint(String value, {int length = 34}) =>
    value.length <= length
    ? value
    : '${value.substring(0, (length - 1) ~/ 2)}…${value.substring(value.length - (length - 1) ~/ 2)}';

Widget tildeSearchLabel(BuildContext context, String text, String query) {
  final index = query.isEmpty
      ? -1
      : text.toLowerCase().indexOf(query.toLowerCase());
  if (index < 0) return Text(text);
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(text: text.substring(0, index)),
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(text: text.substring(index + query.length)),
      ],
    ),
  );
}

class TildeChoicePage extends StatefulWidget {
  final String title;
  final List<(Object?, String)> values;
  final Object? current;
  final bool embedded, navigation, showTitle;
  final Map<Object?, String> subtitles;
  const TildeChoicePage({
    super.key,
    required this.title,
    required this.values,
    this.current,
    this.embedded = false,
    this.navigation = false,
    this.subtitles = const {},
    this.showTitle = true,
  });
  @override
  State<TildeChoicePage> createState() => _TildeChoicePageState();
}

class _TildeChoicePageState extends State<TildeChoicePage> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final pointer = tildePointer(context),
        searchable = widget.values.length > 8;
    final rowHeight = pointer ? (widget.subtitles.isEmpty ? 32.0 : 48.0) : 56.0;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedded && widget.showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        if (searchable)
          Padding(
            padding: EdgeInsets.fromLTRB(
              pointer ? 12 : 24,
              4,
              pointer ? 12 : 24,
              8,
            ),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '검색',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => search = value.trim().toLowerCase()),
            ),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(bottom: pointer ? 4 : 16),
            children: [
              for (final option in widget.values.where(
                (value) => ('${value.$2} ${widget.subtitles[value.$1] ?? ''}')
                    .toLowerCase()
                    .contains(search),
              ))
                ListTile(
                  minTileHeight: rowHeight,
                  dense: pointer,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: pointer ? 12 : 24,
                  ),
                  title: tildeSearchLabel(context, option.$2, search),
                  subtitle: widget.subtitles[option.$1] == null
                      ? null
                      : Text(widget.subtitles[option.$1]!),
                  trailing: widget.navigation
                      ? const Icon(Icons.chevron_right, size: 18)
                      : option.$1 == widget.current
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ],
    );
    if (!widget.embedded) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: content,
      );
    }
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.min(
            MediaQuery.sizeOf(context).height * .75,
            widget.values.length * rowHeight +
                (searchable ? 68 : 0) +
                (widget.showTitle ? 52 : 0) +
                24,
          ),
        ),
        child: content,
      ),
    );
  }
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

class TildeActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const TildeActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final horizontal = MediaQuery.textScalerOf(context).scale(14) > 21;
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 72),
        padding: const EdgeInsets.all(8),
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          SizedBox(width: horizontal ? 8 : 0, height: horizontal ? 0 : 8),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

Widget tildeActionButtons(BuildContext context, List<Widget> actions) =>
    LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(15) > 21) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                actions[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: actions[i]),
            ],
          ],
        );
      },
    );

ButtonStyle tildeDangerButtonStyle(BuildContext context) =>
    FilledButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.error.withValues(alpha: .14),
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
    final colors = Theme.of(context).colorScheme;
    final status = busy
        ? const TildeProgress.circular(label: '저장 중')
        : Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$changes개 변경됨',
                  style: TextStyle(color: colors.onSurface),
                ),
              ),
            ],
          );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colors.onSurface),
          onPressed: busy ? null : cancel,
          child: const Text('되돌리기'),
        ),
        FilledButton(onPressed: busy ? null : save, child: Text(saveLabel)),
      ],
    );
    final bar = Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [status, const SizedBox(height: 8), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: status),
              const SizedBox(width: 8),
              actions,
            ],
          );
        },
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
  List<Color> swatches = const [],
}) => showTildeSheet<Color>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => TildeColorSheet(
    initial: initial,
    title: title,
    onPreview: onPreview,
    swatches: swatches,
  ),
);

class TildeColorSheet extends StatefulWidget {
  final Color initial;
  final List<Color> swatches;
  final String title;
  final ValueChanged<Color>? onPreview;
  const TildeColorSheet({
    super.key,
    required this.initial,
    required this.title,
    this.onPreview,
    this.swatches = const [],
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
            if (widget.swatches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in widget.swatches)
                      Tooltip(
                        message:
                            '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                        child: InkWell(
                          onTap: () => setColor(HSVColor.fromColor(color)),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
                counterText: '',
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
                FilledButton(
                  onPressed: () {
                    final n = int.tryParse(hex.text, radix: 16);
                    if (hex.text.length != 6 || n == null) {
                      setState(() => error = '6자리 색상을 입력하세요');
                      return;
                    }
                    Navigator.pop(context, Color(0xff000000 | n));
                  },
                  child: const Text('적용'),
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

class TildeMenuLabel extends StatelessWidget {
  const TildeMenuLabel(
    this.label,
    this.icon, {
    super.key,
    this.danger = false,
    this.selected = false,
    this.shortcut,
  });
  final String? shortcut;
  final String label;
  final IconData icon;
  final bool danger, selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          size: tildePointer(context) ? 18 : 24,
          color: danger ? colors.error : colors.onSurfaceVariant,
        ),
        SizedBox(width: tildePointer(context) ? 12 : 14),
        Expanded(
          child: Text(
            label,
            maxLines: tildePointer(context) ? 1 : null,
            overflow: tildePointer(context) ? TextOverflow.ellipsis : null,
            style: TextStyle(
              fontSize: tildePointer(context) ? 14 : 15,
              color: danger ? colors.error : colors.onSurface,
            ),
          ),
        ),
        if (tildePointer(context) && shortcut != null)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              shortcut!,
              style: TextStyle(
                fontFamily: tildeMono,
                fontFamilyFallback: tildeMonoFallback,
                fontSize: 11.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        if (selected) ...[
          const SizedBox(width: 12),
          Icon(Icons.check, size: 20, color: colors.primary),
        ],
      ],
    );
  }
}

class TildeItemMenu<T> extends StatelessWidget {
  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T>? onSelected;
  final String tooltip;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? leading;
  const TildeItemMenu({
    super.key,
    required this.itemBuilder,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onSelected,
    this.tooltip = '메뉴',
    this.leading,
  });

  static Future<R?> show<R>(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? subtitle,
    Widget? leading,
    Offset? position,
    required PopupMenuItemBuilder<R> itemBuilder,
  }) {
    if (tildePointer(context)) {
      final theme = Theme.of(context);
      return showMenu<R>(
        context: context,
        position: _tildeMenuPosition(context, position),
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
        items: [
          for (final entry in itemBuilder(context))
            if (entry is PopupMenuItem<R>)
              PopupMenuItem<R>(
                value: entry.value,
                enabled: entry.enabled,
                onTap: entry.onTap,
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Theme(
                  data: theme.copyWith(
                    listTileTheme: theme.listTileTheme.copyWith(
                      minTileHeight: 32,
                      contentPadding: EdgeInsets.zero,
                      minLeadingWidth: 18,
                    ),
                    iconTheme: theme.iconTheme.copyWith(size: 18),
                  ),
                  child: entry.child!,
                ),
              )
            else if (entry is PopupMenuDivider)
              const PopupMenuDivider(height: 9),
        ],
      );
    }
    return showTildeSheet<R>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(c).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotEmpty) ...[
                  ListTile(
                    leading:
                        leading ??
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(c).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 24),
                        ),
                    title: Text(title, style: Theme.of(c).textTheme.titleLarge),
                    subtitle: subtitle == null ? null : Text(subtitle),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(),
                  ),
                ],
                for (final item in itemBuilder(c))
                  if (item is PopupMenuItem<R>)
                    ListTile(
                      minTileHeight: 56,
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
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Divider(),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (anchor) {
      Future<void> open([Offset? position]) async {
        final selected = await show<T>(
          anchor,
          title: title,
          icon: icon,
          subtitle: subtitle,
          leading: leading,
          itemBuilder: itemBuilder,
          position: position,
        );
        if (selected != null) onSelected?.call(selected);
      }

      return GestureDetector(
        onSecondaryTapUp: (event) => open(event.globalPosition),
        child: IconButton(
          tooltip: tooltip,
          icon: const Icon(Icons.more_vert),
          onPressed: open,
        ),
      );
    },
  );
}
