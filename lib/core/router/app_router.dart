// lib/core/router/app_router.dart

import 'package:go_router/go_router.dart';

import '../../presentation/screens/main_screen.dart';
import '../../presentation/screens/quantity_screen.dart';
import '../../presentation/screens/nomenclature_screen.dart'; // Додайте цей імпорт
import '../models/invoice.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const MainScreen()),
    GoRoute(
      path: '/quantity',
      builder: (context, state) {
        final invoice = state.extra as Invoice;
        return QuantityScreen(invoice: invoice);
      },
    ),
    GoRoute(
      path: '/nomenclature',
      builder: (context, state) {
        // Тепер ми передаємо сюди номер (штрихкод) накладної
        final invoiceBarcode = state.extra as String;
        return NomenclatureScreen(invoiceBarcode: invoiceBarcode);
      },
    ),
  ],
);
