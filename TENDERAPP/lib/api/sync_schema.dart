/// Tablas que se comparten entre todos los celulares de una misma cuenta.
///
/// El orden importa: los "padres" van antes que sus "hijos" (productos antes
/// de lotes, ventas antes de sus ítems...), porque la bajada inserta en ese
/// orden.
const List<String> syncedTables = [
  'products',
  'suppliers',
  'customers',
  'expenses',
  'sales',
  'purchases',
  'product_batches',
  'sale_items',
  'sale_payments',
  'customer_movements',
  'loyalty_movements',
  'purchase_items',
  'supplier_appointments',
];

/// Columnas que apuntan a otra tabla: si esa tabla se renumera, la columna se
/// renumera igual para no romper la relación.
const List<(String, String)> syncForeignKeyColumns = [
  ('product_batches', 'product_id'),
  ('sales', 'customer_id'),
  ('sale_items', 'sale_id'),
  ('sale_items', 'product_id'),
  ('sale_payments', 'sale_id'),
  ('customer_movements', 'customer_id'),
  ('customer_movements', 'sale_id'),
  ('purchases', 'supplier_id'),
  ('purchase_items', 'purchase_id'),
  ('purchase_items', 'product_id'),
  ('loyalty_movements', 'customer_id'),
  // No se sincroniza, pero apunta a suppliers: debe renumerarse con ella.
  ('supplier_appointments', 'supplier_id'),
];

/// Cada celular numera sus registros dentro de su propio bloque de ids:
/// `id = bloque * idNamespace + contador`. Con esto los ids de dos celulares
/// nunca chocan y las relaciones siguen siendo números simples.
const int idNamespace = 1000000000000; // 10^12

/// Rango válido de bloques por cuenta (nunca se reutiliza un bloque).
const int maxDeviceIndex = 900;
