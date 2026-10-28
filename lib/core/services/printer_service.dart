import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';

class PrinterService {
  /// Очищає текст від небезпечних символів для TSPL команд,
  /// запобігаючи збоям при друці через спецсимволи або переноси.
  static String sanitizeForTspl(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAll('"', "'")
        .replaceAll('\\', '')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '');
  }

  /// Відправляє TSPL-команду на принтер по IP-адресі (приймає байти)
  Future<bool> printLabels({
    required String ipAddress,
    required List<int> payload,
  }) async {
    const int port = 9100;
    Socket? socket;

    try {
      socket = await Socket.connect(
        ipAddress,
        port,
        timeout: const Duration(seconds: 3),
      );

      // Відправляємо байти напряму
      socket.add(payload);
      await socket.flush();

      return true;
    } catch (e) {
      debugPrint('Помилка друку: $e');
      return false;
    } finally {
      if (socket != null) {
        try {
          // destroy() працює миттєво та розриває TCP з'єднання.
          // Це безпечніше, ніж чекати на await socket.close() при поганому Wi-Fi.
          socket.destroy();
        } catch (e) {
          debugPrint('Помилка при знищенні сокета: $e');
        }
      }
    }
  }

  /// Генерує команду BITMAP для TSPL з жирним текстом (Оптимізовано пам'ять)
  Future<List<int>> generateBoldTitleTspl(String title) async {
    // Налаштування ширини та відступів
    const int totalWidth = 464;
    const double paddingX = 24.0; // Відступ зліва і справа (~3 мм)
    const double paddingY = 4.0; // Відступ зверху і знизу

    final textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 38,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: title, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    // Обмежуємо ширину тексту, щоб він переносився до того, як торкнеться краю
    textPainter.layout(maxWidth: totalWidth - (paddingX * 2));

    // Загальна висота картинки = висота тексту + відступи
    final int totalHeight = (textPainter.height + (paddingY * 2)).ceil();

    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);

    // Малюємо білий фон на всю ширину рулону
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, totalWidth.toDouble(), totalHeight.toDouble()),
      bgPaint,
    );

    // Малюємо текст зі зміщенням на paddingX та paddingY
    textPainter.paint(canvas, const Offset(paddingX, paddingY));

    final picture = pictureRecorder.endRecording();
    ui.Image? image;
    ByteData? byteData;

    try {
      image = await picture.toImage(totalWidth, totalHeight);
      byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image?.dispose();
      picture.dispose();
    }

    int widthBytes = (totalWidth + 7) ~/ 8;
    Uint8List bitmapData = Uint8List(widthBytes * totalHeight);

    if (byteData != null) {
      for (int y = 0; y < totalHeight; y++) {
        for (int x = 0; x < totalWidth; x++) {
          int offset = (y * totalWidth + x) * 4;
          int r = byteData.getUint8(offset);

          bool isWhite = r > 127;

          if (isWhite) {
            int byteIndex = y * widthBytes + (x ~/ 8);
            int bitIndex =
                7 - (x % 8); // ВИПРАВЛЕНО: тут була помилка синтаксису
            bitmapData[byteIndex] |= (1 << bitIndex);
          }
        }
      }
    }

    List<int> tsplPayload = [];
    String header = 'BITMAP 0,10,$widthBytes,$totalHeight,0,';

    tsplPayload.addAll(utf8.encode(header));
    tsplPayload.addAll(bitmapData);
    tsplPayload.addAll(utf8.encode('\r\n'));

    return tsplPayload;
  }
}
