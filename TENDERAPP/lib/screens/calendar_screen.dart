import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../providers/supplier_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    Future.microtask(() {
      Provider.of<CalendarProvider>(context, listen: false).loadAppointments();
      Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
    });
  }

  void _showAddAppointmentDialog() {
    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);
    int? selectedSupplierId;
    final notesController = TextEditingController();

    if (supplierProvider.suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agregue proveedores primero')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agendar Proveedor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Seleccionar Proveedor',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: supplierProvider.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
              onChanged: (val) => selectedSupplierId = val,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Notas / Pedido',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (selectedSupplierId != null && _selectedDay != null) {
                    Provider.of<CalendarProvider>(context, listen: false)
                        .addAppointment(selectedSupplierId!, _selectedDay!, notesController.text);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00DF82),
                  foregroundColor: const Color(0xFF1A3C2B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('AGENDAR VISITA', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointments = Provider.of<CalendarProvider>(context).appointments;
    final selectedAppointments = appointments[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Agenda de Proveedores'),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) setState(() => _calendarFormat = format);
              },
              eventLoader: (day) {
                return appointments[DateTime(day.year, day.month, day.day)] ?? [];
              },
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(color: Color(0x3300DF82), shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Color(0xFF00DF82), shape: BoxShape.circle),
                selectedTextStyle: TextStyle(color: Color(0xFF1A3C2B), fontWeight: FontWeight.bold),
                markerDecoration: BoxDecoration(color: Color(0xFF1A3C2B), shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDay == null ? 'Selecciona un día' : DateFormat('EEEE, d MMMM', 'es_ES').format(_selectedDay!),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                ),
                IconButton.filledTonal(
                  onPressed: _showAddAppointmentDialog,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF00DF82).withOpacity(0.2)),
                ),
              ],
            ),
          ),
          Expanded(
            child: selectedAppointments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Sin visitas para este día', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: selectedAppointments.length,
                    itemBuilder: (context, index) {
                      final appt = selectedAppointments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1A3C2B).withOpacity(0.1),
                            child: const Icon(Icons.local_shipping, color: Color(0xFF1A3C2B)),
                          ),
                          title: Text(appt['supplier_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(appt['notes'] ?? 'Sin notas'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => Provider.of<CalendarProvider>(context, listen: false).deleteAppointment(appt['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
