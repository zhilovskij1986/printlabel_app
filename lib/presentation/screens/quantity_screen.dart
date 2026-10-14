import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/generated_label.dart';
import '../../core/models/invoice.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/settings_service.dart';
import '../../data/repositories/invoice_repository.dart';

class QuantityScreen extends StatefulWidget {
  final Invoice invoice;

  const QuantityScreen({super.key, required this.invoice});

  @override
  State<QuantityScreen> createState() => _QuantityScreenState();
}

class _QuantityScreenState extends State<QuantityScreen> {
  // За замовчуванням ставимо 0 копію
  String _quantity = '0';
  // Прапорець, щоб при першому натисканні цифри одиниця замінювалась, а не ставала "15"
  bool _isFirstTap = true;

  /// Обробка натискання на цифри
  void _onNumberTap(String number) {
    setState(() {
      if (_isFirstTap || _quantity == '0') {
        _quantity = number;
        _isFirstTap = false;
      } else {
        if (_quantity.length < 4) {
          _quantity += number;
        }
      }
    });
  }

  /// Очищення поля вводу (кнопка С)
  void _onClear() {
    setState(() {
      _quantity = '0';
      _isFirstTap = true;
    });
  }

  /// Метод генерації команди TSPL та відправки на принтер (кнопка Друк)
  Future<void> _printLabels() async {
    final int qty = int.tryParse(_quantity) ?? 0;
    if (qty == 0) return;

    final settingsService = context.read<SettingsService>();
    final repository = context.read<InvoiceRepository>();
    final printerService = context.read<PrinterService>();
    final messenger = ScaffoldMessenger.of(context);

    final width = settingsService.getLabelWidth();
    final height = settingsService.getLabelHeight();
    final ipAddress = settingsService.getPrinterIp();
    final numTab = settingsService.getDeviceName();

    if (ipAddress.isEmpty) {
      // 3. ВИКОРИСТОВУЄМО ЗБЕРЕЖЕНИЙ messenger ЗАМІСТЬ ScaffoldMessenger.of(context)
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Вкажіть IP-адресу принтера!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // ЗМІНЕНО: Тепер ми чекаємо масив об'єктів GeneratedLabel
      final List<GeneratedLabel> serverLabels = await repository
          .generateBarcodesOnServer(widget.invoice.scannedBarcode, qty, numTab);

      if (serverLabels.isEmpty) {
        throw Exception('Сервер не повернув дані для друку');
      }

      // 2. Формуємо один загальний пакет TSPL для принтера
      StringBuffer tsplBuffer = StringBuffer();
      tsplBuffer.writeln("SIZE $width mm, $height mm");
      tsplBuffer.writeln("GAP 2 mm, 0 mm");
      tsplBuffer.writeln("DIRECTION 1");
      tsplBuffer.writeln("CODEPAGE UTF-8");

      // ЗМІНЕНО: Проходимось по об'єктах GeneratedLabel
      for (GeneratedLabel label in serverLabels) {
        tsplBuffer.writeln("CLS");

        // Рядок 1: Накладна (X=10, Y=10)
        tsplBuffer.writeln(
          'TEXT 10,10,"4",0,1,1,"Накладна: ${widget.invoice.number}"',
        );

        // Рядок 2: Додатковий текст із 1С (X=10, Y=50)
        tsplBuffer.writeln('TEXT 10,50,"3",0,1,1,"${label.text}"');

        // Рядок 3: Сам EAN-13 (Опустили Y на 90, щоб текст помістився)
        tsplBuffer.writeln(
          'BARCODE 80,90,"EAN13",80,0,0,3,3,"${label.barcode}"',
        );

        tsplBuffer.writeln("PRINT 1");
      }

      // 3. Відправляємо на принтер
      final success = await printerService.printLabels(
        ipAddress: ipAddress,
        tsplCommand: tsplBuffer.toString(),
      );

      if (mounted) {
        if (success) {
          // Показуємо повідомлення про успіх
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Етикетки успішно надруковано!'),
              backgroundColor: Colors.green,
            ),
          );

          // Закриваємо поточний екран і повертаємося на головний
          context.pop();
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Помилка принтера (Перевірте IP)'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Введення кількості'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Використовуємо Row для планшетної (горизонтальної) орієнтації
            return Row(
              children: [
                // 1. ЛІВА ЧАСТИНА: Цифровий блок (Numpad) - займає 60% екрана
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _buildNumpadRow(['1', '2', '3']),
                        const SizedBox(height: 16),
                        _buildNumpadRow(['4', '5', '6']),
                        const SizedBox(height: 16),
                        _buildNumpadRow(['7', '8', '9']),
                        const SizedBox(height: 16),
                        _buildActionRow(), // Ряд із кнопками "С", "0", "ДРУК"
                      ],
                    ),
                  ),
                ),

                // Вертикальний розділювач
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Colors.black12,
                ),

                // 2. ПРАВА ЧАСТИНА: Інформаційна панель - займає 40% екрана
                Expanded(
                  flex: 4,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32.0,
                      vertical: 24.0,
                    ),
                    child: Column(
                      children: [
                        // ЗАМІСТЬ Spacer() загортаємо весь контент у Expanded + SingleChildScrollView
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Кількість копій',
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _quantity,
                                  style: const TextStyle(
                                    fontSize: 72,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),

                                const Divider(height: 48, thickness: 2),

                                // Блок з номером документа
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.blueAccent.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.blue.withValues(alpha: 0.05),
                                  ),
                                  child: Text(
                                    '№ ${widget.invoice.number}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Кількість місць по базі 1С
                                // const Text(
                                //   'Кількість місць',
                                //   style: TextStyle(
                                //     fontSize: 20,
                                //     color: Colors.black54,
                                //   ),
                                // ),
                                // const SizedBox(height: 8),
                                // Text(
                                //   '${widget.invoice.placesCount}',
                                //   style: const TextStyle(
                                //     fontSize: 32,
                                //     fontWeight: FontWeight.bold,
                                //     color: Colors.blue,
                                //     decoration: TextDecoration.underline,
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ),

                        // const SizedBox(
                        //   height: 16,
                        // ), // Відступ між скролом і кнопкою
                        // Кнопка "Список товарів" (завжди закріплена внизу)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.list_alt, size: 28),
                            label: const Text(
                              'Список товарів',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueAccent,
                              side: const BorderSide(
                                color: Colors.blueAccent,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () {
                              context.push(
                                '/nomenclature',
                                extra: widget.invoice.scannedBarcode,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Метод для побудови ряду з трьох звичайних цифр
  Widget _buildNumpadRow(List<String> numbers) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: numbers.map((number) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.grey[300], // Сірий колір кнопок як на скріні
                  foregroundColor: Colors.black87,
                  elevation: 4,
                  // Овальна форма (StadiumBorder)
                  shape: const StadiumBorder(),
                ),
                onPressed: () => _onNumberTap(number),
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Метод для побудови нижнього ряду (Скинути, 0, Друк)
  Widget _buildActionRow() {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Кнопка "С" (Червона)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.red[700],
                  elevation: 4,
                  shape: const StadiumBorder(),
                ),
                onPressed: _onClear,
                child: const Text(
                  'С',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          // Кнопка "0"
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  elevation: 4,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => _onNumberTap('0'),
                child: const Text(
                  '0',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w400),
                ),
              ),
            ),
          ),
          // Кнопка "ДРУК" (Зелена)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: const StadiumBorder(),
                ),
                onPressed: _printLabels,
                child: const Text(
                  'Друк',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
