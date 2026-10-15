import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/nomenclature_item.dart';
import '../../data/repositories/invoice_repository.dart';

class NomenclatureScreen extends StatefulWidget {
  final String invoiceBarcode;

  const NomenclatureScreen({super.key, required this.invoiceBarcode});

  @override
  State<NomenclatureScreen> createState() => _NomenclatureScreenState();
}

class _NomenclatureScreenState extends State<NomenclatureScreen> {
  // Згруповані товари: Ключ - це код товару, Значення - список його фотографій
  Map<int, List<NomenclatureItem>> _groupedItems = {};

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  /// Завантаження товарів з 1С та їх групування
  Future<void> _loadItems() async {
    try {
      final repository = context.read<InvoiceRepository>();
      final items = await repository.getInvoiceItems(widget.invoiceBarcode);

      final grouped = <int, List<NomenclatureItem>>{};
      for (var item in items) {
        if (!grouped.containsKey(item.codeItem)) {
          grouped[item.codeItem] = [];
        }
        grouped[item.codeItem]!.add(item);
      }

      if (mounted) {
        setState(() {
          _groupedItems = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Помилка завантаження: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Форматування коду (наприклад, 309423 -> 309 423)
  String _formatCode(int code) {
    final codeStr = code.toString();
    if (codeStr.length > 3) {
      final firstPart = codeStr.substring(0, codeStr.length - 3);
      final secondPart = codeStr.substring(codeStr.length - 3);
      return '$firstPart $secondPart';
    }
    return codeStr;
  }

  /// Відкриття діалогу з гортанням великих фотографій
  /// Відкриття діалогу з гортанням великих фотографій на весь екран
  void _showImageCarouselDialog(List<NomenclatureItem> productPhotos) {
    showDialog(
      context: context,
      builder: (context) {
        int currentIndex = 0;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final currentItem = productPhotos[currentIndex];
            final imageBytes = currentItem.imageBytes;
            final hasImage = imageBytes != null && imageBytes.isNotEmpty;

            return Dialog.fullscreen(
              backgroundColor: Colors.white,
              child: SafeArea(
                child: Column(
                  children: [
                    // 1. ВЕРХНЯ ЧАСТИНА: Назва та Код товару
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            currentItem.nameItem,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Код: ${_formatCode(currentItem.codeItem)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. КНОПКИ ПЕРЕМИКАННЯ ФОТО (якщо їх більше однієї)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildNavButton(
                          icon: Icons.arrow_left,
                          onPressed: currentIndex > 0
                              ? () => setDialogState(() => currentIndex--)
                              : null,
                        ),
                        if (productPhotos.length > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Text(
                              '${currentIndex + 1} / ${productPhotos.length}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                        _buildNavButton(
                          icon: Icons.arrow_right,
                          onPressed: currentIndex < productPhotos.length - 1
                              ? () => setDialogState(() => currentIndex++)
                              : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3. ЦЕНТРАЛЬНА ЧАСТИНА: Фото на весь вільний простір
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(
                          milliseconds: 300,
                        ), // Тривалість анімації
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              // Плавне перемикання через прозорість (Fade)
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                        child: InteractiveViewer(
                          // ВАЖЛИВО: Цей ключ каже Flutter, що картинка змінилася
                          // і потрібно запустити анімацію переходу
                          key: ValueKey<int>(currentIndex),
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: hasImage
                              ? Image.memory(
                                  imageBytes,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 100,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // 4. НИЖНЯ ЧАСТИНА: Кнопка "Закрити"
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Закрити',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(12),
        backgroundColor: Colors.amber[100],
        foregroundColor: Colors.orange.shade800,
        disabledBackgroundColor: Colors.grey[200],
        disabledForegroundColor: Colors.grey,
        elevation: onPressed == null ? 0 : 2,
      ),
      onPressed: onPressed,
      child: Icon(icon, size: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade100, // М'який фон для контрасту з картками
      appBar: AppBar(
        title: const Text(
          'Номенклатура',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              children: [
                // 1. Сучасний банер-підказка замість простого тексту
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_circle,
                        color: Colors.blue.shade700,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Натисніть на картку товару, щоб переглянути великі фотографії.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Список карток товарів
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _groupedItems.length,
                    itemBuilder: (context, index) {
                      final int code = _groupedItems.keys.elementAt(index);
                      final List<NomenclatureItem> photos =
                          _groupedItems[code]!;
                      final String name = photos.first.nameItem;

                      // Перевіряємо, чи є перша картинка для мініатюри
                      final hasImage =
                          photos.first.imageBytes != null &&
                          photos.first.imageBytes!.isNotEmpty;

                      return Card(
                        elevation: 2,
                        // 1. ЗМЕНШЕНО ВІДСТУП МІЖ КАРТКАМИ (було vertical: 8)
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showImageCarouselDialog(photos),
                          child: Padding(
                            // 2. ЗМЕНШЕНО ВНУТРІШНІЙ ВІДСТУП ЗВЕРХУ І ЗНИЗУ (було all: 12)
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              children: [
                                // Мініатюра (Прев'ю фотографії)
                                Container(
                                  // 3. ЗМЕНШЕНО РОЗМІР КАРТИНКИ (було 80х80)
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: hasImage
                                        ? Image.memory(
                                            photos.first.imageBytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey.shade400,
                                            // Зменшено розмір іконки-заглушки
                                            size: 28,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Текстова інформація (Назва + Код)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    // Щоб текст займав мінімум місця по висоті
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16, // Трохи зменшено шрифт назви (було 18)
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      // 4. ЗМЕНШЕНО ПРОМІЖОК МІЖ НАЗВОЮ ТА КОДОМ (було 8)
                                      const SizedBox(height: 4),

                                      // Стилізована плашка для коду
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical:
                                              2, // Зменшено відступи у плашці
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Код: ${_formatCode(code)}',
                                          style: TextStyle(
                                            fontSize:
                                                14, // Трохи зменшено шрифт коду
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Іконка переходу
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey.shade400,
                                    size: 32, // Трохи зменшено іконку
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
