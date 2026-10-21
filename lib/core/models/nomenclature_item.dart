import 'dart:convert';
import 'dart:typed_data';

class NomenclatureItem {
  final int codeItem;
  final String nameItem;
  final String binaryData;
  final String codeIcon;

  const NomenclatureItem({
    required this.codeItem,
    required this.nameItem,
    required this.binaryData,
    required this.codeIcon,
  });

  factory NomenclatureItem.fromJson(Map<String, dynamic> json) {
    return NomenclatureItem(
      // БЕЗПЕЧНИЙ ПАРСИНГ: конвертує String у int, якщо 1С віддасть рядок
      codeItem: _parseIntSafe(json['code_item']),

      // БЕЗПЕЧНИЙ ПАРСИНГ: конвертує будь-який тип у String
      nameItem: json['name_item']?.toString() ?? 'Невідомий товар',
      binaryData: json['binary_data']?.toString() ?? '',
      codeIcon: json['code_icon']?.toString() ?? '',
    );
  }

  /// Універсальний парсер для цілих чисел (захист від помилок типізації 1С)
  static int _parseIntSafe(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Метод для отримання готових байтів картинки з рядка Base64.
  /// Видаляє всі пробіли та \r\n, які 1С додає при кодуванні.
  Uint8List? get imageBytes {
    if (binaryData.isEmpty) return null;
    try {
      final cleanBase64 = binaryData.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(cleanBase64);
    } catch (e) {
      return null; // Якщо помилка декодування — картинка просто не відобразиться
    }
  }
}
