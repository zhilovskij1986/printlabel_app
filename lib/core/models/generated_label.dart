class GeneratedLabel {
  final String barcode;
  final String title;
  final String text;

  GeneratedLabel({
    required this.barcode,
    required this.title,
    required this.text,
  });

  factory GeneratedLabel.fromJson(Map<String, dynamic> json) {
    return GeneratedLabel(
      // БЕЗПЕЧНИЙ ПАРСИНГ: конвертує int/double у String, якщо 1С помилиться з типом
      barcode: json['barcode']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}
