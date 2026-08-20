import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import 'suppliers_screen.dart';
import 'expenses_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';
import 'alerts_screen.dart';
import 'sales_history_screen.dart';
import 'cash_register_screen.dart';
import 'pin_screen.dart';
import '../api/backup_service.dart';

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
              'Esto reemplazará todos tus datos actuales con los del archivo seleccionado. Esta acción no se puede deshacer.\n\nLa aplicación se cerrará después de restaurar.'),
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
          await BackupService.importDatabase(result.files.single.path!);
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Restauración Completada'),
                content: const Text(
                    'Los datos se han restaurado con éxito. Por favor, reinicia la aplicación para ver los cambios.'),
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
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Error al restaurar: $e')));
          }
        }
      }
    }
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
              leading: const Icon(Icons.edit, color: Colors.blue),
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
      backgroundColor: const Color(0xFFF5F7FA),
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
              'Proveedores',
              'Gestiona tus contactos de compra',
              PhosphorIcons.truck(PhosphorIconsStyle.regular),
              const Color(0xFF1A3C2B),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SuppliersScreen())),
            ),
            _buildMenuItem(
              context,
              'Calendario de Visitas',
              'Agenda citas con proveedores',
              PhosphorIcons.calendar(PhosphorIconsStyle.regular),
              Colors.blue,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CalendarScreen())),
            ),
          ]),
          const SizedBox(height: 24),
          _buildMenuSection('Análisis y Reportes', [
            _buildMenuItem(
              context,
              'Historial de Ventas',
              'Registro detallado de transacciones',
              PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.regular),
              Colors.orange,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SalesHistoryScreen())),
            ),
            _buildMenuItem(
              context,
              'Historial de Gastos',
              'Consulta tus egresos pasados',
              PhosphorIcons.receipt(PhosphorIconsStyle.regular),
              Colors.redAccent,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ExpensesScreen())),
            ),
            _buildMenuItem(
              context,
              'Estadísticas Detalladas',
              'Reportes y gráficas de venta',
              PhosphorIcons.chartBar(PhosphorIconsStyle.regular),
              const Color(0xFF00DF82),
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StatisticsScreen())),
            ),
            _buildMenuItem(
              context,
              'Alertas de Stock',
              'Productos que requieren atención',
              PhosphorIcons.bell(PhosphorIconsStyle.regular),
              Colors.deepOrange,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen())),
            ),
            _buildMenuItem(
              context,
              'Cierre de Caja',
              'Arqueo y resumen del día',
              PhosphorIcons.currencyDollar(PhosphorIconsStyle.regular),
              const Color(0xFFFF9500),
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
              settings.hasPinEnabled ? Colors.green : Colors.grey,
              () => _handlePinSettings(context),
            ),
            _buildMenuItem(
              context,
              'Copia de Seguridad',
              'Exportar tus datos para respaldo',
              Icons.backup_outlined,
              Colors.blueGrey,
              () => _handleBackup(context),
            ),
            _buildMenuItem(
              context,
              'Restaurar Datos',
              'Importar una copia anterior',
              Icons.settings_backup_restore_rounded,
              Colors.indigo,
              () => _handleRestore(context),
            ),
          ]),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'TenderApp v10 - Gestión Total',
              style: TextStyle(
                  color: Colors.grey,
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
                color: Colors.grey,
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
      IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title,
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 13)),
      trailing:
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
