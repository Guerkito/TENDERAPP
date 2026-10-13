import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_model.dart';
import '../models/customer_movement_model.dart';
import '../providers/customer_provider.dart';
import '../api/currency_formatter.dart';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import 'add_customer_screen.dart';
import 'customer_purchases_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  int _historyVersion = 0;

  void _refreshHistory() => setState(() => _historyVersion++);

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);
    // Find the latest version of the customer to get updated points/balance
    final currentCustomer = customerProvider.customers.firstWhere(
      (c) => c.id == widget.customer.id,
      orElse: () => widget.customer,
    );
    
    return Scaffold(
      appBar: AppBar(
        title: Text(currentCustomer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Ver compras',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CustomerPurchasesScreen(customer: currentCustomer),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCustomerScreen(customer: currentCustomer),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummary(currentCustomer),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<CustomerMovement>>(
              key: ValueKey(_historyVersion),
              future: customerProvider.getCustomerHistory(currentCustomer.id!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return const Center(child: Text('No hay movimientos registrados.'));
                }
                return ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final movement = history[index];
                    return _buildMovementTile(movement);
                  },
                );
              },
            ),
          ),
          _buildActionButtons(context, currentCustomer, _refreshHistory),
        ],
      ),
    );
  }

  Widget _buildSummary(Customer customer) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      color: Colors.white,
      child: Column(
        children: [
          Text(
            CurrencyFormatter.format(customer.totalPendingBalance),
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.redAccent),
          ),
          const Text('SALDO TOTAL PENDIENTE', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSmallInfo('Celular', customer.phone),
              _buildSmallInfo('Cupo', CurrencyFormatter.format(customer.creditLimit)),
              _buildSmallInfo('Puntos', '${customer.points} pts'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMovementTile(CustomerMovement movement) {
    final isCargo = movement.type == MovementType.charge;
    return ListTile(
      onTap: () => _showMovementActions(movement),
      leading: Icon(
        isCargo ? Icons.arrow_upward : Icons.arrow_downward,
        color: isCargo ? Colors.red : Colors.green,
      ),
      title: Text(movement.description),
      subtitle: Text(
        '${movement.dateTime.split('T')[0]}\nToca para corregir o anular',
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
      ),
      isThreeLine: true,
      trailing: Text(
        (isCargo ? '+ ' : '- ') + CurrencyFormatter.format(movement.amount),
        style: TextStyle(
          color: isCargo ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showMovementActions(CustomerMovement movement) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(movement.description,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              '${movement.type} de ${CurrencyFormatter.format(movement.amount)} · ${movement.dateTime.split('T')[0]}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: Color(0xFF143122)),
              title: const Text('Corregir monto'),
              subtitle: const Text('Anula este movimiento y registra el correcto'),
              onTap: () => Navigator.pop(sheetContext, 'correct'),
            ),
            ListTile(
              leading: const Icon(Icons.undo, color: Colors.redAccent),
              title: const Text('Anular movimiento'),
              subtitle:
                  const Text('Crea el movimiento opuesto para cuadrar el saldo'),
              onTap: () => Navigator.pop(sheetContext, 'annul'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (action == 'correct') {
      await _showCorrectionDialog(movement);
    } else if (action == 'annul') {
      await _confirmAnnul(movement);
    }
  }

  Future<void> _showCorrectionDialog(CustomerMovement movement) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final newAmount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Corregir monto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monto actual: ${CurrencyFormatter.format(movement.amount)}\nQuedará anulado en el historial y se registrará el monto correcto.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandSeparatorInputFormatter()],
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Monto correcto', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  hintText: 'Ej: se digito mal el monto'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR')),
          ElevatedButton(
              onPressed: () => Navigator.pop(
                  dialogContext, CurrencyFormatter.parse(amountController.text)),
              child: const Text('CORREGIR')),
        ],
      ),
    );
    if (!mounted || newAmount == null) return;

    if (newAmount <= 0 || newAmount == movement.amount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Escribe un monto distinto y mayor que cero para corregir.')));
      return;
    }

    try {
      await Provider.of<CustomerProvider>(context, listen: false)
          .correctMovement(movement,
              correctedAmount: newAmount, reason: reasonController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saldo corregido. Revisa el historial.')));
      _refreshHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo corregir. Inténtalo de nuevo.')));
    }
  }

  Future<void> _confirmAnnul(CustomerMovement movement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Anular movimiento?'),
        content: Text(
            'Se registrará el movimiento opuesto por ${CurrencyFormatter.format(movement.amount)} y el saldo del cliente quedará cuadrado. La anulación queda visible en el historial.',
            style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ANULAR'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await Provider.of<CustomerProvider>(context, listen: false)
          .correctMovement(movement);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Movimiento anulado. Saldo actualizado.')));
      _refreshHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo anular. Inténtalo de nuevo.')));
    }
  }

  Widget _buildActionButtons(BuildContext context, Customer customer, VoidCallback onAbonoRegistered) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showAbonoDialog(context, customer, onAbonoRegistered),
              icon: const Icon(Icons.payments),
              label: const Text('ABONAR'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
          const SizedBox(width: 10),
          // Redeem Points Button
          IconButton(
            onPressed: () => _showRedeemDialog(context, customer),
            icon: const Icon(Icons.card_giftcard, color: Colors.white),
            tooltip: 'Canjear Puntos',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.forest,
              padding: const EdgeInsets.all(15),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _sendWhatsApp(customer),
            icon: const Icon(Icons.chat, color: Colors.white),
            tooltip: 'Enviar WhatsApp',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.all(15),
            ),
          ),
        ],
      ),
    );
  }

  void _sendWhatsApp(Customer customer) async {
    if (customer.phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Este cliente no tiene celular registrado.')));
      return;
    }
    
    final message = "Hola ${customer.name}, te saludo de la tienda. Te recuerdo que tu saldo pendiente es de ${CurrencyFormatter.format(customer.totalPendingBalance)}. ¡Gracias!";
    final url = "https://wa.me/${customer.phone}?text=${Uri.encodeComponent(message)}";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showRedeemDialog(BuildContext context, Customer customer) {
    final controller = TextEditingController();
    double cashValue = 0;
    const double pointsValueRate = 50.0; // 1 punto = $50 COP (Editable)

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.stars, color: AppColors.forest),
                const SizedBox(width: 10),
                const Text('Canjear Puntos'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Disponibles: ${customer.points} puntos', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Puntos a canjear',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final points = int.tryParse(value) ?? 0;
                    setDialogState(() {
                      cashValue = points * pointsValueRate;
                    });
                  },
                ),
                if (cashValue > 0) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.limeSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VALOR EN DINERO:', style: TextStyle(fontSize: 12, color: AppColors.forest, fontWeight: FontWeight.bold)),
                        Text(CurrencyFormatter.format(cashValue), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forest)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text('* Este valor se descontará de la deuda actual.', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF6B7280))),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
              ElevatedButton(
                onPressed: () async {
                  final points = int.tryParse(controller.text) ?? 0;
                  if (points > 0 && points <= customer.points) {
                    await Provider.of<CustomerProvider>(context, listen: false)
                        .redeemPoints(customer.id!, points, cashValue: cashValue);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('¡Éxito! Se han canjeado $points puntos por ${CurrencyFormatter.format(cashValue)}')),
                      );
                    }
                  } else if (points > customer.points) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No tienes suficientes puntos')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest, foregroundColor: Colors.white),
                child: const Text('CONFIRMAR CANJE'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAbonoDialog(BuildContext context, Customer customer, VoidCallback onRegistered) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Abono'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandSeparatorInputFormatter()],
          decoration: const InputDecoration(labelText: 'Monto del Abono', prefixText: '\$ '),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              final amount = CurrencyFormatter.parse(controller.text);
              if (amount > 0) {
                final movement = CustomerMovement(
                  customerId: customer.id!,
                  dateTime: DateTime.now().toIso8601String(),
                  type: MovementType.payment,
                  amount: amount,
                  description: 'Abono a la deuda',
                );
                await Provider.of<CustomerProvider>(context, listen: false).registerMovement(movement);
                if (context.mounted) {
                  Navigator.pop(context);
                  onRegistered();
                }
              }
            },
            child: const Text('REGISTRAR'),
          ),
        ],
      ),
    );
  }
}
