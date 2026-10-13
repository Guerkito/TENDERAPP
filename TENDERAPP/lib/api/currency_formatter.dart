import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class CurrencyFormatter {
  static String format(num value) {
    // Pesos colombianos: el símbolo va antes, con separador de miles.
    final nf = NumberFormat('#,##0', 'es_CO');
    final sign = value < 0 ? '-' : '';
    return '$sign\$ ${nf.format(value.abs())}';
  }

  static String formatWithDecimals(num value) {
    final nf = NumberFormat('#,##0.00', 'es_CO');
    final sign = value < 0 ? '-' : '';
    return '$sign\$ ${nf.format(value.abs())}';
  }

  /// Cantidades: enteras sin decimales ("18"), fraccionarias tal cual ("0,5 kg").
  static String quantity(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }

  /// Convierte un string con formato ("1.200.000") a un número puro (1200000)
  static double parse(String formattedValue) {
    if (formattedValue.isEmpty) return 0;
    // Remueve todo lo que no sea número (mantiene el punto si fuera decimal, pero aquí es separador de miles)
    // En es_CO el punto es miles y la coma es decimal.
    // Si la app solo maneja enteros para dinero (común en COP), removemos todo excepto dígitos.
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
