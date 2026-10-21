import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/generated_label.dart';
import '../../core/models/invoice.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/settings_service.dart';
import '../../data/repositories/invoice_repository.dart';
import '../bloc/scanner/scanner_bloc.dart';
import '../bloc/scanner/scanner_event.dart';
import '../bloc/scanner/scanner_state.dart';

class QuantityScreen extends StatefulWidget {
  final Invoice invoice;

  const QuantityScreen({super.key, required this.invoice});

  @override
  State<QuantityScreen> createState() => _QuantityScreenState();
}

class _QuantityScreenState extends State<QuantityScreen> {
  String _quantity = '0';
  bool _isFirstTap = true;

  // 1. Змінна для збереження BLoC
  late final ScannerBloc _scannerBloc;

  @override
  void initState() {
    super.initState();
    // 2. Отримуємо BLoC при ініціалізації екрана
    _scannerBloc = context.read<ScannerBloc>();
  }

  @override
  void dispose() {
    // Скидаємо стан, ТІЛЬКИ якщо ми не в процесі завантаження нового штрихкоду
    if (_scannerBloc.state is! ScannerLoading) {
      _scannerBloc.add(ResetScanner());
    }
    super.dispose();
  }

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

  void _onClear() {
    setState(() {
      _quantity = '0';
      _isFirstTap = true;
    });
  }

  /// Метод генерації команди TSPL (як байтів) та відправки на принтер (кнопка Друк)
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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Вкажіть IP-адресу принтера!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final List<GeneratedLabel> serverLabels = await repository
          .generateBarcodesOnServer(widget.invoice.scannedBarcode, qty, numTab);

      if (serverLabels.isEmpty) {
        throw Exception('Сервер не повернув дані для друку');
      }

      // Збираємо список байтів замість рядка
      List<int> payload = [];

      // "Будильник" та налаштування етикетки (обов'язково додаємо \r\n для нових рядків)
      payload.addAll(utf8.encode('\r\n\r\n'));
      payload.addAll(utf8.encode('SIZE $width mm, $height mm\r\n'));
      payload.addAll(utf8.encode('GAP 2 mm, 0 mm\r\n'));
      payload.addAll(utf8.encode('DIRECTION 1\r\n'));
      payload.addAll(utf8.encode('CODEPAGE UTF-8\r\n'));

      // Цикл по всіх етикетках з 1С
      for (GeneratedLabel label in serverLabels) {
        payload.addAll(utf8.encode('CLS\r\n'));

        final safeTitle = PrinterService.sanitizeForTspl(label.title);
        final safeText = PrinterService.sanitizeForTspl(label.text);

        // 1. ЗАГОЛОВОК (Зверху) - Генерується як картинка з жирним шрифтом
        List<int> titleBitmapBytes = await printerService.generateBoldTitleTspl(
          safeTitle,
        );
        payload.addAll(titleBitmapBytes);

        // 2. ШТРИХКОД (Посередині)
        payload.addAll(
          utf8.encode(
            'BARCODE 80,150,"EAN13",70,0,0,3,3,"${label.barcode}"\r\n',
          ),
        );

        // 3. ТЕКСТ (Знизу) - Стандартний шрифт TSPL
        payload.addAll(
          utf8.encode('BLOCK 10,230,444,70,"3",0,1,1,10,1,"$safeText"\r\n'),
        );

        payload.addAll(utf8.encode('PRINT 1\r\n'));
      }

      final success = await printerService.printLabels(
        ipAddress: ipAddress,
        payload: payload,
      );

      if (mounted) {
        if (success) {
          context.pop();
          // ResetScanner() тут видалено, бо його тепер гарантовано викличе dispose()
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
    return BlocListener<ScannerBloc, ScannerState>(
      listener: (context, state) {
        // Якщо комірник відсканував щось нове (почалося завантаження),
        // негайно закриваємо цей екран і повертаємо його на Головний!
        if (state is ScannerLoading) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: const Text('Введення кількості'),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
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
                          _buildActionRow(),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Colors.black12,
                  ),
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
                                      color: Colors.blue.withValues(
                                        alpha: 0.05,
                                      ),
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
                                ],
                              ),
                            ),
                          ),
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
      ),
    );
  }

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
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  elevation: 4,
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

  Widget _buildActionRow() {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
