class GeneratedLabel {
  final String barcode;
  final String text;
  final String title;

  GeneratedLabel({required this.barcode, required this.text, this.title = ''});

  factory GeneratedLabel.fromJson(Map<String, dynamic> json) {
    return GeneratedLabel(
      barcode: json['barcode'] ?? '',
      text: json['text'] ?? '',
      title: json['title'] ?? '',
    );
  }
}
