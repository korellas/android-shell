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

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'tilde_design.dart';
import 'tilde_controls.dart';
import 'main.dart';
import 'editors.dart';
import 'management.dart';
import 'settings_widgets.dart';
import 'settings_advertising.dart';
import 'l10n/strings.dart';

class SettingsPage extends StatefulWidget {
  final AndroidEngine engine;
  final Widget? initialPage;
  const SettingsPage({super.key, required this.engine, this.initialPage});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AndroidEngine get engine => widget.engine;
  String? category;
  late Widget? managementPage = widget.initialPage;
  final managementNavigator = GlobalKey<NavigatorState>();
  Future<void> update(BuildContext c, String key, dynamic value) =>
      runEngine(c, engine, 'settings.update', {'key': key, 'value': value});

  String sidebarQuery = '';
  int searchSelection = 0;
  final searchFocus = FocusNode();
  String buildingCategory = 'display';
  final searchTargets = <String, (String, String)>{};
  final rowKeys = <String, GlobalKey>{};
  String? highlighted;
  Timer? highlightTimer;
  @override
  void dispose() {
    highlightTimer?.cancel();
    searchFocus.dispose();
    super.dispose();
  }

  Widget tracked(String key, String label, Widget child) {
    searchTargets[key] = (buildingCategory, label);
    return AnimatedContainer(
      key: rowKeys.putIfAbsent(key, () => GlobalKey()),
      duration: const Duration(milliseconds: 240),
      color: highlighted == key
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: child,
    );
  }

