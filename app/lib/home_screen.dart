import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'models.dart';
import 'qr_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<QrItem>> _items = loadQrItems();
  ShuffleBag<QrItem>? _bag;

  void _open(QrItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QrScreen(item: item, onNextRandom: _bag!.next),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QrItem>>(
      future: _items,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items != null) _bag ??= ShuffleBag(items);
        return Scaffold(
          appBar: AppBar(title: Text('QR-коды (${items?.length ?? 0})')),
          body: switch (snapshot) {
            AsyncSnapshot(hasError: true) =>
              Center(child: Text('Ошибка загрузки: ${snapshot.error}')),
            AsyncSnapshot(data: final items?) when items.isEmpty =>
              const Center(child: Text('Список пуст')),
            AsyncSnapshot(data: final items?) => ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => ListTile(
                  leading: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(2),
                    child: QrImageView(data: items[i].url, size: 48, padding: EdgeInsets.zero),
                  ),
                  title: Text(items[i].title),
                  subtitle: Text(items[i].url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _open(items[i]),
                ),
              ),
            _ => const Center(child: CircularProgressIndicator()),
          },
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: items == null || items.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _open(_bag!.next()),
                  icon: const Icon(Icons.casino),
                  label: const Text('Случайный'),
                ),
        );
      },
    );
  }
}
