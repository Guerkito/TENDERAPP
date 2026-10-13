import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// Tipo de cliente para una venta: suma puntos o no.
enum CustomerType { registered, walkIn }

/// Paso rápido del cobro: ¿esta venta suma puntos?
class CustomerTypeSheet extends StatelessWidget {
  final void Function(CustomerType type) onSelect;

  const CustomerTypeSheet({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('¿Esta venta suma puntos?',
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          const Text('Elige cómo registrar al cliente',
              style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
          const SizedBox(height: 18),
          _option(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Cliente registrado',
            subtitle: 'Suma puntos y sellos en su tarjeta digital',
            primary: true,
            onTap: () => onSelect(CustomerType.registered),
          ),
          const SizedBox(height: 12),
          _option(
            context,
            icon: Icons.directions_walk,
            title: 'Cliente ocasional',
            subtitle: 'Venta rápida, no suma puntos',
            primary: false,
            onTap: () => onSelect(CustomerType.walkIn),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR',
                style: TextStyle(
                    color: AppColors.muted, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primary ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: primary
              ? null
              : Border.all(color: const Color(0xFFDCE2E8), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary
                    ? AppColors.lime
                    : AppColors.limeSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: AppColors.ink, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: primary ? Colors.white : AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: primary ? Colors.white70 : AppColors.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: primary ? AppColors.lime : AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Muestra el paso de tipo de cliente. Devuelve null si se cancela el cobro.
Future<CustomerType?> showCustomerTypeSheet(BuildContext context) {
  return showModalBottomSheet<CustomerType>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => CustomerTypeSheet(
      onSelect: (type) => Navigator.pop(sheetContext, type),
    ),
  );
}
