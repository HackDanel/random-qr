import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class QrItem {
  const QrItem({required this.id, required this.title, required this.url});

  final String id;
  final String title;
  final String url;

  factory QrItem.fromJson(Map<String, dynamic> json) => QrItem(
        id: json['id'] as String,
        title: json['title'] as String,
        url: json['url'] as String,
      );
}

Future<List<QrItem>> loadQrItems() async {
  final raw = await rootBundle.loadString('assets/qr_list.json');
  final list = jsonDecode(raw) as List<dynamic>;
  return list.map((e) => QrItem.fromJson(e as Map<String, dynamic>)).toList();
}

/// Random picker without repeats: every item is shown once before any repeats,
/// and the same item never appears twice in a row across reshuffles.
class ShuffleBag<T> {
  ShuffleBag(this._items, {Random? random}) : _random = random ?? Random();

  final List<T> _items;
  final Random _random;
  final List<T> _bag = [];
  T? _last;

  T next() {
    if (_items.isEmpty) throw StateError('ShuffleBag is empty');
    if (_bag.isEmpty) {
      _bag
        ..addAll(_items)
        ..shuffle(_random);
      // _bag is popped from the end; keep the previous pick away from it.
      if (_bag.length > 1 && _bag.last == _last) {
        final tmp = _bag.first;
        _bag.first = _bag.last;
        _bag.last = tmp;
      }
    }
    return _last = _bag.removeLast();
  }
}
