import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/loyalty.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../providers/settings_provider.dart';
import '../api/supabase_service.dart';
import '../widgets/loyalty_widgets.dart';
import 'customer_purchases_screen.dart';
import '../constants/app_theme.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  late Future<List<LoyaltyBoardRow>> _future;

  @override
  void initState() {
    super.initState();
    _future =
        Provider.of<CustomerProvider>(context, listen: false).getLoyaltyBoard();
  }

  void _refresh() {
    setState(() {
      _future = Provider.of<CustomerProvider>(context, listen: false)
          .getLoyaltyBoard();
    });
  }

  Future<void> _stamp(LoyaltyBoardRow row) async {
    await Provider.of<CustomerProvider>(context, listen: false)
        .addLoyaltyStamp(row.customerId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sello agregado a ${row.name}')),
    );
    _refresh();
  }

  Future<void> _redeem(LoyaltyBoardRow row) async {
    final ok = await Provider.of<CustomerProvider>(context, listen: false)
        .redeemLoyaltyReward(row.customerId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '¡Premio entregado a ${row.name}!'
            : 'No hay premios disponibles'),
      ),
    );
    _refresh();
  }

  void _showConfigDialog() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final goalController =
        TextEditingController(text: settings.loyaltyGoal.toString());
    final rewardController =
        TextEditingController(text: settings.loyaltyReward);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Configurar Fidelización',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Compras necesarias para el premio',
                hintText: 'Ej: 6',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rewardController,
              decoration: const InputDecoration(
                labelText: 'Premio',
                hintText: 'Ej: 1 cerveza gratis',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              final goal = int.tryParse(goalController.text) ?? 6;
              await settings.updateLoyaltyConfig(
                goal: goal < 1 ? 1 : goal,
                reward: rewardController.text.trim().isEmpty
                    ? 'Premio gratis'
                    : rewardController.text.trim(),
              );
              // Publica la regla del premio para que la webapp la muestre.
              try {
                if (SupabaseService.isLoggedIn) {
                  await SupabaseService.syncStore(settings.storeId, null,
                      loyaltyGoal: settings.loyaltyGoal,
                      loyaltyReward: settings.loyaltyReward);
                }
              } catch (e) {
                debugPrint('Loyalty: no se pudo publicar el premio: $e');
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _refresh();
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7EA),
      appBar: AppBar(
        title: const Text('Tarjetas de Fidelización',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configurar premio',
            onPressed: _showConfigDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<LoyaltyBoardRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF143122)));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.limeSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.card_giftcard,
                          color: Color(0xFF143122), size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text('Aún no hay tarjetas',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                      'Registra a tus clientes en la pestaña Clientes y aquí verás sus tarjetas: cada factura aprobada suma un sello.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildRewardBanner(settings),
              const SizedBox(height: 16),
              ...rows.map((row) => _buildCustomerTile(row)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRewardBanner(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF143122),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFC6F24E).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.card_giftcard,
                color: Color(0xFFC6F24E), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premio: ${settings.loyaltyReward}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Junta ${settings.loyaltyGoal} sellos (1 por factura aprobada) y gana el premio',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTile(LoyaltyBoardRow row) {
    final summary = row.summary;
    final progress =
        summary.goal > 0 ? summary.currentStamps / summary.goal : 0.0;
    final premios = summary.rewardsAvailable;
    final premiosTexto =
        premios == 1 ? '1 premio disponible' : '$premios premios disponibles';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        fontWeight: FontWeight.bold, color: Color(0xFF143122)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.currentStamps} de ${summary.goal} sellos'
                        '${premios > 0 ? ' · $premiosTexto' : ''}',
                        style: TextStyle(
                          color: premios > 0
                              ? const Color(0xFF143122)
                              : const Color(0xFF5F6B63),
                          fontSize: 12.5,
                          fontWeight:
                              premios > 0 ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined,
                      color: Color(0xFF143122)),
                  tooltip: 'Ver compras',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerPurchasesScreen(
                        customer: Customer(
                            id: row.customerId,
                            name: row.name,
                            phone: row.phone ?? ''),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (summary.goal <= 12)
              LoyaltyStampRow(
                  filled: summary.currentStamps, goal: summary.goal)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  color: const Color(0xFFC6F24E),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _stamp(row),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Sellar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF143122),
                      side: const BorderSide(
                          color: Color(0xFFC6F24E), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        premios > 0 ? () => _redeem(row) : null,
                    icon: const Icon(Icons.redeem, size: 18),
                    label: const Text('Canjear'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(0xFF143122),
                      foregroundColor: Color(0xFFC6F24E),
                      disabledBackgroundColor: Colors.grey[200],
                      disabledForegroundColor: Colors.grey[500],
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
