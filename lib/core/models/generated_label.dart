class GeneratedLabel {
  final String barcode;
  final String text;

  GeneratedLabel({required this.barcode, required this.text});

  factory GeneratedLabel.fromJson(Map<String, dynamic> json) {
    return GeneratedLabel(
      barcode: json['barcode']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}
