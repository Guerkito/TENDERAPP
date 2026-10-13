import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../constants/business_types.dart';
import '../widgets/business_type_picker.dart';
import '../api/supabase_service.dart';
import 'import_products_screen.dart';
import 'loyalty_screen.dart';
import 'receipt_review_screen.dart';
import 'suppliers_screen.dart';
import 'expenses_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';
import 'alerts_screen.dart';
import 'sales_history_screen.dart';
import 'cash_register_screen.dart';
import 'pin_screen.dart';
import 'purchases_screen.dart';
import 'store_profile_screen.dart';
import '../api/backup_service.dart';
import '../constants/app_theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _handleBackup(BuildContext context) async {
    try {
      await BackupService.exportDatabase();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copia de seguridad generada con éxito.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    }
  }

  void _handleRestore(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Restaurar Datos?'),
          content: const Text(
              'Esto reemplazará tus datos actuales con los del archivo seleccionado.\n\nAntes de reemplazar, guardaremos una copia de tus datos actuales por si algo sale mal.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('RESTAURAR AHORA'),
            ),
          ],
        ),
      );
      if (confirm == true && context.mounted) {
        try {
          final summary =
              await BackupService.importDatabase(result.files.single.path!);
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Restauración completada'),
                content: Text(
                    '$summary\n\nCierra y vuelve a abrir la aplicación para ver tus datos restaurados.'),
                actions: [
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK')),
                ],
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            final message = e is BackupException
                ? e.message
                : 'No se pudo restaurar la copia. Tus datos actuales siguen en su lugar.';
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('No se pudo restaurar'),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ENTENDIDO')),
                ],
              ),
            );
          }
        }
      }
    }
  }

  void _showBusinessTypeDialog(BuildContext context, SettingsProvider settings) {
    String selected = settings.businessType;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Tipo de Negocio',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: BusinessTypePicker(
              selectedId: selected,
              onSelected: (id) => setDialogState(() => selected = id),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () async {
                await settings.updateBusinessType(selected);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePinSettings(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (!settings.hasPinEnabled) {
      // Activar PIN
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
      return;
    }

    // Ya tiene PIN: mostrar opciones
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('PIN de Seguridad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.forest),
              title: const Text('Cambiar PIN'),
              onTap: () => Navigator.pop(ctx, 'change'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_open, color: Colors.red),
              title:
                  const Text('Desactivar PIN', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (action == 'change') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
    } else if (action == 'remove') {
      // Pedir PIN actual antes de eliminar
      final confirmed = await _verifyCurrentPin(context);
      if (confirmed && context.mounted) {
        await settings.removePin();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN desactivado')),
        );
      }
    }
  }

  Future<bool> _verifyCurrentPin(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar PIN actual'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'PIN de 4 dígitos'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, settings.verifyPin(controller.text)),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7EA),
      appBar: AppBar(
        title: const Text('Más Opciones',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildMenuSection('Negocio', [
            _buildMenuItem(
              context,
              'Tipo de Negocio',
              '${businessTypeById(settings.businessType).label} — toca para cambiar',
              Icons.storefront,
              () => _showBusinessTypeDialog(context, settings),
            ),
            _buildMenuItem(
              context,
              'Proveedores',
              'Gestiona tus contactos de compra',
              Icons.local_shipping,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SuppliersScreen())),
            ),
            _buildMenuItem(
              context,
              'Historial de Entradas',
              'Compras a proveedores y costos',
              Icons.shopping_cart_checkout,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PurchasesScreen())),
            ),
            _buildMenuItem(
              context,
              'Calendario de Visitas',
              'Agenda citas con proveedores',
              Icons.calendar_month,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CalendarScreen())),
            ),
            _buildMenuItem(
              context,
              'Importar Productos (Excel)',
              'Carga tu catálogo desde un archivo .xlsx',
              Icons.upload_file,
              () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ImportProductsScreen())),
            ),
          ]),
          const SizedBox(height: 24),
          _buildMenuSection('Fidelización', [
            _buildMenuItem(
              context,
              'Tarjetas de Fidelización',
              'Sellos y premios de tus clientes',
              Icons.card_giftcard,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoyaltyScreen())),
            ),
            _buildMenuItem(
              context,
              'Facturas de Clientes',
              'Aprueba las fotos y suma sellos',
              Icons.fact_check_outlined,
              () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ReceiptReviewScreen())),
            ),
          ]),
          const SizedBox(height: 24),
          _buildMenuSection('Cuenta', [
            _buildMenuItem(
              context,
              'Mi Cuenta',
              SupabaseService.currentEmail ?? 'Conectado',
              Icons.account_circle_outlined,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StoreProfileScreen())),
            ),
          ]),
          const SizedBox(height: 24),
          _buildMenuSection('Análisis y Reportes', [
            _buildMenuItem(
              context,
              'Historial de Ventas',
              'Registro detallado de transacciones',
              Icons.history,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SalesHistoryScreen())),
            ),
            _buildMenuItem(
              context,
              'Historial de Gastos',
              'Consulta tus egresos pasados',
              Icons.receipt_long,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExpensesScreen())),
            ),
            _buildMenuItem(
              context,
              'Estadísticas Detalladas',
              'Reportes y gráficas de venta',
              Icons.bar_chart,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StatisticsScreen())),
            ),
            _buildMenuItem(
              context,
              'Alertas de Stock',
              'Productos que requieren atención',
              Icons.notifications,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen())),
            ),
            _buildMenuItem(
              context,
              'Cierre de Caja',
              'Arqueo y resumen del día',
              Icons.attach_money,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CashRegisterScreen())),
            ),
          ]),
          const SizedBox(height: 24),
          _buildMenuSection('Seguridad y Datos', [
            _buildMenuItem(
              context,
              'PIN de Seguridad',
              settings.hasPinEnabled ? 'Activado — toca para cambiar' : 'Desactivado — toca para activar',
              Icons.lock_outline,
              () => _handlePinSettings(context),
              accent: settings.hasPinEnabled ? Colors.green : Colors.grey,
            ),
            _buildMenuItem(
              context,
              'Copia de Seguridad',
              'Exportar tus datos para respaldo',
              Icons.backup_outlined,
              () => _handleBackup(context),
            ),
            _buildMenuItem(
              context,
              'Restaurar Datos',
              'Importar una copia anterior',
              Icons.settings_backup_restore_rounded,
              () => _handleRestore(context),
              accent: Colors.redAccent,
            ),
          ]),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'TenderApp v10 - Gestión Total',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
                letterSpacing: 1.2),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 15,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, String subtitle,
      IconData icon, VoidCallback onTap, {Color? accent}) {
    // Tratamiento de marca por defecto: icono verde bosque sobre fondo neón
    // suave. `accent` se reserva para estado (PIN) o peligro (Restaurar).
    final tint = accent ?? const Color(0xFFC6F24E);
    final iconColor = accent ?? const Color(0xFF143122);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: accent == null ? AppColors.limeSoft : tint.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title,
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      trailing:
          const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 20),
      onTap: onTap,
    );
  }
}
