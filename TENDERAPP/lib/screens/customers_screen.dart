import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../api/currency_formatter.dart';
import '../widgets/info_banner.dart';
import 'customer_detail_screen.dart';
import 'add_customer_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('El Cuaderno (Fiados)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header con "Dinero en la calle"
            _buildHeader(customerProvider.totalDebtInStreet),
            
            // Banner Guía
            if (_showTutorial)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: InfoBanner(
                  text: 'Lleva el control de deudas ("fiados") y abonos. Mira quién tiene puntos acumulados por fidelidad.',
                  icon: Icons.info_outline,
                  color: Colors.amber,
                  onClose: () => setState(() => _showTutorial = false),
                ),
              ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: customerProvider.customers.isEmpty
                    ? const Center(child: Text('No hay clientes registrados.'))
                    : ListView.builder(
                        itemCount: customerProvider.customers.length,
                        itemBuilder: (context, index) {
                          final customer = customerProvider.customers[index];
                          return _buildCustomerCard(customer);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCustomerScreen())),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildHeader(double total) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DINERO EN LA CALLE',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(total),
            style: const TextStyle(color: Color(0xFF00DF82), fontSize: 32, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(dynamic customer) {
    // Semáforo visual
    Color statusColor = Colors.green;
    if (customer.creditLimit > 0) {
      double ratio = customer.totalPendingBalance / customer.creditLimit;
      if (ratio >= 1.0) statusColor = Colors.red;
      else if (ratio > 0.7) statusColor = Colors.orange;
    } else if (customer.totalPendingBalance > 500000) {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: customer))),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.person, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(child: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (customer.points > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${customer.points}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(customer.phone.isEmpty ? 'Sin teléfono' : customer.phone),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(customer.totalPendingBalance),
              style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 16),
            ),
            const Text('pendiente', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
