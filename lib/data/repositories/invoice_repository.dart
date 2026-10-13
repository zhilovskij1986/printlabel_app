import '../../core/models/generated_label.dart';
import '../../core/models/invoice.dart';
import '../../core/models/nomenclature_item.dart';
import 'api/api_client.dart';

class InvoiceRepository {
  final ApiClient apiClient;

  InvoiceRepository({required this.apiClient});

  // 1. Отримання самої накладної (повертає об'єкт Map)
  Future<Invoice?> getInvoiceByBarcode(String barcode) async {
    try {
      final dynamic response = await apiClient.get(
        '/docsale',
        queryParameters: {'barcode_doc_sale': barcode},
      );

      // 1. ПЕРЕВІРКА НА ПОРОЖНЮ ВІДПОВІДЬ
      if (response == null) {
        throw Exception('Документ не знайдено в базі');
      }

      // 2. БЕЗПЕЧНЕ ПРИВЕДЕННЯ ТИПІВ
      if (response is Map<String, dynamic>) {
        // 3. ПЕРЕВІРКА НА СТРУКТУРУ ПОМИЛКИ ВІД 1С
        // (Якщо 1С повертає MessageOK з текстом "Не знайдено документ")
        if (response.containsKey('MessageOK')) {
          final messageOk = response['MessageOK'];
          if (messageOk is Map<String, dynamic> &&
              messageOk.containsKey('ЗаписьДокумента')) {
            throw Exception(
              messageOk['ЗаписьДокумента'],
            ); // Викине "Не знайдено документ"
          }
        }

        // Додаткова перевірка, якщо 1С поверне ключ 'error'
        if (response.containsKey('error')) {
          throw Exception(response['error']);
        }

        // Якщо помилок немає, спокійно парсимо накладну
        return Invoice.fromJson(response, barcode);
      } else {
        throw Exception('Сервер повернув невідомий формат даних');
      }
    } catch (e) {
      // rethrow передасть помилку у ScannerBloc, де вона виведеться на екран
      rethrow;
    }
  }

  // 2. Отримання списку товарів (повертає масив List)
  Future<List<NomenclatureItem>> getInvoiceItems(String barcode) async {
    try {
      final dynamic response = await apiClient.get(
        '/labelitems',
        queryParameters: {'barcode_doc_sale': barcode},
      );

      // Перевіряємо, чи повернула 1С саме масив (List)
      if (response is List) {
        // Кастуємо response до List<dynamic>, щоб Dart дозволив викликати .map() та .toList()
        final List<dynamic> list = response;

        return list
            .map((e) => NomenclatureItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return []; // Якщо прийшов не масив, повертаємо порожній список
    } catch (e) {
      rethrow;
    }
  }

  Future<List<GeneratedLabel>> generateBarcodesOnServer(
    String docBarcode,
    int qty,
    String numTab,
  ) async {
    try {
      final dynamic response = await apiClient.post(
        '/doc',
        body: {"barcode_doc": docBarcode, "numcopy": qty, "numtab": numTab},
      );

      // 1. Перевірка на порожню відповідь
      if (response == null) {
        throw Exception('Порожня відповідь від сервера');
      }

      if (response is Map<String, dynamic>) {
        // 2. Перевірка наявності MessageOK
        if (response.containsKey('MessageOK')) {
          final messageOk = response['MessageOK'];

          if (messageOk is Map<String, dynamic> &&
              messageOk.containsKey('generated_barcodes')) {
            final barcodesData = messageOk['generated_barcodes'];

            // 3. БЕЗПЕЧНА ПЕРЕВІРКА: Якщо 1С повернула false (Ложь)
            if (barcodesData is bool && barcodesData == false) {
              throw Exception(
                'Сервер відхилила запит на генерацію (можливо, збій запису або нульова кількість).',
              );
            }

            // 4. БЕЗПЕЧНА ПЕРЕВІРКА: Якщо 1С повернула масив (Успіх)
            if (barcodesData is List) {
              return barcodesData
                  .map(
                    (json) =>
                        GeneratedLabel.fromJson(json as Map<String, dynamic>),
                  )
                  .toList();
            }
          }
        }

        // Перевірка на стандартну помилку від 1С
        if (response.containsKey('error')) {
          throw Exception(response['error']);
        }
      }

      // Якщо структура взагалі не збігається з очікуваною
      throw Exception('Неправильний формат відповіді від 1С');
    } catch (e) {
      // Щоб уникнути довгого ланцюжка "Exception: Помилка генерації: Exception: ...",
      // просто прокидаємо помилку далі, якщо це вже Exception
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Помилка сервера: $e');
    }
  }
}
