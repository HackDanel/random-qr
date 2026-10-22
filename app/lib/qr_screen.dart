import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'models.dart';

/// Fullscreen QR for scanning by another phone: white background,
/// max brightness and screen kept awake while open.
/// Optionally shows a preview of the linked photo under the QR.
class QrScreen extends StatefulWidget {
  const QrScreen({super.key, required this.item, required this.onNextRandom});

  final QrItem item;
  final QrItem Function() onNextRandom;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  late QrItem _item = widget.item;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _ignoreErrors(() => ScreenBrightness.instance.setApplicationScreenBrightness(1.0));
    _ignoreErrors(WakelockPlus.enable);
  }

  @override
  void dispose() {
    _ignoreErrors(ScreenBrightness.instance.resetApplicationScreenBrightness);
    _ignoreErrors(WakelockPlus.disable);
    super.dispose();
  }

  // Brightness/wakelock are nice-to-have; don't crash on unsupported platforms.
  static void _ignoreErrors(Future<void> Function() action) {
    action().catchError((_) {});
  }

  void _openPhoto() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PhotoScreen(item: _item),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(_item.title),
        actions: [
          IconButton(
            tooltip: _showPreview ? 'Скрыть фото' : 'Показать фото',
            icon: Icon(_showPreview ? Icons.image : Icons.image_outlined),
            onPressed: () => setState(() => _showPreview = !_showPreview),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const buttonArea = 120.0;
            final maxHeight = constraints.maxHeight - buttonArea;
            // With preview on, QR gets half of the height, the photo the rest.
            final size = min(constraints.maxWidth, _showPreview ? maxHeight * 0.5 : maxHeight) * 0.9;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_showPreview) const SizedBox(height: 16),
                Center(
                  child: QrImageView(
                    data: _item.url,
                    size: size,
                    backgroundColor: Colors.white,
                  ),
                ),
                if (_showPreview)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: GestureDetector(
                        onTap: _openPhoto,
                        child: _NetworkPhoto(url: _item.url, dark: false),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => setState(() => _item = widget.onNextRandom()),
                  icon: const Icon(Icons.casino),
                  label: const Text('Ещё случайный'),
                ),
                if (_showPreview) const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Photo opened fullscreen from the preview, with pinch-to-zoom.
class _PhotoScreen extends StatelessWidget {
  const _PhotoScreen({required this.item});

  final QrItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(item.title),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: _NetworkPhoto(url: item.url, dark: true)),
      ),
    );
  }
}

class _NetworkPhoto extends StatelessWidget {
  const _NetworkPhoto({required this.url, required this.dark});

  final String url;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white70 : Colors.black54;
    return Image.network(
      url,
      key: ValueKey(url),
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Center(child: CircularProgressIndicator(color: color)),
      errorBuilder: (context, error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: color, size: 48),
            const SizedBox(height: 8),
            Text('Не удалось загрузить фото', style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
