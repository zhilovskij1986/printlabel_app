import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final SharedPreferences _prefs;

  // Конструктор тепер приймає готовий об'єкт SharedPreferences
  SettingsService(this._prefs);

  static const String _deviceKey = 'device_name';
  static const String _warehouseKey = 'warehouse_name'; // Новий ключ для складу
  static const String _labelWidthKey = 'label_width';
  static const String _labelHeightKey = 'label_height';
  static const String _printerIpKey = 'printer_ip';

  /// --- Назва ТЗД ---
  String getDeviceName() => _prefs.getString(_deviceKey) ?? '';
  Future<bool> saveDeviceName(String name) =>
      _prefs.setString(_deviceKey, name.trim());

  /// --- Назва Складу (ДЛЯ BLOC) ---
  String getWarehouseName() => _prefs.getString(_warehouseKey) ?? '';
  Future<bool> saveWarehouseName(String name) =>
      _prefs.setString(_warehouseKey, name.trim());

  /// --- Розміри та IP ---
  String getLabelWidth() => _prefs.getString(_labelWidthKey) ?? '58';
  Future<bool> saveLabelWidth(String width) =>
      _prefs.setString(_labelWidthKey, width.trim());

  String getLabelHeight() => _prefs.getString(_labelHeightKey) ?? '40';
  Future<bool> saveLabelHeight(String height) =>
      _prefs.setString(_labelHeightKey, height.trim());

  String getPrinterIp() => _prefs.getString(_printerIpKey) ?? '';
  Future<bool> savePrinterIp(String ip) =>
      _prefs.setString(_printerIpKey, ip.trim());
}
