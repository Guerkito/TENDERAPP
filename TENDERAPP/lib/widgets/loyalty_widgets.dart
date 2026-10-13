import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/supabase_service.dart';

/// Sellos de una tarjeta digital: rellenos = ganados, vacíos = faltantes.
class LoyaltyStampRow extends StatelessWidget {
  final int filled;
  final int goal;
  final double size;

  const LoyaltyStampRow({
    super.key,
    required this.filled,
    required this.goal,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (goal <= 0) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(goal, (i) {
        final won = i < filled;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: won ? const Color(0xFFC6F24E) : const Color(0xFFEFF2F5),
            border: Border.all(
              color: won ? const Color(0xFF00B368) : const Color(0xFFDCE2E8),
              width: 1.2,
            ),
          ),
          child: won
              ? Icon(Icons.check,
                  size: size * 0.6, color: const Color(0xFF143122))
              : null,
        );
      }),
    );
  }
}

/// QR de fidelización de la tienda: lo imprimen y lo escanean los clientes.
Future<void> showLoyaltyQrDialog(BuildContext context, String storeId) {
  final url = '${SupabaseService.webAppUrl}?store=$storeId';
  final notConfigured = SupabaseService.webAppUrl.contains('TU-WEBAPP');
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Tu QR de Fidelización'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (notConfigured) ...[
            const Text(
              'El enlace para tus clientes todavía no está activo. Pide al soporte de TenderApp que lo active para poder imprimir el QR.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
          ],
          QrImageView(data: url, size: 200),
          const SizedBox(height: 12),
          Text(url,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'Imprime este QR y ponlo en tu mostrador: tus clientes suben la factura desde el celular y tú la apruebas en la app.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            Navigator.pop(dialogContext);
          },
          child: const Text('COPIAR ENLACE'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('CERRAR'),
        ),
      ],
    ),
  );
}
