import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/invoice_repository.dart';
import '../../../core/models/invoice.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final InvoiceRepository repository;
  // Назва поточного складу, де стоїть планшет (аналог глНаименованиеСклада)
  final String currentWarehouseName;

  ScannerBloc({
    required this.repository,
    this.currentWarehouseName = "Основний склад",
  }) : super(ScannerInitial()) {
    on<BarcodeScanned>(_onBarcodeScanned);
    on<ConfirmContinue>(_onConfirmContinue);
    on<ResetScanner>(_onResetScanner);
  }

  Future<void> _onBarcodeScanned(
    BarcodeScanned event,
    Emitter<ScannerState> emit,
  ) async {
    if (state is ScannerLoading) return;
    emit(ScannerLoading());

    try {
      final Invoice? invoice = await repository.getInvoiceByBarcode(
        event.barcode,
      );

      if (invoice == null || invoice.number.isEmpty) {
        emit(const ScannerError("Не знайдено документ"));
        await Future.delayed(const Duration(seconds: 2));
        emit(ScannerInitial());
        return;
      }

      // Перевірка умови 1: Склад не знайдено серед дозволених
      final bool isAnotherWarehouse = !invoice.warehouseNames.contains(
        currentWarehouseName,
      );
      final bool hasPrintedLabels = invoice.loadingPlaceBarcode
          .trim()
          .isNotEmpty;

      if (isAnotherWarehouse) {
        String question =
            "Накладна № ${invoice.number} з іншого складу. Продовжити?";
        if (hasPrintedLabels) {
          question =
              "Накладна № ${invoice.number} з іншого складу, та за цим документом вже роздруковані етикетки. Продовжити?";
        }
        emit(
          ScannerConfirmationRequired(questionText: question, invoice: invoice),
        );
      }
      // Перевірка умови 2: Склад наш, але етикетки вже роздруковані
      else if (hasPrintedLabels) {
        emit(
          ScannerConfirmationRequired(
            questionText:
                "За цим документом вже роздруковані етикетки. Продовжити?",
            invoice: invoice,
          ),
        );
      }
      // Умова 3: Все чисто
      else {
        emit(ScannerSuccess(invoice));
      }
    } catch (e) {
      emit(ScannerError(e.toString().replaceAll('Exception: ', '')));
      await Future.delayed(const Duration(seconds: 2));
      emit(ScannerInitial());
    }
  }

  void _onConfirmContinue(ConfirmContinue event, Emitter<ScannerState> emit) {
    emit(ScannerSuccess(event.invoice));
  }

  void _onResetScanner(ResetScanner event, Emitter<ScannerState> emit) {
    emit(ScannerInitial());
  }
}
