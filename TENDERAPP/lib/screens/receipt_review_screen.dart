import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api/supabase_service.dart';
import '../constants/app_constants.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../providers/settings_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SupabaseService.isLoggedIn) _load();
    });
  }

  Future<void> _load() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final storeId = await SupabaseService.syncStore(
          settings.storeId, settings.storeName);
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
      final phone = _normalizePhone(sub['customer_phone'] as String?);
      var customer = await _findCustomer(phone);
      customer ??= await _askCreateCustomer(sub);
      if (customer == null) return;
      if (!mounted) return;

      await Provider.of<CustomerProvider>(context, listen: false)
          .addLoyaltyStamp(
        customer.id!,
        note: 'Factura validada (web)',
        source: LoyaltySource.web,
      );
      await SupabaseService.reviewSubmission(sub['id'] as String,
          approved: true);
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
    final url = '${SupabaseService.webAppUrl}?store=${settings.storeId}';
    final notConfigured = SupabaseService.webAppUrl.contains('TU-WEBAPP');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('QR de Fidelización'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (notConfigured) ...[
              const Text(
                'Falta publicar la webapp y poner su URL en supabase_service.dart',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            QrImageView(data: url, size: 200),
            const SizedBox(height: 12),
            Text(url, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Imprime este QR y ponlo en tu mostrador: tus clientes suben la factura desde el celular.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    setState(() => _submissions = []);
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = SupabaseService.isLoggedIn;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Validar Facturas (Web)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          if (loggedIn) ...[
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
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: _logout,
            ),
          ],
        ],
      ),
      body: loggedIn
          ? _buildReviewBody()
          : _LoginPanel(onLoggedIn: _load),
    );
  }

  Widget _buildReviewBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00DF82)));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No se pudo conectar:\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('REINTENTAR')),
            ],
          ),
        ),
      );
    }
    if (_submissions.isEmpty) {
      return const Center(
        child: Text('No hay facturas pendientes por validar.'),
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
                          backgroundColor: const Color(0xFF00DF82),
                          foregroundColor: const Color(0xFF1A3C2B),
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

class _LoginPanel extends StatefulWidget {
  final VoidCallback onLoggedIn;

  const _LoginPanel({required this.onLoggedIn});

  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      widget.onLoggedIn();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.cloud_sync, size: 56, color: Color(0xFF1A3C2B)),
        const SizedBox(height: 12),
        const Text(
          'Conecta tu tienda',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Inicia sesión para recibir las facturas que tus clientes suban desde la webapp de fidelización.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Contraseña',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy
              ? null
              : () => _run(() => SupabaseService.signIn(
                  _emailController.text, _passwordController.text)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00DF82),
            foregroundColor: const Color(0xFF1A3C2B),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('INICIAR SESIÓN',
                  style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    final active = await SupabaseService.signUp(
                        _emailController.text, _passwordController.text);
                    if (!active && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Cuenta creada. Revisa tu correo para confirmarla y luego inicia sesión.')));
                    }
                  }),
          child: const Text('CREAR CUENTA'),
        ),
      ],
    );
  }
}
