import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import 'package:intl/intl.dart';
import '../api/currency_formatter.dart';
import '../api/report_generator.dart';
import '../widgets/info_banner.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<ExpenseProvider>(context, listen: false).loadExpenses());
  }

  void _showAddExpenseDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Otros';
    final List<String> categories = ['Alquiler', 'Servicios', 'Sueldos', 'Mantenimiento', 'Otros'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Gasto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandSeparatorInputFormatter()],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (val) {
                selectedCategory = val!;
              },
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final description = descriptionController.text;
              final amount = CurrencyFormatter.parse(amountController.text);

              if (description.isNotEmpty && amount > 0) {
                final newExpense = ExpenseModel(
                  description: description,
                  amount: amount,
                  date: DateTime.now(),
                  category: selectedCategory,
                );
                Provider.of<ExpenseProvider>(context, listen: false).addExpense(newExpense);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final expenses = expenseProvider.expenses;
    final totalExpenses = expenseProvider.totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Operativos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar Gastos PDF',
            onPressed: () => ReportGenerator.generateExpensesReport(
              expenses,
              storeName: Provider.of<SettingsProvider>(context, listen: false).storeName,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Guía
          if (_showTutorial)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InfoBanner(
                text: 'Registra aquí tus pagos de servicios, arriendo y otros egresos. Esto permite calcular tu ganancia neta real.',
                icon: Icons.money_off,
                color: Colors.red,
                onClose: () => setState(() => _showTutorial = false),
              ),
            ),
          
          // Total Expenses Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Gastos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      CurrencyFormatter.format(totalExpenses),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Expenses List
          Expanded(
            child: expenses.isEmpty
                ? const Center(child: Text('No hay gastos registrados.'))
                : ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (ctx, index) {
                      final expense = expenses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red[100],
                            child: const Icon(Icons.money_off, color: Colors.red),
                          ),
                          title: Text(expense.description),
                          subtitle: Text('${DateFormat('dd/MM/yyyy').format(expense.date)} - ${expense.category}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                CurrencyFormatter.format(expense.amount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  // Confirm deletion
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Eliminar Gasto'),
                                      content: const Text('¿Estás seguro de eliminar este gasto?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                                        TextButton(
                                          onPressed: () {
                                            expenseProvider.deleteExpense(expense.id!);
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
