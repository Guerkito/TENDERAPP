import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/supabase_service.dart';
import '../constants/business_types.dart';
import '../demo_seed.dart';
import '../models/loyalty.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/loyalty_widgets.dart';
import '../constants/app_theme.dart';

/// Perfil de la tienda: cuenta conectada, QR de fidelización y la base de
/// datos de clientes con sus tarjetas digitales (respaldadas en la nube).
class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  late Future<List<LoyaltyBoardRow>> _future;
  bool _syncing = false;
  bool _loadingDemo = false;
  String? _syncMessage;

  @override
  void initState() {
    super.initState();
    _future = Provider.of<CustomerProvider>(context, listen: false)
        .getLoyaltyBoard();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _syncMessage = null;
    });
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final rows = await Provider.of<CustomerProvider>(context, listen: false)
          .getLoyaltyBoard();
      final storeId =
          await SupabaseService.syncStore(settings.storeId, null);
      if (storeId != settings.storeId) {
        await settings.updateStoreId(storeId);
      }
      final uploaded = await SupabaseService.syncCustomers(
        storeId,
        rows
            .map((row) => {
                  'id': row.customerId,
                  'name': row.name,
                  'phone': row.phone,
                  'stamps_total': row.summary.currentStamps,
                  'rewards_available': row.summary.rewardsAvailable,
                })
            .toList(),
      );

      // Las compras recientes también, para que el cliente las vea en la web.
      final sales = await Provider.of<SaleProvider>(context, listen: false)
          .getRecentSalesWithCustomers();
      final purchases = await SupabaseService.syncPurchases(
        storeId,
        sales
            .map((sale) => {
                  'id': sale['id'],
                  'phone': sale['phone'],
                  'name': sale['name'],
                  'total': sale['total_amount'],
                  'items_count': sale['items_count'],
                  'payment_method': sale['payment_method'],
                  'sold_at': sale['sale_date'],
                })
            .toList(),
      );

      if (!mounted) return;
      setState(() {
        _syncMessage = (uploaded == 0 && purchases == 0)
            ? 'Aún no hay tarjetas ni compras que sincronizar.'
            : 'Listo: $uploaded tarjetas y $purchases compras en la nube.';
      });
    } catch (e) {
      debugPrint('StoreProfile: error al sincronizar: $e');
      if (!mounted) return;
      setState(() {
        _syncMessage =
            'No se pudo sincronizar. Revisa tu conexión e inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _loadDemoData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Datos de demostración'),
        content: const Text(
            'Se cargarán productos, clientes con tarjetas, ventas de 2 semanas, gastos y proveedores de ejemplo.\n\nSolo funciona si el dispositivo está vacío (no pisa datos reales).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('CARGAR')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loadingDemo = true);
    String message;
    try {
      message = await seedDemoData();
      if (message.startsWith('Datos demo')) {
        // Refresca la app con los datos recién cargados.
        final settings =
            Provider.of<SettingsProvider>(context, listen: false);
        await settings.loadSettings();
        await Provider.of<CustomerProvider>(context, listen: false)
            .loadCustomers();
        await Provider.of<ProductProvider>(context, listen: false)
            .loadProducts();
        if (!mounted) return;
        setState(() {
          _future = Provider.of<CustomerProvider>(context, listen: false)
              .getLoyaltyBoard();
        });
      }
    } catch (e) {
      message = 'No se pudieron cargar los datos: $e';
    } finally {
      if (mounted) setState(() => _loadingDemo = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

    // Con datos recién cargados, publica todo (nombre, tarjetas y compras).
    if (message.startsWith('Datos demo')) {
      await _sync();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
            'Tus datos de ventas, clientes y tarjetas siguen guardados en este celular. Cerrar sesión no los borra.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo cerrar sesión. Revisa tu conexión.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7EA),
      appBar: AppBar(
        title: const Text('Mi Tienda'),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<LoyaltyBoardRow>>(
        future: _future,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildStoreHeader(settings),
              const SizedBox(height: 16),
              _buildAccountCard(),
              const SizedBox(height: 28),
              _buildSectionTitle('Tarjetas digitales', rows.length),
              const SizedBox(height: 12),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF143122))),
                )
              else if (rows.isEmpty)
                _buildEmptyCards()
              else
                ...rows.map(_buildCardTile),
              const SizedBox(height: 20),
              _buildSyncCard(settings),
              const SizedBox(height: 28),
              Center(
                child: TextButton.icon(
                  onPressed: _loadingDemo ? null : _loadDemoData,
                  icon: const Icon(Icons.auto_awesome,
                      size: 18, color: Color(0xFF6B7280)),
                  label: const Text(
                    'Cargar datos de demostración',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  'CERRAR SESIÓN',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoreHeader(SettingsProvider settings) {
    final business = businessTypeById(settings.businessType);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF143122),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.jpg',
                fit: BoxFit.cover,
                semanticLabel: 'Logo de la tienda',
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF143122),
                    size: 32),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.storeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  business.label,
                  style: const TextStyle(
                      color: Color(0xFF9BE8C6),
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F24E).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done,
                          color: Color(0xFFC6F24E), size: 14),
                      SizedBox(width: 6),
                      Text('Fidelización activa',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Cambiar nombre',
            onPressed: () => _renameStore(settings),
            icon:
                const Icon(Icons.edit, color: Color(0xFFC6F24E), size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _renameStore(SettingsProvider settings) async {
    final controller = TextEditingController(text: settings.storeName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Nombre del negocio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Licorera Punto de Encuentro',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('GUARDAR')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await settings.updateStoreName(name);
    // Publica el nombre en la nube para que el QR/webapp lo muestre.
    try {
      if (SupabaseService.isLoggedIn) {
        await SupabaseService.syncStore(settings.storeId, name,
            loyaltyGoal: settings.loyaltyGoal,
            loyaltyReward: settings.loyaltyReward);
      }
    } catch (e) {
      debugPrint('StoreProfile: no se pudo publicar el nombre: $e');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre del negocio actualizado.')));
  }

  Widget _buildAccountCard() {
    final email = SupabaseService.currentEmail;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.limeSoft,
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.account_circle, color: Color(0xFF143122)),
        ),
        title: const Text('Cuenta conectada',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        subtitle: Text(
          email ?? 'Sesión activa',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.verified_user,
            color: Color(0xFF143122), size: 22),
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
              letterSpacing: 1.2),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF143122).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count == 1 ? '1 cliente' : '$count clientes',
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF143122)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCards() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.limeSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.style_outlined,
                color: Color(0xFF143122), size: 32),
          ),
          const SizedBox(height: 14),
          const Text('Aún no hay tarjetas digitales',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          const Text(
            'Registra clientes en la pestaña Clientes y aprueba sus facturas: aquí verás sus tarjetas con sellos.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF6B7280), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile(LoyaltyBoardRow row) {
    final summary = row.summary;
    final premios = summary.rewardsAvailable;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF3F7EA),
                child: Text(
                  row.name.isNotEmpty ? row.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF143122)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      'Tarjeta digital · ${summary.currentStamps} de ${summary.goal} sellos',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (premios > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.limeSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    premios == 1 ? '1 premio' : '$premios premios',
                    style: const TextStyle(
                        color: AppColors.forest,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LoyaltyStampRow(
              filled: summary.currentStamps, goal: summary.goal),
        ],
      ),
    );
  }

  Widget _buildSyncCard(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_outlined,
                    color: Color(0xFF007AFF), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Respalda tus tarjetas y clientes en la nube para no perderlos si cambias de celular.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          if (_syncMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _syncMessage!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _syncMessage!.startsWith('No se pudo')
                    ? Colors.redAccent
                    : const Color(0xFF0B7A4B),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _syncing ? null : _sync,
                  icon: _syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF143122)))
                      : const Icon(Icons.cloud_upload, size: 18),
                  label: Text(_syncing ? 'SINCRONIZANDO...' : 'SINCRONIZAR',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6F24E),
                    foregroundColor: const Color(0xFF143122),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      showLoyaltyQrDialog(context, settings.storeId),
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('VER QR',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF143122),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFC6F24E), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
