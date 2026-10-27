// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/terminal/images/inline_images.dart';

void main() {
  test(
    'async parsing preserves split uploads and shares retained budget',
    () async {
      final budget = InlineImageBudget();
      final protocol = AsyncInlineImageProtocol(budget: budget);
      final store = InlineImageStore(budget: budget);
      expect(await protocol.feed('\x1b_Ga=T,f=32,s=1,v=1,i=9;'), isEmpty);
      final events = await protocol.feed(
        '${base64Encode([255, 0, 0, 255])}\x1b\\tail',
      );
      store.apply(events.first as InlineImageCommand);
      expect((events.last as InlineImageText).text, 'tail');
      final data = await store.assets[9]!.currentFrame.source!
          .openDecodeAsync();
      expect(data.bytes, [255, 0, 0, 255]);
      expect(budget.decodedUsage, 4);
      data.dispose();
      protocol.dispose();
      store.dispose();
      expect(budget.encodedUsage, 0);
      expect(budget.decodedUsage, 0);
    },
  );
  test(
    'async decoding requires consent and disposal releases partial upload',
    () async {
      final budget = InlineImageBudget();
      final protocol = AsyncInlineImageProtocol(
        budget: budget,
        policy: InlineImagePolicy.ask,
      );
      final events = await protocol.feed(
        '\x1b_Gf=32,s=1,v=1;${base64Encode([1, 2, 3, 255])}\x1b\\',
      );
      final command = events.single as InlineImageCommand;
      await expectLater(command.source!.openDecodeAsync(), throwsStateError);
      expect(budget.decodedUsage, 0);
      command.dispose();
      await protocol.feed('\x1b_Gf=32,s=100,v=100;AAAA');
      protocol.dispose();
      expect(budget.encodedUsage, 0);
    },
  );
  test(
    'dispose during worker startup cancels output and returns allowance',
    () async {
      final budget = InlineImageBudget();
      final protocol = AsyncInlineImageProtocol(budget: budget);
      final pending = protocol.feed('late');
      protocol.dispose();
      expect(await pending, isEmpty);
      expect(budget.encodedUsage, 0);
    },
  );
  test(
    'worker copies share retained encoded limit and reject with Kitty reply',
    () async {
      final budget = InlineImageBudget(
        const InlineImageLimits(encodedBytes: 8192),
      );
      final protocol = AsyncInlineImageProtocol(budget: budget);
      final store = InlineImageStore(budget: budget);
      final first = await protocol.feed(
        '\x1b_Ga=t,i=1,f=32,s=1,v=1;AQID/w==\x1b\\',
      );
      store.apply(first.single as InlineImageCommand);
      expect(budget.encodedUsage, 4096);
      final next = await protocol.feed(
        '\x1b_Ga=t,i=2,f=32,s=1,v=1;AQID/w==\x1b\\tail',
      );
      expect(next.whereType<InlineImageCommand>(), isEmpty);
      expect(
        next.whereType<InlineImageReply>().single.text,
        contains('ENOSPC'),
      );
      expect(next.whereType<InlineImageText>().single.text, 'tail');
      expect(budget.encodedUsage, 4096);
      protocol.dispose();
      store.dispose();
      expect(budget.encodedUsage, 0);
    },
  );
}
