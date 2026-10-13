import 'package:equatable/equatable.dart';

import '../../../core/models/invoice.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();
  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}

class ScannerLoading extends ScannerState {}

/// Перехід без питань або коли користувач погодився у діалозі
class ScannerSuccess extends ScannerState {
  final Invoice invoice;
  const ScannerSuccess(this.invoice);

  @override
  List<Object?> get props => [invoice];
}

/// Стан запитання: містить текст питання та саму накладну
class ScannerConfirmationRequired extends ScannerState {
  final String questionText;
  final Invoice invoice;

  const ScannerConfirmationRequired({
    required this.questionText,
    required this.invoice,
  });

  @override
  List<Object?> get props => [questionText, invoice];
}

class ScannerError extends ScannerState {
  final String message;
  const ScannerError(this.message);

  @override
  List<Object?> get props => [message];
}
