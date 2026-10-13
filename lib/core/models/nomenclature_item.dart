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
      codeItem: json['code_item'] ?? 0,
      nameItem: json['name_item'] ?? 'Невідомий товар',
      binaryData: json['binary_data'] ?? '',
      codeIcon: json['code_icon'] ?? '',
    );
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
