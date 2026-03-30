import 'package:flutter/material.dart';
import '../api/db_helper.dart';

class CalendarProvider with ChangeNotifier {
  Map<DateTime, List<Map<String, dynamic>>> _appointments = {};

  Map<DateTime, List<Map<String, dynamic>>> get appointments => _appointments;

  Future<void> loadAppointments() async {
    final db = await DBHelper().database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT a.*, s.name as supplier_name 
      FROM supplier_appointments a
      JOIN suppliers s ON a.supplier_id = s.id
      ORDER BY a.appointment_date ASC
    ''');

    _appointments = {};
    for (var map in maps) {
      DateTime date = DateTime.parse(map['appointment_date']);
      // Normalizar a fecha sin hora para el mapa del calendario
      DateTime key = DateTime(date.year, date.month, date.day);
      if (_appointments[key] == null) _appointments[key] = [];
      _appointments[key]!.add(map);
    }
    notifyListeners();
  }

  Future<void> addAppointment(int supplierId, DateTime date, String notes) async {
    final db = await DBHelper().database;
    await db.insert('supplier_appointments', {
      'supplier_id': supplierId,
      'appointment_date': date.toIso8601String(),
      'notes': notes,
    });
    await loadAppointments();
  }

  Future<void> deleteAppointment(int id) async {
    final db = await DBHelper().database;
    await db.delete('supplier_appointments', where: 'id = ?', whereArgs: [id]);
    await loadAppointments();
  }
}
