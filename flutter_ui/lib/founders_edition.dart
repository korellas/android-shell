/* Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0 */
import 'package:flutter/material.dart';
import 'engine.dart';
import 'main.dart' show runEngine;

class FoundersEditionPage extends StatelessWidget {
  const FoundersEditionPage({super.key, required this.engine});
  final AndroidEngine engine;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final state = row(engine.state['founders']);
      final owned = state['owned'] == true;
      final busy = state['checking'] == true || state['pending'] == true;
      final price = state['price'] as String?;
      final ready = state['ready'] == true && price != null;
      final error = switch (state['error']) {
        'verification_failed' => '구매를 확인하지 못했습니다. 구매 복원으로 다시 확인해 주세요.',
        'acknowledgement_failed' => '구매 확인을 완료하지 못했습니다. 구매 복원으로 다시 시도해 주세요.',
        'purchase_failed' => '구매를 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.',
        'billing_unavailable' => 'Google Play 구매 정보를 불러오지 못했습니다.',
        _ => null,
      };
      return Scaffold(
        appBar: AppBar(title: const Text('Founders Edition')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  owned
                      ? Icons.check_circle_outline
                      : Icons.auto_awesome_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  owned ? 'Founders Edition 사용 중' : '광고 없는 Tilde',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text('설정 화면의 배너 없이 Tilde를 이용하세요.'),
                const SizedBox(height: 8),
                const Text('한 번 구매 · 같은 Google 계정에서 구매 복원'),
                const SizedBox(height: 32),
                if (!owned)
                  FilledButton(
                    onPressed: ready && !busy
                        ? () => runEngine(context, engine, 'founders.purchase')
                        : null,
                    child: Text(
                      state['pending'] == true
                          ? '결제 확인 중'
                          : state['checking'] == true
                          ? '구매 정보 확인 중'
                          : ready
                          ? '$price에 구매'
                          : '구매 준비 중',
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => runEngine(context, engine, 'founders.restore'),
                  child: const Text('구매 복원'),
                ),
                if (error != null) ...[const SizedBox(height: 16), Text(error)],
              ],
            ),
          ),
        ),
      );
    },
  );
}
