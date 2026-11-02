// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/widgets.dart';
import 'transfer.dart';

typedef FileExport =
    Future<void> Function(
      SftpName entry,
      File destination,
      TransferControl control,
    );
typedef FileDropBuilder =
    Widget Function(Widget child, Future<void> Function(List<String>)? upload);
typedef FileDragBuilder =
    Widget Function(Widget child, SftpName entry, FileExport? download);

class FileDragScope extends InheritedWidget {
  const FileDragScope({
    super.key,
    required super.child,
    required this.dropBuilder,
    required this.dragBuilder,
    this.selectionDragBuilder,
    this.targetDropBuilder,
    this.chooseDirectory,
    this.readLocalFiles,
    this.copyRemoteFiles,
    this.readSetting,
    this.writeSetting,
  });
  final Widget Function(Widget, List<SftpName>, FileExport?)?
  selectionDragBuilder;
  final Widget Function(Widget, Future<void> Function(List<String>)?, String)?
  targetDropBuilder;
  final Future<String?> Function()? chooseDirectory;
  final Future<List<String>> Function()? readLocalFiles;
  final Future<void> Function(List<SftpName>, FileExport, String)?
  copyRemoteFiles;
  final Future<Object?> Function(String)? readSetting;
  final Future<void> Function(String, Object)? writeSetting;
  final FileDropBuilder dropBuilder;
  final FileDragBuilder dragBuilder;
  static FileDragScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FileDragScope>();
  @override
  bool updateShouldNotify(FileDragScope oldWidget) =>
      dropBuilder != oldWidget.dropBuilder ||
      dragBuilder != oldWidget.dragBuilder ||
      selectionDragBuilder != oldWidget.selectionDragBuilder ||
      targetDropBuilder != oldWidget.targetDropBuilder ||
      chooseDirectory != oldWidget.chooseDirectory ||
      readSetting != oldWidget.readSetting ||
      writeSetting != oldWidget.writeSetting;
}
