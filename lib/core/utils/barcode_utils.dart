class BarcodeUtils {
  /// Аналог функції Прав() з 1С (бере останні [length] символів)
  /// Якщо рядок коротший, заповнює його нулями зліва (щоб EAN-13 завжди мав 13 цифр)
  static String right(String text, int length) {
    if (text.length >= length) {
      return text.substring(text.length - length);
    }
    return text.padLeft(length, '0');
  }

  /// Обчислення контрольної цифри EAN-13 (аналог КонтрольныйСимволEAN з 1С)
  static String calculateEan13CheckDigit(String baseBarcode) {
    int oddSum = 0; // Для непарних позицій (в 1С: Нечетн)
    int evenSum = 0; // Для парних позицій (в 1С: Четн)

    for (int i = 0; i < 12; i++) {
      int digit = int.parse(baseBarcode[i]);
      // У програмуванні індекси починаються з 0, тому логіка парності дзеркальна до 1С
      if (i % 2 == 0) {
        oddSum += digit;
      } else {
        evenSum += digit;
      }
    }

    evenSum = evenSum * 3;
    int checkDigit = 10 - ((oddSum + evenSum) % 10);
    if (checkDigit == 10) {
      checkDigit = 0;
    }

    return checkDigit.toString();
  }

  /// Головна функція генерації штрихкоду для конкретного місця
  static String generateBoxBarcode({
    required String invoiceNumber,
    required String warehouseCode,
    required int boxIndex, // Поточний номер місця (Сч в 1С)
  }) {
    final String rightInvoice = right(invoiceNumber, 6);
    final String rightWarehouse = right(warehouseCode, 2);
    final String strCounter = right(boxIndex.toString(), 3);

    // Збираємо базові 12 цифр
    final String baseBarcode = "2$rightInvoice$rightWarehouse$strCounter";

    // Рахуємо контрольну цифру (13-ту)
    final String checkDigit = calculateEan13CheckDigit(baseBarcode);

    return "$baseBarcode$checkDigit";
  }
}
