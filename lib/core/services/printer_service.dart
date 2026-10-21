import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';

class PrinterService {
  /// Очищає текст від небезпечних символів для TSPL команд,
  /// запобігаючи збоям при друці через спецсимволи або переноси.
  static String sanitizeForTspl(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAll('"', "'") // Замінюємо подвійні лапки на одинарні
        .replaceAll('\\', '') // Видаляємо зворотні слеші
        .replaceAll('\n', ' ') // Прибираємо переноси рядків
        .replaceAll('\r', ' ') // Прибираємо повернення каретки
        .replaceAll(
          RegExp(r'[\x00-\x1F]'),
          '',
        ); // Видаляємо невидимі керуючі символи
  }

  /// Відправляє TSPL-команду на принтер по IP-адресі
  Future<bool> printLabels({
    required String ipAddress,
    required String tsplCommand,
  }) async {
    const int port = 9100; // Стандартний порт для RAW-друку
    Socket? socket; // Оголошуємо змінну поза блоком try

    try {
      // Встановлюємо з'єднання
      socket = await Socket.connect(
        ipAddress,
        port,
        timeout: const Duration(seconds: 3),
      );

      // Відправляємо сформовану команду на принтер
      socket.add(utf8.encode(tsplCommand));

      // Чекаємо, поки дані гарантовано будуть виштовхнуті в мережу
      await socket.flush();

      return true; // Друк успішний
    } catch (e) {
      debugPrint('Помилка друку: $e');
      return false; // Помилка підключення
    } finally {
      // Цей блок виконається ЗАВЖДИ, навіть якщо була помилка.
      // Це гарантує, що ми ніколи не залишимо "фантомних" з'єднань.
      if (socket != null) {
        try {
          await socket
              .close(); // Коректно просимо закрити з'єднання (FIN-пакет)
          socket.destroy(); // Жорстко вбиваємо сокет і звільняємо пам'ять
        } catch (e) {
          debugPrint('Помилка при закритті сокета: $e');
        }
      }
    }
  }
}
