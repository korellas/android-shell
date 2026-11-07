// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:xterm2/xterm.dart';

String? terminalWebLinkAt(Terminal terminal, CellOffset cell) {
  final lines = terminal.buffer.lines;
  if (cell.y < 0 ||
      cell.y >= lines.length ||
      cell.x < 0 ||
      cell.x >= lines[cell.y].length) {
    return null;
  }
  String? webUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty
        ? value
        : null;
  }

  final explicit = terminal.hyperlinkAt(cell);
  if (explicit != null) return webUrl(explicit);

  var first = cell.y;
  var last = cell.y;
  while (first > 0 && lines[first].isWrapped) {
    first--;
  }
  while (last + 1 < lines.length && lines[last + 1].isWrapped) {
    last++;
  }
  final text = StringBuffer();
  var offset = 0;
  for (var y = first; y <= last; y++) {
    final line = lines[y];
    for (var x = 0; x < line.length; x++) {
      if (y == cell.y && x == cell.x) offset = text.length;
      if (line.getWidth(x) == 0 && x > 0 && line.getWidth(x - 1) == 2) continue;
      final code = line.getCodePoint(x);
      text.writeCharCode(code == 0 ? 32 : code);
    }
  }
  for (final match in RegExp(
    r'''(https?://)[^\s<>"']+|'''
    r'(?<![\w@/.-])(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+'
    r'''[a-z]{2,}(?![\w-])(?::[0-9]+)?(?:[/?#][^\s<>"']*)?''',
    caseSensitive: false,
  ).allMatches(text.toString())) {
    var url = match.group(0)!;
    // Sentence punctuation and unmatched closing brackets are not part of a URL.
    while (url.isNotEmpty) {
      final end = url[url.length - 1];
      final opening = const {')': '(', ']': '[', '}': '{'}[end];
      if ('.!,;:'.contains(end) ||
          (opening != null &&
              end.allMatches(url).length > opening.allMatches(url).length)) {
        url = url.substring(0, url.length - 1);
      } else {
        break;
      }
    }
    if (offset >= match.start && offset < match.start + url.length) {
      return webUrl(match.group(1) == null ? 'https://$url' : url);
    }
  }
  return null;
}
