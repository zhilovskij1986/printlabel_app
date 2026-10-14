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
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(prefs);

  // Отримуємо ідентифікатор пристрою (numtab)
  String numTabFromSettings = settingsService.getDeviceName();
  if (numTabFromSettings.isEmpty) {
    numTabFromSettings =
        "Основний склад"; // Дефолтне значення, якщо ще не налаштовано
  }

  runApp(
    MyApp(
      settingsService: settingsService,
      currentWarehouseName: numTabFromSettings, // Передаємо його в BLoC
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
