import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/api/api_client.dart';

class UpdateService {
  final ApiClient apiClient;
  final Dio _dio = Dio(); // Створюємо локальний Dio для скачування файлу

  UpdateService({required this.apiClient});

  /// Перевіряє наявність нової версії
  Future<Map<String, dynamic>?> checkForUpdates({required String type}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // автоматично підставить хост, порт, публікацію, Basic Auth та розпарсить JSON!
      final response = await apiClient.get(
        '/getversion',
        queryParameters: {"type": type, "name_app": "MobileTsdPrint"},
      );

      // Оскільки ваш ApiClient повертає вже jsonDecode(decoderBody),
      // ми можемо відразу звертатися до ключів:
      if (response != null) {
        final serverVersion = response['version'];
        final apkUrl = response['way'];

        if (serverVersion != currentVersion && apkUrl != null) {
          return {'version': serverVersion, 'url': apkUrl};
        }
      }
      return null;
    } catch (e) {
      debugPrint('Помилка перевірки оновлень: $e');
      return null;
    }
  }

  /// Завантажує та запускає встановлення APK
  Future<void> downloadAndInstall(
    String apkUrl,
    Function(double) onProgress,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/update.apk';

      // Для завантаження великого файлу з відображенням відсотків використовуємо Dio
      await _dio.download(
        apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = received / total;
            onProgress(progress);
          }
        },
      );

      // Відкриваємо файл для встановлення
      final result = await OpenFilex.open(savePath);
      debugPrint('Результат відкриття: ${result.message}');
    } catch (e) {
      debugPrint('Помилка завантаження APK: $e');
    }
  }
}
