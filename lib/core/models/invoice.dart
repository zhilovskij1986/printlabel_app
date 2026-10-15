class Invoice {
  final String scannedBarcode;
  final String number;
  final String warehouseCode;
  final List<String> warehouseNames;
  final int placesCount;
  final String loadingPlaceBarcode;

  Invoice({
    required this.scannedBarcode,
    required this.number,
    required this.warehouseCode,
    required this.warehouseNames,
    required this.placesCount,
    required this.loadingPlaceBarcode,
  });

  // Оновлюємо fromJson: тепер він приймає ще й штрихкод
  factory Invoice.fromJson(Map<String, dynamic> json, String barcode) {
    return Invoice(
      scannedBarcode: barcode,
      number: json['Номер'] ?? '',
      warehouseCode: json['СкладКод'] ?? '',
      warehouseNames:
          (json['СкладНаименование'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      placesCount: json['КоличествоМест'] is int
          ? json['КоличествоМест']
          : int.tryParse(json['КоличествоМест']?.toString() ?? '0') ?? 0,
      loadingPlaceBarcode: json['ШтрихкодПогрузочногоМеста'] ?? '',
    );
  }
}
