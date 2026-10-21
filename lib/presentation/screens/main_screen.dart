import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/printer_service.dart';
import '../../core/services/update_service.dart';
import '../../data/repositories/api/api_client.dart';
import '../bloc/scanner/scanner_bloc.dart';
import '../bloc/scanner/scanner_event.dart';
import '../bloc/scanner/scanner_state.dart';
import '../../../core/models/invoice.dart';
import '../../../core/services/settings_service.dart';

import 'dart:convert'; // Потрібно для utf8, якщо тут залишити String

import 'package:flutter/services.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _deviceName = '';
  String _labelWidth = '58';
  String _labelHeight = '40';
  String _printerIp = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAppUpdate();
  }

  /// Завантажуємо всі налаштування: назву ТЗД та розміри етикетки
  void _loadSettings() {
    final settingsService = context.read<SettingsService>();

    final name = settingsService.getDeviceName();
    final width = settingsService.getLabelWidth();
    final height = settingsService.getLabelHeight();
    final printerIp = settingsService.getPrinterIp();

    setState(() {
      _deviceName = name;
      _labelWidth = width;
      _labelHeight = height;
      _printerIp = printerIp;
    });

    if (name.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSettingsDialog();
      });
    }
  }

  /// 1. Підменю: Налаштування ТЗД та розмірів етикетки
  Future<void> _showSettingsDialog() async {
    final nameController = TextEditingController(text: _deviceName);
    final widthController = TextEditingController(text: _labelWidth);
    final heightController = TextEditingController(text: _labelHeight);
    final ipController = TextEditingController(text: _printerIp);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.blue),
              SizedBox(width: 8),
              Text('Налаштування'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ідентифікатор термінала (Склад):',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Наприклад: 9В',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'IP-адреса принтера:',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ipController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [IpAddressInputFormatter()],
                  decoration: InputDecoration(
                    hintText: '192.168.0.120',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.wifi),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Розмір етикетки (мм):',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widthController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Ширина',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'X',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: heightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Висота',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (_deviceName.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Скасувати'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                final nameText = nameController.text.trim();
                final widthText = widthController.text.trim();
                final heightText = heightController.text.trim();
                final ipText = ipController.text.trim();

                final ipRegExp = RegExp(
                  r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$',
                );
                if (!ipRegExp.hasMatch(ipText)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Введіть коректну IP-адресу!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (nameText.isNotEmpty &&
                    widthText.isNotEmpty &&
                    heightText.isNotEmpty) {
                  final settingsService = context.read<SettingsService>();
                  final navigator = Navigator.of(dialogContext);

                  await settingsService.saveDeviceName(nameText);
                  await settingsService.saveLabelWidth(widthText);
                  await settingsService.saveLabelHeight(heightText);
                  await settingsService.savePrinterIp(ipText);

                  if (!mounted) return;

                  setState(() {
                    _deviceName = nameText;
                    _labelWidth = widthText;
                    _labelHeight = heightText;
                    _printerIp = ipText;
                  });

                  navigator.pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Будь ласка, заповніть всі поля'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('Зберегти'),
            ),
          ],
        );
      },
    );
  }

  /// 2. Підменю: Форма друку окремої етикетки (Код, Найменування, Друк)
  Future<void> _showCustomLabelPrintDialog() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    // Додаємо контролер для кількості з дефолтним значенням 1
    final copiesController = TextEditingController(text: '');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.print, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text(
                'Друк етикетки',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'Код',
                      hintText: 'Введіть код або артикул',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.qr_code),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Найменування',
                      hintText: 'Введіть назву товару',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // НОВЕ ПОЛЕ ДЛЯ КІЛЬКОСТІ КОПІЙ
                  TextField(
                    controller: copiesController,
                    keyboardType:
                        TextInputType.number, // Відкриває цифрову клавіатуру
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ], // Тільки цифри
                    decoration: InputDecoration(
                      labelText: 'Кількість етикеток',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.file_copy_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Закрити'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Друк'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                final code = codeController.text.trim();
                final name = nameController.text.trim();
                final copiesText = copiesController.text.trim();

                // Перетворюємо введений текст на число. Якщо щось не так (порожньо) — друкуємо 1
                final int copies = int.tryParse(copiesText) ?? 0;

                if (code.isEmpty && name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Заповніть хоча б одне поле для друку'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (copies <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Кількість має бути більше нуля'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop();

                // Передаємо параметр copies у метод друку
                _printCustomLabel(code: code, name: name, copies: copies);
              },
            ),
          ],
        );
      },
    );
  }

  /// Метод для надсилання окремого TSPL-макета на принтер
  Future<void> _printCustomLabel({
    required String code,
    required String name,
    required int copies,
  }) async {
    final settingsService = context.read<SettingsService>();
    final printerService = context.read<PrinterService>();
    final messenger = ScaffoldMessenger.of(context);

    final width = settingsService.getLabelWidth();
    final height = settingsService.getLabelHeight();
    final ipAddress = settingsService.getPrinterIp();

    if (ipAddress.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Вкажіть IP-адресу принтера в налаштуваннях!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String safeName = PrinterService.sanitizeForTspl(name);
    final String safeCode = PrinterService.sanitizeForTspl(code);

    // Тут ми поки що залишаємо текстовий формат команд, бо це окремий друк.
    // Якщо захочете зробити жирним і тут, треба буде адаптувати під List<int>.
    final String tsplCommand =
        """
SIZE $width mm, $height mm
GAP 2 mm, 0 mm
DIRECTION 1
CODEPAGE UTF-8
CLS
TEXT 100,60,"4",0,2,2,"$safeCode"
BLOCK 10,140,444,160,"3",0,2,2,1,2,1,"$safeName"
PRINT $copies 
""";

    // Відправляємо масив байтів (utf8.encode працюватиме, бо ми додали імпорт зверху)
    final success = await printerService.printLabels(
      ipAddress: ipAddress,
      payload: utf8.encode(tsplCommand),
    );

    if (mounted) {
      if (!success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Помилка з\'єднання з принтером!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showConfirmationDialog(
    BuildContext context,
    String question,
    Invoice invoice,
  ) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Попередження',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(question, style: const TextStyle(fontSize: 18)),

          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.only(
            bottom: 16,
            left: 16,
            right: 16,
          ),
          actions: [
            // Велика кнопка НІ
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(130, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'НІ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),

            // Велика кнопка ТАК
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(130, 60),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'ТАК',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;

    if (result == true) {
      context.read<ScannerBloc>().add(ConfirmContinue(invoice));
    } else {
      context.read<ScannerBloc>().add(ResetScanner());
    }
  }

  Future<void> _checkAppUpdate() async {
    final apiClient = context.read<ApiClient>();
    final updateService = UpdateService(apiClient: apiClient);

    final updateInfo = await updateService.checkForUpdates(type: "android");

    if (updateInfo != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Доступне оновлення'),
          content: Text(
            'Знайдено нову версію: ${updateInfo['version']}. Оновити зараз?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Пізніше'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Завантаження оновлення...'),
                    backgroundColor: Colors.blue,
                  ),
                );

                updateService.downloadAndInstall(updateInfo['url'], (progress) {
                  debugPrint(
                    'Завантажено: ${(progress * 100).toStringAsFixed(0)}%',
                  );
                });
              },
              child: const Text('Оновити'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        centerTitle: true,
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Меню налаштувань',
              onPressed: () {
                Scaffold.of(ctx).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueAccent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.settings_suggest,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Меню термінала',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _deviceName.isNotEmpty
                        ? 'Пристрій: $_deviceName'
                        : 'Пристрій не налаштовано',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.badge, color: Colors.blueAccent),
              title: const Text('Ідентифікація девайса'),
              subtitle: Text(
                _deviceName.isNotEmpty ? _deviceName : 'Вказати назву',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                _showSettingsDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.print_outlined,
                color: Colors.blueAccent,
              ),
              title: const Text('Друк етикетки товару'),
              subtitle: const Text('Ручний друк за кодом/назвою'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                _showCustomLabelPrintDialog();
              },
            ),
          ],
        ),
      ),
      body: BlocConsumer<ScannerBloc, ScannerState>(
        listener: (context, state) {
          if (state is ScannerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (state is ScannerConfirmationRequired) {
            _showConfirmationDialog(context, state.questionText, state.invoice);
          } else if (state is ScannerSuccess) {
            context.push('/quantity', extra: state.invoice);
            context.read<ScannerBloc>().add(ResetScanner());
          }
        },
        builder: (context, state) {
          return BarcodeKeyboardListener(
            bufferDuration: const Duration(milliseconds: 200),
            onBarcodeScanned: (barcode) {
              if (_deviceName.isEmpty) {
                _showSettingsDialog();
                return;
              }
              context.read<ScannerBloc>().add(BarcodeScanned(barcode));
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    state is ScannerError
                        ? Icons.error_outline
                        : Icons.qr_code_scanner_rounded,
                    size: 130,
                    color: _getIconColor(state),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _getStatusText(state),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Піднесіть накладну до сканера',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                  const SizedBox(height: 40),
                  if (state is ScannerLoading)
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getIconColor(ScannerState state) {
    if (state is ScannerLoading) return Colors.grey;
    if (state is ScannerError) return Colors.red;
    if (state is ScannerSuccess) return Colors.green;
    return Colors.blueAccent;
  }

  String _getStatusText(ScannerState state) {
    if (state is ScannerLoading) return 'Пошук документа...';
    if (state is ScannerError) return 'Помилка';
    if (state is ScannerSuccess) return 'Успіх!';
    return 'Готовий до сканування';
  }
}

class IpAddressInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text.length > newValue.text.length) {
      return newValue;
    }

    String text = newValue.text;
    text = text.replaceAll(RegExp(r'[^0-9.]'), '');

    List<String> blocks = text.split('.');

    if (blocks.length > 4) {
      blocks = blocks.sublist(0, 4);
    }

    String formatted = '';
    for (int i = 0; i < blocks.length; i++) {
      String block = blocks[i];

      if (block.length > 3) {
        String extra = block.substring(3);
        block = block.substring(0, 3);
        if (i < 3) {
          formatted += '$block.$extra';
          continue;
        }
      }

      formatted += block;

      // ВИПРАВЛЕНО: додано знак мінуса
      if (i < blocks.length - 1) {
        formatted += '.';
      } else if (block.length == 3 && i < 3) {
        formatted += '.';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
