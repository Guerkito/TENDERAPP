import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../providers/supplier_provider.dart';
import '../api/currency_formatter.dart';
import '../widgets/info_banner.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  List<Product> _getEventsForDay(DateTime day, List<Product> allProducts) {
    return allProducts.where((product) {
      if (product.expirationDate == null) return false;
      try {
        final expiryDate = DateTime.parse(product.expirationDate!);
        return isSameDay(expiryDate, day);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final selectedEvents = _getEventsForDay(_selectedDay!, productProvider.products);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario de Negocio'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Banner Guía
              if (_showTutorial)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: InfoBanner(
                    text: 'Mantente al día con los vencimientos de productos y visitas de proveedores marcadas en el calendario.',
                    icon: Icons.calendar_month,
                    color: Colors.indigo,
                    onClose: () => setState(() => _showTutorial = false),
                  ),
                ),
              
              // Calendario
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: TableCalendar(
                  locale: 'es_ES', 
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(color: const Color(0xFF00DF82).withOpacity(0.3), shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(color: Color(0xFF00DF82), shape: BoxShape.circle),
                    markerDecoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  ),
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: _onDaySelected,
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() => _calendarFormat = format);
                    }
                  },
                  onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                  eventLoader: (day) => _getEventsForDay(day, productProvider.products),
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Icon(Icons.event_note, color: Colors.grey, size: 18),
                    const SizedBox(width: 8),
                    Text('VENCIMIENTOS Y NOTAS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Lista de Eventos (Vencimientos)
              selectedEvents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No hay vencimientos para este día', style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: selectedEvents.length,
                      itemBuilder: (context, index) {
                        final product = selectedEvents[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFEBEE),
                              child: Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                            ),
                            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Stock: ${product.stock} ${product.unit ?? ""}'),
                            trailing: Text(
                              CurrencyFormatter.format(product.salePrice),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
