import 'package:equatable/equatable.dart';

import '../../../core/models/invoice.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();
  @override
  List<Object?> get props => [];
}

class BarcodeScanned extends ScannerEvent {
  final String barcode;
  const BarcodeScanned(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

/// Користувач натиснув "Продовжити" у спливаючому вікні
class ConfirmContinue extends ScannerEvent {
  final Invoice invoice;
  const ConfirmContinue(this.invoice);

  @override
  List<Object?> get props => [invoice];
}

/// Скидання у готовність до сканування
class ResetScanner extends ScannerEvent {}
