import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Додайте цей імпорт

import 'core/router/app_router.dart';
import 'core/services/printer_service.dart';
import 'core/services/settings_service.dart';
import 'data/repositories/api/api_client.dart';
import 'data/repositories/invoice_repository.dart';
import 'presentation/bloc/scanner/scanner_bloc.dart';

void main() async {
  // 1. Обов'язково першим рядком перед будь-якою роботою плагінів
  WidgetsFlutterBinding.ensureInitialized();

  // 2. ОДИН РАЗ ініціалізуємо SharedPreferences для всього додатка
  final prefs = await SharedPreferences.getInstance();

  // 3. Створюємо сервіс налаштувань із готовим кешем
  final settingsService = SettingsService(prefs);

  // 4. Безпечно дістаємо назву складу для BLoC
  String warehouseFromSettings = settingsService.getWarehouseName();
  if (warehouseFromSettings.isEmpty) {
    warehouseFromSettings = "Основний склад"; // Дефолтне значення
  }

  // 5. Запуск застосунку з передачею готових даних
  runApp(
    MyApp(
      settingsService: settingsService,
      currentWarehouseName: warehouseFromSettings,
    ),
  );
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;
  final String currentWarehouseName;

  const MyApp({
    super.key,
    required this.settingsService,
    required this.currentWarehouseName,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>(create: (context) => ApiClient()),
        RepositoryProvider<InvoiceRepository>(
          create: (context) =>
              InvoiceRepository(apiClient: context.read<ApiClient>()),
        ),
        // Передаємо вже створений екземпляр сервісу через RepositoryProvider.value
        RepositoryProvider<SettingsService>.value(value: settingsService),
        RepositoryProvider<PrinterService>(
          create: (context) => PrinterService(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ScannerBloc(
              repository: context.read<InvoiceRepository>(),
              // Більше ніякого хардкоду! Назва береться з пам'яті пристрою
              currentWarehouseName: currentWarehouseName,
            ),
          ),
        ],
        child: MaterialApp.router(
          //title: 'Складський термінал',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