  Widget toggle(
    BuildContext c,
    String key,
    String label, {
    String? sub,
    bool enabled = true,
    IconData? icon,
  }) => tracked(
    key,
    label,
    SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: icon == null ? null : Icon(icon, size: 24),
      title: Text(label),
      subtitle: sub == null ? null : Text(sub),
      value: engine.preferences[key] == true,
      onChanged: enabled ? (v) => update(c, key, v) : null,
    ),
  );
  Widget choice(
    BuildContext c,
    String key,
    String label,
    List<(Object?, String)> values, {
    VoidCallback? manage,
    bool forceList = false,
  }) {
    final current = engine.preferences[key] ?? values.firstOrNull?.$1;
    final options = [...values];
    if (current != null && !options.any((v) => v.$1 == current)) {
      options.add((current, c.l10n.currentValue((current).toString())));
    }
    return tracked(
      key,
      label,
      !forceList && options.length <= 4
          ? tildeSegments(c, label, options, current, (v) => update(c, key, v))
          : Builder(
              builder: (anchor) => ListTile(
                title: Text(label),
                subtitle: Text(
                  options.where((v) => v.$1 == current).firstOrNull?.$2 ??
                      c.l10n.select,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await pickTildeOption(
                    anchor,
                    label,
                    options,
                    current,
                  );
                  if (result != null && c.mounted) {
                    await update(c, key, result.$1);
                  }
                },
              ),
            ),
    );
  }

  Widget radio(
    BuildContext c,
    String key,
    List<(Object?, String)> options, {
    required String label,
    Map<Object?, String> subtitles = const {},
  }) => tracked(
    key,
    label,
    tildeRadioOptions(
      c,
      options,
      engine.preferences[key] ?? options.first.$1,
      (v) => update(c, key, v),
      subtitles: subtitles,
    ),
  );
  Future<void> googleFonts(BuildContext c) async {
    final cStrings = c.l10n;
    final values = [
      for (final font in rows(engine.preferences['fonts']))
        if (font['value'] != 'SYSTEM_DEFAULT' && font['value'] != 'D2CODING')
          (font['value'], '${font['label']}'),
    ];
    final result = await pickTildeOption(
      c,
      cStrings.googleFontsMonospace,
      values,
      engine.preferences['fontFamily'],
    );
    if (result != null && c.mounted) {
      if (result.$1 == 'JETBRAINS_MONO') {
        await update(c, 'fontFamily', result.$1);
      } else {
        await runEngine(c, engine, 'font.custom', {'name': result.$2});
      }
    }
  }

  void indexSettings() {
    searchTargets.clear();
    for (final id in [
      'display',
      'keyboard',
      'gesture',
      'terminal',
      'connection',
      'security',
      'fonts',
    ]) {
      fields(context, id);
    }
  }

  Future<bool> leaveManagement() async {
    final nav = managementNavigator.currentState;
    if (nav?.canPop() == true) {
      await nav!.maybePop();
      if (!mounted || nav.canPop()) return false;
    }
    return mounted;
  }

  Future<void> selectCategory(String id) async {
    if (!await leaveManagement()) return;
    setState(() {
      category = id;
      managementPage = null;
    });
  }

  Future<void> searchSettings([BuildContext? anchor]) async {
    final contextStrings = context.l10n;
    indexSettings();
    final result = await pickTildeOption(
      anchor ?? context,
      contextStrings.searchSettings,
      [for (final e in searchTargets.entries) (e.key, e.value.$2)],
      null,
      navigation: true,
      subtitles: {
        for (final e in searchTargets.entries) e.key: title(e.value.$1),
      },
    );
    if (result == null || !mounted) return;
    final key = result.$1 as String;
    navigateSetting(key);
  }

  Future<void> navigateSetting(String key) async {
    if (!await leaveManagement()) return;
    setState(() {
      managementPage = null;
      category = searchTargets[key]!.$1;
      highlighted = key;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = rowKeys[key]?.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(
          c,
          duration: const Duration(milliseconds: 240),
          alignment: .25,
        );
      }
    });
    highlightTimer?.cancel();
    highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => highlighted = null);
    });
  }

  String title(String id) => switch (id) {
    'display' => context.l10n.display,
    'keyboard' => context.l10n.keyboard,
    'gesture' => context.l10n.gestures,
    'terminal' => context.l10n.terminal,
    'connection' => context.l10n.connectionsAndNotifications,
    'security' => context.l10n.securityAndBackup,
    'fonts' => context.l10n.manageFonts,
    'bar' => context.l10n.specialKeyBar,
    _ => context.l10n.settings,
  };
  String summary(String id) {
    final p = engine.preferences;
    final profile = defaultProfile(engine);
    final scheme = engine
        .list('schemes')
        .where((s) => s['id'] == profile['colorSchemeId'])
        .firstOrNull;
    return switch (id) {
      'display' => '${scheme?['name'] ?? 'Tilde Night'}',
      'keyboard' => context.l10n.specialKeys(
        (((p['terminalBarOrder'] as List? ?? []).where(
          (k) => !(p['terminalBarHidden'] as List? ?? []).contains(k),
        )).length).toString(),
      ),
      'gesture' => context.l10n.twoFingerHorizontalSwipe(
        (p['swipeTmux'] == true
                ? context.l10n.tmuxWindows
                : p['swipeSessions'] == true
                ? context.l10n.session2
                : context.l10n.disabled2)
            .toString(),
      ),
      'terminal' => '${profile['name'] ?? context.l10n.defaultTerminal}',
      'connection' => context.l10n.notificationsAndBell,
      'security' => context.l10n.sshKeys2((engine.list('keys').length)),
      _ => '',
    };
  }

  Widget categories(String? selected) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final items = [
      ('display', Icons.palette_outlined),
      ('keyboard', Icons.keyboard_outlined),
      ('gesture', Icons.swipe_outlined),
      ('terminal', Icons.terminal_outlined),
      ('connection', Icons.notifications_outlined),
      ('security', Icons.lock_outline),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (tildePointer(context)) ...[
          Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final results = searchTargets.entries
                  .where(
                    (e) => '${e.value.$2} ${title(e.value.$1)}'
                        .toLowerCase()
                        .contains(sidebarQuery.toLowerCase()),
                  )
                  .toList();
              if (sidebarQuery.isEmpty || results.isEmpty) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                setState(
                  () =>
                      searchSelection = (searchSelection + 1) % results.length,
                );
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                setState(
                  () =>
                      searchSelection = (searchSelection - 1) % results.length,
                );
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                navigateSetting(
                  results[searchSelection.clamp(0, results.length - 1)].key,
                );
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              focusNode: searchFocus,
              decoration: tildeToolbarInput(
                context,
                InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: context.l10n.searchSettings,
                ),
              ),
              onChanged: (value) {
                indexSettings();
                setState(() {
                  sidebarQuery = value;
                  searchSelection = 0;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          if (sidebarQuery.isNotEmpty) ...[
            for (final (index, e)
                in searchTargets.entries
                    .where(
                      (e) => '${e.value.$2} ${title(e.value.$1)}'
                          .toLowerCase()
                          .contains(sidebarQuery.toLowerCase()),
                    )
                    .indexed)
              ListTile(
                selected: index == searchSelection,
                title: tildeSearchLabel(context, e.value.$2, sidebarQuery),
                subtitle: Text(title(e.value.$1)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => navigateSetting(e.key),
              ),
          ],
        ],
        if (wide && sidebarQuery.isEmpty)
          for (final (id, icon) in items)
            ListTile(
              selected: selected == id,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerLow,
              selectedColor: Theme.of(context).colorScheme.onSurface,
              leading: Icon(
                icon,
                size: 22,
                color: selected == id
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                title(id),
                style: TextStyle(
                  fontWeight: selected == id
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              subtitle: tildePointer(context) ? null : Text(summary(id)),
              onTap: () => selectCategory(id),
            )
        else if (sidebarQuery.isEmpty)
          LayoutBuilder(
            builder: (context, c) {
              final columns = MediaQuery.textScalerOf(context).scale(15) > 24
                  ? 1
                  : 2;
              final width = (c.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (id, icon) in items)
                    SizedBox(
                      width: width,
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => selectCategory(id),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: 22),
                                const SizedBox(height: 20),
                                Text(
                                  title(id),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  summary(id),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.help_outline, size: 22),
          title: Text(context.l10n.helpAndLogs2),
          selected: selected == 'help',
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (!await leaveManagement()) return;
            if (!mounted) return;
            if (tildePointer(context) && wide) {
              setState(() => managementPage = HelpPage(engine: engine));
            } else {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => HelpPage(engine: engine),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> importFont(BuildContext c) async {
    await runEngine(c, engine, 'font.import');
  }

  Widget margin(BuildContext c) {
    final current =
        (engine.preferences['terminalMargin'] as num?)?.toInt() ?? 0;
    return tracked(
      'terminalMargin',
      c.l10n.horizontalMargins,
      tildeSegments(
        c,
        c.l10n.horizontalMargins,
        [
          for (final v in {0, 4, 8, 12, current})
            (v, v == 0 ? c.l10n.none : '$v'),
        ],
        current,
        (v) => update(c, 'terminalMargin', v),
      ),
    );
  }

  Widget scrollback(BuildContext c) => tracked(
    'scrollback',
    c.l10n.scrollback,
    TildeStepper(
      title: c.l10n.scrollback,
      unit: c.l10n.lines,
      value: int.tryParse('${engine.preferences['scrollback'] ?? 140}') ?? 140,
      step: 500,
      onChanged: (v) => update(c, 'scrollback', '$v'),
    ),
  );

  List<Widget> fields(BuildContext c, String id) {
    buildingCategory = id;
    final p = engine.preferences;
    final largeText = MediaQuery.textScalerOf(c).scale(15) > 20;
    final profile = defaultProfile(engine);
    final scheme = engine
        .list('schemes')
        .where((s) => s['id'] == profile['colorSchemeId'])
        .firstOrNull;
    Widget group(String title, List<Widget> rows) =>
        settingsSection(c, title, rows);
    Widget go(
      String key,
      String label,
      VoidCallback action, {
      String? sub,
      IconData? icon,
      bool enabled = true,
    }) => tracked(
      key,
      label,
      ListTile(
        leading: icon == null ? null : Icon(icon, size: 24),
        title: Text(label),
        subtitle: sub == null ? null : Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? action : null,
      ),
    );
    void page(Widget child) {
      if (tildePointer(c) && MediaQuery.sizeOf(c).width >= 720) {
        setState(() => managementPage = child);
      } else {
        Navigator.push(c, MaterialPageRoute<void>(builder: (_) => child));
      }
    }

    switch (id) {
      case 'display':
        final fontPreview = TerminalPreview(
          engine: engine,
          framed: false,
          overrides: {
            'fontFamily': p['fontFamily'],
            'sampleText': fontLabel(engine, p['fontFamily']),
            'compact': true,
            'backgroundColor': 0,
            'foregroundColor': Theme.of(c).colorScheme.onSurface.toARGB32(),
            'profile': {...profile, 'fontSize': 13},
          },
        );
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TerminalPreview(engine: engine, framed: false),
          ),
          group('', [
            tracked(
              'themeMode',
              c.l10n.appTheme,
              Padding(
                padding: const EdgeInsets.all(16),
                child: OverflowBar(
                  spacing: 16,
                  overflowSpacing: 8,
                  alignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c.l10n.appTheme),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: 'SYSTEM',
                          icon: Icon(Icons.brightness_auto_outlined),
                          tooltip: c.l10n.systemTheme,
                          label: Text(c.l10n.automatic),
                        ),
                        ButtonSegment(
                          value: 'LIGHT',
                          icon: Icon(Icons.light_mode_outlined),
                          tooltip: c.l10n.light,
                          label: Text(c.l10n.light),
                        ),
                        ButtonSegment(
                          value: 'DARK',
                          icon: Icon(Icons.dark_mode_outlined),
                          tooltip: c.l10n.dark,
                          label: Text(c.l10n.dark),
                        ),
                      ],
                      selected: {'${p['themeMode'] ?? 'SYSTEM'}'},
                      onSelectionChanged: (v) =>
                          update(c, 'themeMode', v.first),
                    ),
                  ],
                ),
              ),
            ),
            tracked(
              'schemes',
              c.l10n.colorTheme,
              ListTile(
                title: Text(c.l10n.colorTheme),
                subtitle: largeText
                    ? Text('${scheme?['name'] ?? 'Tilde Night'}')
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!largeText)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 112),
                        child: Text(
                          '${scheme?['name'] ?? 'Tilde Night'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(c).textTheme.bodySmall,
                        ),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => page(SchemesPage(engine: engine)),
              ),
            ),
            tracked(
              'fontFamily',
              c.l10n.font,
              ListTile(
                title: Text(c.l10n.font),
                subtitle: largeText ? fontPreview : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!largeText) SizedBox(width: 140, child: fontPreview),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => setState(() => category = 'fonts'),
              ),
            ),
          ]),
          if (profile['id'] is int)
            group('', [
              tracked(
                'fontSize',
                c.l10n.fontSize,
                TildeStepper(
                  title: c.l10n.fontSize,
                  unit: 'sp',
                  value: (profile['fontSize'] as num? ?? 14).toInt(),
                  min: 4,
                  max: 72,
                  onChanged: (value) => runEngine(c, engine, 'profile.save', {
                    ...profile,
                    'fontSize': value,
                  }),
                ),
              ),
            ]),
          if (!tildePointer(c))
            group('', [
              choice(c, 'rotation', c.l10n.orientation, [
                ('Default', c.l10n.automatic),
                ('Automatic', c.l10n.alwaysRotate),
                ('Force portrait', c.l10n.portrait),
                ('Force landscape', c.l10n.landscape),
              ]),
              toggle(c, 'fullscreen', c.l10n.hideStatusBar),
              toggle(c, 'titlebarhide', c.l10n.autoHideTitleBar),
            ]),
        ];
      case 'keyboard':
        return [
          group('', [
            tracked(
              'terminalBar',
              c.l10n.specialKeyLayout,
              ListTile(
                title: Text(c.l10n.specialKeyBar),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TerminalBarPreview(
                    order: (p['terminalBarOrder'] as List? ?? [])
                        .cast<String>(),
                    hidden: (p['terminalBarHidden'] as List? ?? [])
                        .cast<String>()
                        .toSet(),
                    height: (p['terminalBarHeight'] as int?) ?? 36,
                    group: p['terminalBarFn'] == true,
                    keys: rows(p['barKeys']),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => category = 'bar'),
              ),
            ),
            toggle(c, 'alwaysvisible', c.l10n.showWhenKeyboardIsClosed),
            tracked(
              'stickymodifiers',
              c.l10n.whenPressingCtrlOrAlt,
              tildeSegments(
                c,
                c.l10n.whenPressingCtrlOrAlt,
                [
                  ('no', c.l10n.once),
                  ('yes', c.l10n.sticky),
                  ('alt', c.l10n.stickyAltOnly),
                ],
                p['stickymodifiers'] ?? 'no',
                (v) => update(c, 'stickymodifiers', v),
                labels: {
                  for (final (value, label) in [
                    ('no', c.l10n.once),
                    ('yes', c.l10n.sticky),
                    ('alt', c.l10n.stickyAltOnly),
                  ])
                    value: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final name
                                  in value == 'alt'
                                      ? ['Ctrl', 'Alt']
                                      : ['Ctrl'])
                                Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Container(
                                    width: 36,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: value == 'yes' || name == 'Alt'
                                          ? Theme.of(c).colorScheme.primary
                                          : Theme.of(
                                              c,
                                            ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: value == 'yes' || name == 'Alt'
                                              ? Theme.of(
                                                  c,
                                                ).colorScheme.onPrimary
                                              : Theme.of(c).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(label),
                      ],
                    ),
                },
              ),
            ),
          ]),
          group('', [toggle(c, 'imeTogglekey', c.l10n.keyboardToggleButton)]),
        ];
      case 'gesture':
        final horizontal = p['swipeTmux'] == true
            ? 'tmux'
            : p['swipeSessions'] == true
            ? 'sessions'
            : 'none';
        return [
          group(c.l10n.twoFingerHorizontalSwipe2, [
            tracked(
              'swipeSessions',
              c.l10n.twoFingerHorizontalSwipe2,
              tildeRadioOptions(
                c,
                [
                  ('none', c.l10n.doNothing),
                  ('sessions', c.l10n.switchSessions),
                  ('tmux', c.l10n.switchTmuxWindows),
                ],
                horizontal,
                (value) async {
                  try {
                    await engine.invoke('settings.update', {
                      'key': value == 'tmux' ? 'swipeSessions' : 'swipeTmux',
                      'value': false,
                    });
                    await engine.invoke('settings.update', {
                      'key': value == 'tmux' ? 'swipeTmux' : 'swipeSessions',
                      'value': value != 'none',
                    });
                  } catch (error) {
                    if (c.mounted) showEngineFailure(c, error);
                  }
                },
              ),
            ),
            if (horizontal == 'tmux')
              choice(c, 'tmuxCtrlA', c.l10n.prefixKey, [
                (false, 'C-b'),
                (true, 'C-a'),
              ]),
          ]),
          group('', [
            choice(c, 'pgupdngesture', c.l10n.twoFingerVerticalSwipe, [
              (false, c.l10n.scroll),
              (true, 'PgUp/PgDn'),
            ]),
          ]),
          group('', [
            if (!tildePointer(c))
              toggle(
                c,
                'volumefont',
                c.l10n.volumeButtonsChangeFontSize,
                icon: Icons.volume_up_outlined,
              ),
            if (!tildePointer(c))
              toggle(
                c,
                'bumpyarrows',
                c.l10n.specialKeyVibration,
                icon: Icons.vibration_outlined,
              ),
          ]),
        ];
      case 'terminal':
        return [
          group(c.l10n.profile, [
            choice(c, 'defaultProfileId', c.l10n.defaultTerminalProfile, [
              for (final profile in engine.list('profiles'))
                (profile['id'], '${profile['name']}'),
            ], forceList: true),
            go(
              'profiles',
              c.l10n.manageTerminalProfiles,
              () => page(
                RecordListPage(engine: engine, kind: RecordKind.profile),
              ),
              sub: c.l10n.itemCount(
                (engine.list('profiles').length).toString(),
              ),
            ),
          ]),
          group(c.l10n.appearance, [scrollback(c), margin(c)]),
          group(c.l10n.terminalTypeTerm, [
            ListTile(
              title: Text(
                '${profile['emulation'] ?? 'xterm-256color'}',
                style: const TextStyle(fontFamily: tildeMono),
              ),
              trailing: const Icon(Icons.check),
            ),
            for (final type in (p['customTerminalTypes'] as List? ?? []))
              ListTile(
                title: Text(
                  '$type',
                  style: const TextStyle(fontFamily: tildeMono),
                ),
                trailing: TildeItemMenu<String>(
                  title: '$type',
                  icon: Icons.terminal_outlined,
                  onSelected: (_) => runEngine(
                    c,
                    engine,
                    'terminalType.delete',
                    {'name': type},
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: TildeMenuLabel(
                        c.l10n.delete,
                        Icons.delete_outline,
                        danger: true,
                      ),
                    ),
                  ],
                ),
              ),
            go('terminalType', c.l10n.addTerminalType, () async {
              final cStrings = c.l10n;
              final name = await askText(
                c,
                cStrings.terminalType,
                action: cStrings.add,
              );
              if (name != null && c.mounted) {
                await runEngine(c, engine, 'terminalType.add', {'name': name});
              }
            }, icon: Icons.add),
          ]),
        ];
      case 'connection':
        return [
          group(c.l10n.connect, [
            toggle(
              c,
              'keepalive',
              c.l10n.keepScreenAwakeWhileConnected,
              sub: c.l10n.theTerminalScreenWillStayAwake,
            ),
            toggle(
              c,
              'wifilock',
              c.l10n.preventWiFiSleep,
              sub: c.l10n.usesMoreBattery,
            ),
            go(
              'backgroundNotification',
              c.l10n.backgroundConnectionNotification,
              () => runEngine(c, engine, 'settings.notifications'),
              sub: c.l10n.pinnedWhileConnected,
              icon: Icons.notifications_active_outlined,
            ),
          ]),
          group(c.l10n.terminalBell, [
            tracked(
              'bellMode',
              c.l10n.whenTheBellRings,
              tildeSegments(
                c,
                c.l10n.whenTheBellRings,
                [
                  (0, c.l10n.ignore),
                  (1, c.l10n.sound),
                  (2, c.l10n.vibration),
                  if (p['bell'] == true && p['bellVibrate'] == true)
                    (3, c.l10n.soundAndVibration),
                ],
                p['bell'] == true
                    ? (p['bellVibrate'] == true ? 3 : 1)
                    : p['bellVibrate'] == true
                    ? 2
                    : 0,
                (v) => runEngine(c, engine, 'settings.bellMode', {'mode': v}),
              ),
            ),
            if (p['bell'] == true)
              tracked(
                'bellVolume',
                c.l10n.volume,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.l10n.volume),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value:
                                  ((p['bellVolume'] as num?)?.toDouble() ?? .5)
                                      .clamp(0, 1),
                              onChanged: (v) => update(c, 'bellVolume', v),
                            ),
                          ),
                          Text(
                            '${(((p['bellVolume'] as num?)?.toDouble() ?? .5) * 100).round()}%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ]),
          group(c.l10n.notifications, [
            if (p['notificationsAvailable'] == false)
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(c).colorScheme.tertiary,
                ),
                title: Text(c.l10n.notificationPermissionRequired),
                trailing: TextButton(
                  onPressed: () =>
                      runEngine(c, engine, 'settings.notifications'),
                  child: Text(c.l10n.allow),
                ),
              ),
            toggle(
              c,
              'connectionAlerts',
              c.l10n.enableConnectionNotifications,
              sub: c.l10n.allowBellAndDisconnectionNotifications,
            ),
            toggle(
              c,
              'bellNotification',
              c.l10n.bellInBackground,
              enabled: p['connectionAlerts'] == true,
            ),
            toggle(
              c,
              'connectionLostNotification',
              c.l10n.onDisconnect,
              enabled: p['connectionAlerts'] == true,
            ),
            go(
              'notifications',
              c.l10n.androidNotificationSettings,
              () => runEngine(c, engine, 'settings.notifications'),
              sub: p['notificationsAvailable'] == false
                  ? c.l10n.notificationsOff
                  : c.l10n.notificationsAllowed,
              icon: Icons.open_in_new,
            ),
          ]),
        ];
      case 'security':
        return [
          group(c.l10n.lock, [
            toggle(
              c,
              'authOnLaunch',
              c.l10n.unlockWhenStartingTheApp,
              enabled: p['canAuthenticate'] != false,
              sub: p['canAuthenticate'] == false
                  ? c.l10n.setUpAScreenLockFirst
                  : c.l10n.fingerprintOrScreenLock,
            ),
          ]),
          group(c.l10n.keysAndServers, [
            go(
              'keys',
              c.l10n.sshKeys,
              () => page(KeyPage(engine: engine)),
              sub: c.l10n.itemCount((engine.list('keys').length).toString()),
              icon: Icons.key_outlined,
            ),
            go(
              'identities',
              c.l10n.sharedLoginAccount,
              () => page(
                RecordListPage(engine: engine, kind: RecordKind.identity),
              ),
              sub: c.l10n.itemCount(
                (engine.list('identities').length).toString(),
              ),
              icon: Icons.badge_outlined,
            ),
            go(
              'knownHosts',
              c.l10n.trustedServerKeys,
              () => page(KnownHostsPage(engine: engine)),
              sub: c.l10n.itemCount(
                (engine.list('knownHosts').length).toString(),
              ),
              icon: Icons.verified_user_outlined,
            ),
          ]),
          group(c.l10n.configurationFile, [
            go(
              'export',
              c.l10n.exportHosts,
              () => exportTildeHosts(c, engine),
              sub: 'tilde-hosts.json',
              icon: Icons.upload_outlined,
            ),
            go(
              'import',
              c.l10n.importHosts,
              () => importTildeHosts(c, engine),
              icon: Icons.download_outlined,
            ),
          ]),
        ];
      case 'fonts':
        return [
          group(c.l10n.selectDefaultFont, [
            for (final option in fontOptions(engine).where(
              (f) =>
                  f.$1 == 'D2CODING' ||
                  f.$1 == 'JETBRAINS_MONO' ||
                  f.$1 == p['fontFamily'] ||
                  f.$1.toString().startsWith('local:') ||
                  f.$1.toString().startsWith('custom:'),
            ))
              ListTile(
                leading: Icon(
                  option.$1 == p['fontFamily']
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: option.$1 == p['fontFamily']
                      ? Theme.of(c).colorScheme.primary
                      : null,
                ),
                title: TerminalPreview(
                  engine: engine,
                  framed: false,
                  overrides: {
                    'fontFamily': option.$1,
                    'sampleText': c.l10n.fontSample((option.$2).toString()),
                    'compact': true,
                    'backgroundColor': 0,
                    'foregroundColor': Theme.of(
                      c,
                    ).colorScheme.onSurface.toARGB32(),
                    'profile': {...defaultProfile(engine), 'fontSize': 15},
                  },
                ),
                subtitle: Text(
                  option.$1 == 'D2CODING' || option.$1 == 'JETBRAINS_MONO'
                      ? c.l10n.bundledWithApp
                      : option.$1.toString().startsWith('local:')
                      ? option.$1.toString().substring(6)
                      : option.$1.toString().startsWith('custom:')
                      ? 'Google Fonts'
                      : c.l10n.monospaceFont,
                ),
                onTap: () => update(c, 'fontFamily', option.$1),
                trailing: option.$1.toString().startsWith('local:')
                    ? IconButton(
                        tooltip: c.l10n.deleteFont,
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          final cStrings = c.l10n;
                          if (await confirm(
                                c,
                                cStrings.deleteFont,
                                cStrings.deleteThisFontFile,
                                action: cStrings.deleteFont,
                              ) &&
                              c.mounted) {
                            await runEngine(c, engine, 'font.delete', {
                              'fileName': option.$1.toString().substring(6),
                            });
                          }
                        },
                      )
                    : option.$1.toString().startsWith('custom:')
                    ? IconButton(
                        tooltip: c.l10n.removeFont,
                        icon: const Icon(Icons.close),
                        onPressed: () => runEngine(
                          c,
                          engine,
                          'font.customDelete',
                          {'name': option.$2},
                        ),
                      )
                    : null,
              ),
            if (p['fontBusy'] == true)
              Padding(
                padding: EdgeInsets.all(16),
                child: TildeProgress(label: c.l10n.preparingFont),
              ),
            if (p['fontError'] != null) settingsNote(c, '${p['fontError']}'),
          ]),
          if (!const {'windows', 'ios'}.contains(engine.state['platform']))
            group(c.l10n.add, [
              go(
                'fontImport',
                c.l10n.importFontFile,
                () => importFont(c),
                enabled: p['fontBusy'] != true,
                sub: '.ttf · .otf · .ttc',
                icon: Icons.upload_file,
              ),
              go(
                'fontSearch',
                c.l10n.findOnGoogleFonts,
                () => googleFonts(c),
                enabled: p['fontBusy'] != true,
                sub: c.l10n.onlyMonospaceFontsAreShown,
                icon: Icons.travel_explore,
              ),
            ]),
        ];
      default:
        return [];
    }
  }

  void back(bool wide) {
    if (managementPage != null) {
      if (managementNavigator.currentState?.canPop() == true) {
        managementNavigator.currentState!.maybePop();
      } else {
        setState(() => managementPage = null);
      }
      return;
    }
    if (category == 'bar') {
      setState(() => category = 'keyboard');
    } else if (category == 'fonts') {
      setState(() => category = 'display');
    } else if (!wide && category != null) {
      setState(() => category = null);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final selected = category ?? (wide ? 'display' : null);
        final content = fields(context, selected ?? 'display');
        final columns =
            !tildePointer(context) &&
            constraints.maxWidth >= 1200 &&
            MediaQuery.textScalerOf(context).scale(15) <= 20 &&
            ['display', 'keyboard', 'gesture'].contains(selected);
        final contentView = managementPage != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => back(wide),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text(
                      context.l10n.settings2(
                        (managementPage is HelpPage
                                ? context.l10n.help
                                : title(selected ?? 'display'))
                            .toString(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Navigator(
                      key: managementNavigator,
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => managementPage!,
                      ),
                    ),
                  ),
                ],
              )
            : selected == 'bar'
            ? TerminalBarPage(engine: engine, embedded: true)
            : ListView(
                key: ValueKey(selected),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (wide && selected != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        title(selected),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  if (!columns)
                    ...content
                  else ...[
                    if (selected == 'display') content.first,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: content[selected == 'display' ? 1 : 0]),
                        Expanded(
                          child: Column(
                            children: content
                                .skip(selected == 'display' ? 2 : 1)
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
        final detail = tildePointer(context)
            ? Theme(
                data: Theme.of(context).copyWith(
                  listTileTheme: Theme.of(
                    context,
                  ).listTileTheme.copyWith(minTileHeight: 56),
                ),
                child: contentView,
              )
            : contentView;
        return PopScope(
          canPop:
              managementPage == null &&
              (category == null ||
                  wide && !['fonts', 'bar'].contains(category)),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) back(wide);
          },
          child: Scaffold(
            bottomNavigationBar:
                !kIsWeb && Platform.isAndroid && (wide || selected == null)
                ? const SettingsAdvertising()
                : null,
            appBar: AppBar(
              title: Text(
                !wide && selected == null
                    ? context.l10n.settings
                    : !wide
                    ? title(selected!)
                    : context.l10n.settings,
              ),
              actions: [
                if (!wide || !tildePointer(context))
                  Builder(
                    builder: (anchor) => IconButton(
                      tooltip: context.l10n.searchSettings,
                      onPressed: () => searchSettings(anchor),
                      icon: const Icon(Icons.search),
                    ),
                  ),
              ],
              leading: IconButton(
                tooltip: context.l10n.back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => back(wide),
              ),
            ),
            body: wide
                ? Row(
                    children: [
                      SizedBox(
                        key: const ValueKey('settings-navigation'),
                        width: tildePointer(context) ? 320 : 264,
                        child: categories(switch (managementPage is HelpPage
                            ? 'help'
                            : selected) {
                          'help' => 'help',
                          'fonts' => 'display',
                          'bar' => 'keyboard',
                          _ => selected,
                        }),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Padding(
                          padding: tildePointer(context)
                              ? const EdgeInsets.symmetric(horizontal: 24)
                              : EdgeInsets.zero,
                          child: Align(
                            alignment: tildePointer(context)
                                ? Alignment.topLeft
                                : Alignment.center,
                            child: ConstrainedBox(
                              key: const ValueKey('settings-detail'),
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: detail,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : selected == null
                ? categories(null)
                : detail,
          ),
        );
      },
    ),
  );
}

class TerminalBarPage extends StatefulWidget {
  final AndroidEngine engine;
  final bool embedded;
  const TerminalBarPage({
    super.key,
    required this.engine,
    this.embedded = false,
  });
  @override
  State<TerminalBarPage> createState() => _TerminalBarPageState();
}

class _TerminalBarPageState extends State<TerminalBarPage> {
  late List<String> order;
  late Set<String> hidden;
  late int height;
  late bool group;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.engine.preferences;
    order = (p['terminalBarOrder'] as List).cast<String>().toList();
    hidden = (p['terminalBarHidden'] as List).cast<String>().toSet();
    height = p['terminalBarHeight'] as int;
    group = p['terminalBarFn'] == true;
  }

  Future<void> save({
    List<String>? nextOrder,
    Set<String>? nextHidden,
    int? nextHeight,
    bool? nextGroup,
  }) async {
    final contextStrings = context.l10n;
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.engine.invoke('settings.update', {
        'key': 'terminalBar',
        'value': {
          'order': nextOrder ?? order,
          'hidden': (nextHidden ?? hidden).toList(),
          'height': nextHeight ?? height,
          'groupFunctionKeys': nextGroup ?? group,
        },
      });
      if (mounted) {
        setState(() {
          order = nextOrder ?? order;
          hidden = nextHidden ?? hidden;
          height = nextHeight ?? height;
          group = nextGroup ?? group;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(contextStrings.couldNotSaveSettings),
            action: SnackBarAction(
              label: contextStrings.details,
              onPressed: () => showErrorDetails(context, e),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reset() async {
    final contextStrings = context.l10n;
    final defaults = row(widget.engine.preferences['terminalBarDefaults']);
    if (busy || defaults.isEmpty) return;
    if (await confirm(
          context,
          contextStrings.resetSpecialKeyBar,
          contextStrings.restoreTheDefaultHeightKeyOrderAndVisibility,
          action: contextStrings.undo,
          destructive: false,
        ) &&
        mounted) {
      await save(
        nextOrder: (defaults['order'] as List).cast<String>(),
        nextHidden: (defaults['hidden'] as List).cast<String>().toSet(),
        nextHeight: defaults['height'] as int,
        nextGroup: defaults['groupFunctionKeys'] as bool,
      );
    }
  }

  void move(String source, String target) {
    if (busy || source == target) return;
    final next = [...order];
    final index = next.indexOf(target);
    next.remove(source);
    next.insert(index, source);
    save(nextOrder: next);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.engine.preferences;
    final keys = rows(p['barKeys']);
    final defaults = row(p['terminalBarDefaults']);
    final heights = (p['terminalBarHeights'] as List? ?? []).cast<int>();
    final cs = Theme.of(context).colorScheme;
    Widget cap(String name, {bool target = false, bool feedback = false}) {
      final label =
          '${keys.where((k) => k['name'] == name).firstOrNull?['label'] ?? name}';
      return Material(
        color: target ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: busy || feedback
              ? null
              : () {
                  final next = {...hidden};
                  if (!next.remove(name)) next.add(name);
                  save(nextHidden: next);
                },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            key: feedback ? null : ValueKey('bar-cap-$name'),
            constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: target ? cs.primary : cs.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    Widget draggable(String name) => LongPressDraggable<String>(
      data: name,
      maxSimultaneousDrags: busy ? 0 : 1,
      feedback: cap(name, feedback: true),
      childWhenDragging: Opacity(opacity: .3, child: cap(name, feedback: true)),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => !busy && d.data != name,
        onAcceptWithDetails: (d) => move(d.data, name),
        builder: (_, candidates, _) => cap(name, target: candidates.isNotEmpty),
      ),
    );
    final showAppBar =
        !widget.embedded || MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              automaticallyImplyLeading: !widget.embedded,
              title: Text(context.l10n.specialKeyBar),
              actions: [
                TextButton(
                  onPressed: busy || defaults.isEmpty ? null : reset,
                  child: Text(context.l10n.defaultValue),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (!showAppBar)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy || defaults.isEmpty ? null : reset,
                      child: Text(context.l10n.defaultValue),
                    ),
                  ),
                Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 22,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.longPressToDragTapToHide,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in order.where(
                      (k) =>
                          !hidden.contains(k) &&
                          !(group && k == 'FUNCTION_KEYS'),
                    ))
                      draggable(key),
                  ],
                ),
                const SizedBox(height: 24),
                DragTarget<String>(
                  onWillAcceptWithDetails: (d) =>
                      !busy && !hidden.contains(d.data),
                  onAcceptWithDetails: (d) =>
                      save(nextHidden: {...hidden, d.data}),
                  builder: (_, candidates, _) => Container(
                    key: const ValueKey('bar-hidden-region'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: candidates.isEmpty
                            ? cs.outlineVariant
                            : cs.primary,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_off_outlined,
                              size: 22,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(context.l10n.hiddenKeys),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final key in order.where(hidden.contains))
                              cap(key),
                          ],
                        ),
                        if (hidden.isEmpty)
                          Text(
                            context.l10n.tapAKeyToMoveItHere,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.combineF1F12IntoFn),
                  value: group,
                  onChanged: busy ? null : (value) => save(nextGroup: value),
                ),
                const SizedBox(height: 16),
                Text(context.l10n.height),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  segments: [
                    for (var i = 0; i < heights.length; i++)
                      ButtonSegment(
                        value: heights[i],
                        label: Tooltip(
                          message: i == 0
                              ? context.l10n.small
                              : i == heights.length - 1
                              ? context.l10n.large
                              : context.l10n.default3,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 40,
                                height: heights[i].toDouble(),
                                decoration: BoxDecoration(
                                  color: height == heights[i]
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  selected: {height},
                  onSelectionChanged: busy
                      ? null
                      : (v) => save(nextHeight: v.first),
                ),
                settingsNote(
                  context,
                  context.l10n.escAndCtrlStayOnTheLeftKeyboardFn,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TerminalPreview(engine: widget.engine, framed: false),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: TerminalBarPreview(
                    order: order,
                    hidden: hidden,
                    height: height,
                    group: group,
                    keys: keys,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  final AndroidEngine engine;
  const HelpPage({super.key, required this.engine});
  Future<void> document(
    BuildContext context,
    String section,
    String title,
  ) async {
    final contextStrings = context.l10n;
    final bundle = DefaultAssetBundle.of(context);
    final prefix = engine.state['platform'] == 'windows'
        ? 'packages/android_shell_ui/'
        : '';
    final document = section == 'license'
        ? bundle.loadString('${prefix}assets/licenses/THIRD_PARTY_NOTICES.txt')
        : runEngine(context, engine, 'help.document', {'section': section});
    final value = await document;
    if (value == null || !context.mounted) return;
    var text = '$value';
    if (section == 'license') {
      text +=
          '\n\n${await bundle.loadString('${prefix}assets/fonts/Pretendard-LICENSE.txt')}\n\n${await bundle.loadString('${prefix}assets/fonts/JetBrainsMono-OFL.txt')}\n\n${await bundle.loadString('${prefix}assets/fonts/D2Coding-OFL.txt')}';
    }
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (section == 'license')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: 'Tilde',
                      ),
                      child: Text(contextStrings.flutterLibraryLicenses),
                    ),
                  ),
                SelectableText(text),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.help)),
    body: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TildeWordmark(size: 40),
              const SizedBox(height: 16),
              Text('${engine.state['appVersion'] ?? ''}'),
              const Text('Dart SSH · Flutter Terminal'),
            ],
          ),
        ),
        settingsSection(context, context.l10n.help, [
          for (final (section, title, icon) in [
            ('hints', context.l10n.tips, Icons.lightbulb_outline),
            (
              'license',
              context.l10n.licensesAndTerms,
              Icons.description_outlined,
            ),
            ('contact', context.l10n.projectAndContact, Icons.mail_outline),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => document(context, section, title),
            ),
        ]),
        if (!const {'windows', 'ios'}.contains(engine.state['platform']))
          settingsSection(context, context.l10n.diagnostics, [
            ListTile(
              leading: const Icon(Icons.subject),
              title: Text(context.l10n.diagnosticLogs),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => LogsPage(engine: engine)),
              ),
            ),
          ]),
      ],
    ),
  );
}

class LogsPage extends StatefulWidget {
  final AndroidEngine engine;
  const LogsPage({super.key, required this.engine});
  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String logs = '', search = '', severity = 'ALL';
  bool searching = false;
  RegExpMatch? levelMatch(String line) => RegExp(
    r'\b(TRACE|DEBUG|INFO|WARN|ERROR|FATAL)\b|\s([VDIWEF])\s',
  ).firstMatch(line);
  String level(String line) {
    final match = levelMatch(line);
    return match?.group(1) ?? match?.group(2) ?? '';
  }

  bool matches(String line, String filter) => switch (filter) {
    'WARN' => const {'WARN', 'W'}.contains(level(line)),
    'ERROR' => const {'ERROR', 'FATAL', 'E', 'F'}.contains(level(line)),
    _ => true,
  };
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.engine.query('logs');
      if (mounted) setState(() => logs = '$result');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = logs.split('\n').where((line) => line.isNotEmpty).toList();
    final shown = lines
        .where(
          (line) =>
              matches(line, severity) &&
              line.toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diagnosticLogs),
        actions: [
          IconButton(
            tooltip: context.l10n.searchLogs,
            onPressed: () => setState(() {
              searching = !searching;
              if (!searching) search = '';
            }),
            icon: const Icon(Icons.search),
          ),
          TildeItemMenu<String>(
            title: '',
            icon: Icons.more_vert,
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  await load();
                case 'share':
                  if (logs.isNotEmpty) {
                    await runEngine(context, widget.engine, 'share', {
                      'text': logs,
                    });
                  }
                case 'crash':
                  await runEngine(context, widget.engine, 'logs.tombstone');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'refresh',
                enabled: !busy,
                child: TildeMenuLabel(context.l10n.refresh, Icons.refresh),
              ),
              PopupMenuItem(
                value: 'share',
                enabled: logs.isNotEmpty,
                child: TildeMenuLabel(context.l10n.share, Icons.ios_share),
              ),
              PopupMenuItem(
                value: 'crash',
                child: TildeMenuLabel(
                  context.l10n.saveNativeCrashLog,
                  Icons.save_alt,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (searching)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: tildeToolbarInput(
                  context,
                  InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: context.l10n.searchLogs,
                  ),
                ),
                onChanged: (value) => setState(() => search = value),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final filter in ['ALL', 'WARN', 'ERROR'])
                    ChoiceChip(
                      label: Text(
                        '${switch (filter) {
                          'WARN' => context.l10n.warning,
                          'ERROR' => context.l10n.error,
                          _ => context.l10n.all,
                        }} ${lines.where((line) => matches(line, filter)).length}',
                      ),
                      selected: severity == filter,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => severity = filter),
                    ),
                ],
              ),
            ),
          ),
          if (busy) const TildeProgress(),
          if (error != null)
            ListTile(
              title: Text(context.l10n.couldNotLoadLogs),
              trailing: TextButton(
                onPressed: () => showErrorDetails(context, error!),
                child: Text(context.l10n.details),
              ),
            ),
          Expanded(
            child: SelectionArea(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final line = shown[index], kind = level(line);
                  const style = TextStyle(
                    fontFamily: tildeMono,
                    fontFamilyFallback: tildeMonoFallback,
                    fontSize: 12.5,
                    height: 1.6,
                  );
                  if (kind.isEmpty) return Text(line, style: style);
                  final match = levelMatch(line)!;
                  final at = match.start + (match.group(1) == null ? 1 : 0),
                      prefix = line.substring(0, at).trim();
                  final time =
                      RegExp(
                        r'\b\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?\b',
                      ).firstMatch(prefix)?.group(0) ??
                      prefix;
                  final color =
                      const {'ERROR', 'FATAL', 'E', 'F'}.contains(kind)
                      ? Theme.of(context).colorScheme.error
                      : const {'WARN', 'W'}.contains(kind)
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.onSurfaceVariant;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            kind,
                            style: style.copyWith(color: color),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line.substring(at + kind.length).trimLeft(),
                            style: style,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
