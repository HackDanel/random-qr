import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:random_qr/models.dart';

void main() {
  test('each round covers all items without repeats', () {
    final bag = ShuffleBag([1, 2, 3, 4, 5], random: Random(1));
    for (var round = 0; round < 20; round++) {
      final picks = List.generate(5, (_) => bag.next());
      expect(picks.toSet(), {1, 2, 3, 4, 5});
    }
  });

  test('never picks same item twice in a row', () {
    for (var seed = 0; seed < 200; seed++) {
      final bag = ShuffleBag([1, 2, 3], random: Random(seed));
      var prev = bag.next();
      for (var i = 0; i < 30; i++) {
        final cur = bag.next();
        expect(cur, isNot(prev));
        prev = cur;
      }
    }
  });

  test('single item works', () {
    final bag = ShuffleBag(['a']);
    expect([bag.next(), bag.next()], ['a', 'a']);
  });
}
