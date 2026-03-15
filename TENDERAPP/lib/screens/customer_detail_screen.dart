import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_model.dart';
import '../models/customer_movement_model.dart';
import '../providers/customer_provider.dart';
import '../api/currency_formatter.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
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
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navegar a editar cliente si se desea
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
          _buildActionButtons(context, currentCustomer),
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
          const Text('SALDO TOTAL PENDIENTE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
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
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMovementTile(CustomerMovement movement) {
    final isCargo = movement.type == 'Cargo';
    return ListTile(
      leading: Icon(
        isCargo ? Icons.arrow_upward : Icons.arrow_downward,
        color: isCargo ? Colors.red : Colors.green,
      ),
      title: Text(movement.description),
      subtitle: Text(movement.dateTime.split('T')[0]),
      trailing: Text(
        (isCargo ? '+ ' : '- ') + CurrencyFormatter.format(movement.amount),
        style: TextStyle(
          color: isCargo ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Customer customer) {
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
              onPressed: () => _showAbonoDialog(context, customer),
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
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.all(15),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _sendWhatsApp(customer),
            icon: const Icon(Icons.chat, color: Colors.white),
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
    if (customer.phone.isEmpty) return;
    
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
                const Icon(Icons.stars, color: Colors.purple),
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
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VALOR EN DINERO:', style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold)),
                        Text(CurrencyFormatter.format(cashValue), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.purple)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text('* Este valor se descontará de la deuda actual.', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                child: const Text('CONFIRMAR CANJE'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAbonoDialog(BuildContext context, Customer customer) {
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
                  type: 'Abono',
                  amount: amount,
                  description: 'Abono a la deuda',
                );
                await Provider.of<CustomerProvider>(context, listen: false).registerMovement(movement);
                if (mounted) {
                  Navigator.pop(context);
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
