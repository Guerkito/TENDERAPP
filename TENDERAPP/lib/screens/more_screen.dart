import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'suppliers_screen.dart';
import 'expenses_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';
import 'alerts_screen.dart';
import 'sales_history_screen.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  void _handleRestore(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Restaurar Datos?'),
          content: const Text('Esto reemplazará todos tus datos actuales con los del archivo seleccionado. Esta acción no se puede deshacer.\n\nLa aplicación se cerrará después de restaurar.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
                content: const Text('Los datos se han restaurado con éxito. Por favor, reinicia la aplicación para ver los cambios.'),
                actions: [
                  ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                ],
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al restaurar: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Más Opciones', style: TextStyle(fontWeight: FontWeight.bold)),
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
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen())),
            ),
            _buildMenuItem(
              context,
              'Calendario de Visitas',
              'Agenda citas con proveedores',
              PhosphorIcons.calendar(PhosphorIconsStyle.regular),
              Colors.blue,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
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
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
            ),
            _buildMenuItem(
              context,
              'Historial de Gastos',
              'Consulta tus egresos pasados',
              PhosphorIcons.receipt(PhosphorIconsStyle.regular),
              Colors.redAccent,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen())),
            ),
            _buildMenuItem(
              context,
              'Estadísticas Detalladas',
              'Reportes y gráficas de venta',
              PhosphorIcons.chartBar(PhosphorIconsStyle.regular),
              const Color(0xFF00DF82),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen())),
            ),
            _buildMenuItem(
              context,
              'Alertas de Stock',
              'Productos que requieren atención',
              PhosphorIcons.bell(PhosphorIconsStyle.regular),
              Colors.deepOrange,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen())),
            ),
          ]),
          const SizedBox(height: 24),
          _buildMenuSection('Seguridad y Datos', [
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
              'TenderApp v9.5 - Gestión Total',
              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
