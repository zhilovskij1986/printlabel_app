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
          await socket.close();
          socket.destroy();
        } catch (e) {
          debugPrint('Помилка при закритті сокета: $e');
        }
      }
    }
  }

  /// Генерує команду BITMAP для TSPL з жирним текстом (Оптимізовано пам'ять)
  Future<List<int>> generateBoldTitleTspl(String title) async {
    final textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 34,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: title, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: 464);

    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, 464, textPainter.height), bgPaint);
    textPainter.paint(canvas, Offset.zero);

    final picture = pictureRecorder.endRecording();
    ui.Image? image;
    ByteData? byteData;

    try {
      // Створюємо нативне зображення
      image = await picture.toImage(464, textPainter.height.toInt());
      byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      // ГАРАНТОВАНЕ звільнення нативної графічної пам'яті
      image?.dispose();
      picture.dispose();
    }

    int widthBytes = (464 + 7) ~/ 8;
    // Оскільки image ми вже знищили, беремо висоту з textPainter
    int height = textPainter.height.toInt();
    Uint8List bitmapData = Uint8List(widthBytes * height);

    if (byteData != null) {
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < 464; x++) {
          int offset = (y * 464 + x) * 4;
          int r = byteData.getUint8(offset);
          int g = byteData.getUint8(offset + 1);
          int b = byteData.getUint8(offset + 2);

          int brightness = (0.299 * r + 0.587 * g + 0.114 * b).round();
          // Наша інверсія для принтера (білий фон = 1, чорний текст = 0)
          bool isWhite = brightness >= 128;

          if (isWhite) {
            int byteIndex = y * widthBytes + (x ~/ 8);
            int bitIndex = 7 - (x % 8);
            bitmapData[byteIndex] |= (1 << bitIndex);
          }
        }
      }
    }

    List<int> tsplPayload = [];
    String header = 'BITMAP 0,10,$widthBytes,$height,0,';

    tsplPayload.addAll(utf8.encode(header));
    tsplPayload.addAll(bitmapData);
    tsplPayload.addAll(utf8.encode('\r\n'));

    return tsplPayload;
  }
}
