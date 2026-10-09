import 'package:flutter/material.dart';

class BusinessTypeInfo {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final List<String> seedCategories;

  const BusinessTypeInfo({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.seedCategories,
  });
}

const List<BusinessTypeInfo> businessTypes = [
  BusinessTypeInfo(
    id: 'liquor',
    label: 'Licorera',
    description: 'Licores, cervezas, vinos y cigarrillos',
    icon: Icons.wine_bar,
    seedCategories: [
      'Cervezas',
      'Vinos',
      'Licores',
      'Ron',
      'Aguardiente',
      'Whisky',
      'Tequila',
      'Vodka',
      'Cigarrillos',
      'Pasabocas',
      'Bebidas',
      'Abarrotes',
    ],
  ),
  BusinessTypeInfo(
    id: 'supermarket',
    label: 'Supermercado',
    description: 'Abarrotes, fruver, aseo y más',
    icon: Icons.shopping_cart,
    seedCategories: [
      'Fruver',
      'Lácteos',
      'Cárnicos',
      'Abarrotes',
      'Aseo',
      'Bebidas',
      'Panadería',
      'Snacks',
      'Enlatados',
    ],
  ),
  BusinessTypeInfo(
    id: 'generic',
    label: 'Otro negocio',
    description: 'Tienda de barrio o surtido general',
    icon: Icons.store,
    seedCategories: [
      'General',
      'Bebidas',
      'Abarrotes',
      'Aseo',
      'Snacks',
    ],
  ),
];

BusinessTypeInfo businessTypeById(String? id) =>
    businessTypes.firstWhere((t) => t.id == id, orElse: () => businessTypes.last);
