import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class CurrencyFormatter {
  static String format(num value) {
    // Formato estándar para pesos colombianos (COP)
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  static String formatWithDecimals(num value) {
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 2,
    );
    return formatter.format(value);
  }

  /// Convierte un string con formato ("1.000") a un número puro (1000)
  static double parse(String formattedValue) {
    if (formattedValue.isEmpty) return 0;
    // Remueve todo lo que no sea número
    String cleaned = formattedValue.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
}

/// Formateador para campos de texto que agrega separadores de miles en tiempo real
class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Obtener solo los números del nuevo texto
    String cleanedString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleanedString.isEmpty) {
      return newValue.copyWith(text: '');
    }

    try {
      double value = double.parse(cleanedString);
      final formatter = NumberFormat.decimalPattern('es_CO');
      String newText = formatter.format(value);

      return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } catch (e) {
      return oldValue;
    }
  }
}
