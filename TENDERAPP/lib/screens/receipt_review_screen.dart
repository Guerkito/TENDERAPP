import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api/supabase_service.dart';
import '../constants/app_constants.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/loyalty_widgets.dart';
import '../constants/app_theme.dart';

class ReceiptReviewScreen extends StatefulWidget {
  const ReceiptReviewScreen({super.key});

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _submissions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final storeId =
          await SupabaseService.syncStore(settings.storeId, null);
      if (storeId != settings.storeId) {
        await settings.updateStoreId(storeId);
      }
      final rows = await SupabaseService.fetchPendingSubmissions(storeId);
      if (!mounted) return;
      setState(() {
        _submissions = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _normalizePhone(String? raw) {
    if (raw == null) return '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  Future<Customer?> _findCustomer(String phone) async {
    final provider = Provider.of<CustomerProvider>(context, listen: false);
    await provider.loadCustomers();
    for (final customer in provider.customers) {
      if (_normalizePhone(customer.phone) == phone && phone.isNotEmpty) {
        return customer;
      }
    }
    return null;
  }

  Future<Customer?> _askCreateCustomer(Map<String, dynamic> sub) async {
    final phone = _normalizePhone(sub['customer_phone'] as String?);
    final nameController =
        TextEditingController(text: sub['customer_name'] as String? ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cliente no registrado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('El teléfono $phone no está en tu lista de clientes.'),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre del cliente'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('CREAR Y APROBAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    if (!mounted) return null;
    final name = nameController.text.trim().isEmpty
        ? 'Cliente $phone'
        : nameController.text.trim();
    final provider = Provider.of<CustomerProvider>(context, listen: false);
    final id = await provider.addCustomer(
      Customer(name: name, phone: phone),
    );
    return Customer(id: id, name: name, phone: phone);
  }

  Future<void> _approve(Map<String, dynamic> sub) async {
    try {
      final customerProvider =
          Provider.of<CustomerProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final phone = _normalizePhone(sub['customer_phone'] as String?);
      var customer = await _findCustomer(phone);
      customer ??= await _askCreateCustomer(sub);
      if (customer == null) return;
      if (!mounted) return;

      await customerProvider.addLoyaltyStamp(
        customer.id!,
        note: 'Factura validada (web)',
        source: LoyaltySource.web,
      );
      await SupabaseService.reviewSubmission(sub['id'] as String,
          approved: true);

      // Publica la tarjeta actualizada para que el cliente la vea en la web.
      try {
        final summary = await customerProvider.getLoyaltySummary(customer.id!);
        await SupabaseService.syncCustomers(settings.storeId, [
          {
            'id': customer.id,
            'name': customer.name,
            'phone': customer.phone,
            'stamps_total': summary.currentStamps,
            'rewards_available': summary.rewardsAvailable,
          }
        ]);
      } catch (e) {
        debugPrint('ReceiptReview: no se pudo publicar la tarjeta: $e');
      }

      if (!mounted) return;
      setState(() => _submissions.remove(sub));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sello agregado a ${customer.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aprobar: $e')),
      );
    }
  }

  Future<void> _reject(Map<String, dynamic> sub) async {
    try {
      await SupabaseService.reviewSubmission(sub['id'] as String,
          approved: false);
      if (!mounted) return;
      setState(() => _submissions.remove(sub));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura rechazada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar: $e')),
      );
    }
  }

  void _showQrDialog() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    showLoyaltyQrDialog(context, settings.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7EA),
      appBar: AppBar(
        title: const Text('Facturas de Clientes',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'QR para clientes',
            onPressed: _showQrDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _load,
          ),
        ],
      ),
      body: _buildReviewBody(),
    );
  }

  Widget _buildReviewBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF143122)));
    }
    if (_error != null) {
      debugPrint('ReceiptReview: error al cargar: $_error');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Color(0xFF6B7280)),
              const SizedBox(height: 16),
              const Text('No pudimos conectar con el servidor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'Revisa tu conexión a internet e inténtalo de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('REINTENTAR',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC6F24E),
                  foregroundColor: const Color(0xFF143122),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_submissions.isEmpty) {
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
                child: const Icon(Icons.inbox_outlined,
                    color: Color(0xFF143122), size: 36),
              ),
              const SizedBox(height: 16),
              const Text('No hay facturas pendientes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'Cuando un cliente suba la foto de su factura desde tu QR, aparecerá aquí para que la apruebes y le sumes su sello.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _showQrDialog,
                icon: const Icon(Icons.qr_code_2, size: 20),
                label: const Text('MOSTRAR MI QR',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF143122),
                  side: const BorderSide(
                      color: Color(0xFFC6F24E), width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _submissions.length,
        itemBuilder: (context, index) =>
            _buildSubmissionCard(_submissions[index]),
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> sub) {
    final photoUrl = sub['photo_url'] as String?;
    final phone = sub['customer_phone'] as String? ?? '';
    final name = sub['customer_name'] as String?;
    final date = DateTime.tryParse(sub['submitted_at'] as String? ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoUrl != null)
            Image.network(
              photoUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 120,
                child: Center(child: Icon(Icons.broken_image, size: 40)),
              ),
            )
          else
            const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.image_not_supported, size: 40)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.isEmpty ? 'Cliente sin nombre' : name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Tel: $phone',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                if (date != null)
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm')
                        .format(date.toLocal()),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reject(sub),
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        label: const Text('RECHAZAR',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approve(sub),
                        icon: const Icon(Icons.check),
                        label: const Text('APROBAR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC6F24E),
                          foregroundColor: const Color(0xFF143122),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

