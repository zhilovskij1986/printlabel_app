import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';

class PrinterService {
  /// Відправляє TSPL-команду на принтер по IP-адресі
  Future<bool> printLabels({
    required String ipAddress,
    required String tsplCommand,
  }) async {
    const int port = 9100; // Стандартний порт для RAW-друку

    try {
      // Встановлюємо з'єднання з таймаутом 3 секунди, щоб додаток не "зависав",
      // якщо принтер вимкнено або IP неправильний
      final socket = await Socket.connect(
        ipAddress,
        port,
        timeout: const Duration(seconds: 3),
      );

      // Відправляємо сформовану команду на принтер.
      // Кодуємо в UTF-8. (Якщо замість кирилиці будуть "ієрогліфи",
      // ми згодом підключимо пакет charset_converter для Windows-1251).
      socket.add(utf8.encode(tsplCommand));

      // Чекаємо, поки дані гарантовано будуть відправлені
      await socket.flush();
      // Закриваємо з'єднання
      await socket.close();

      return true; // Друк успішний
    } catch (e) {
      debugPrint('Помилка друку: $e');
      return false; // Помилка підключення
    }
  }
}
