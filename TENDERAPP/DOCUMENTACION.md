# Documentación Técnica de TenderApp 📚

## 📋 Estado Actual del Proyecto

TenderApp ha evolucionado desde una app básica de inventario a un sistema de gestión empresarial (ERP) ligero para microempresas.

### 🛠️ Funcionalidades Implementadas (Core)

1. **Gestión de Inventario y Productos**
   - Control de stock con precios de compra/venta diferenciados.
   - Seguimiento de fechas de caducidad.
   - Escaneo de códigos de barras (Cámara).
   - Soporte para unidades de medida (Kg, Unidades, Litros, etc.).

2. **Punto de Venta (POS) y Ventas**
   - Carrito de ventas con selección rápida de productos.
   - Soporte para múltiples métodos de pago (Efectivo, Tarjeta, Crédito).
   - Generación de tickets/recibos en PDF para compartir por WhatsApp o imprimir.
   - Historial de ventas detallado por día, mes y año.

3. **Gestión de Clientes y Crédito ("Fiados")**
   - Directorio de clientes con saldos automáticos.
   - Historial de movimientos: Registro de deudas generadas por ventas a crédito y abonos realizados.
   - Límites de crédito configurables.
   - **Sistema de Puntos:** Preparado en base de datos para fidelización (Versión 8).

4. **Gestión Financiera (Gastos y Compras)**
   - **Módulo de Compras:** Registro de entradas de productos a través de facturas de proveedores.
   - **Módulo de Gastos:** Control de egresos operativos (Alquiler, Luz, Internet).
   - **Análisis de Utilidad:** Cálculo automático de:
     - `Utilidad Bruta = Ventas - Costo de Productos Vendidos`.
     - `Utilidad Neta = Utilidad Bruta - Gastos Operativos`.

5. **Reportes y Estadísticas**
   - Gráficos interactivos de ventas mensuales.
   - Identificación del producto más vendido y el más rentable.
   - Valorización del inventario actual a precio de venta.

---

## 🗄️ Esquema de Base de Datos (SQLite)

La base de datos actual (v8) consta de las siguientes tablas principales:

- `products`: Almacena el catálogo de productos y su stock.
- `sales`: Registro de transacciones de venta.
- `sale_items`: Detalle de productos vendidos en cada transacción.
- `customers`: Directorio de clientes con saldos y puntos.
- `customer_movements`: Diario de deudas y abonos de clientes.
- `suppliers`: Registro de proveedores.
- `expenses`: Registro de gastos operativos.
- `purchases`: Cabecera de facturas de compra a proveedores.
- `purchase_items`: Detalle de productos ingresados en cada compra.

---

## 🚀 Hoja de Ruta Actualizada (Roadmap)

### 🎯 Prioridad Alta (Próximos Pasos)
1. **Exportación de Reportes:** Implementar la capacidad de exportar reportes detallados (Ventas, Inventario, Gastos) a formatos PDF o Excel para contabilidad externa.
2. **Mejora de UX en Entradas Numéricas:** Añadir formateo automático con separadores de miles (puntos) mientras el usuario digita montos en los campos de texto.
3. **Gestión Multilote/Multivencimiento:** Modificar el esquema de inventario para permitir que un mismo producto tenga múltiples fechas de vencimiento (lotes distintos) con sus respectivos stocks independientes.
4. **Refactorización del Módulo de Proveedores:** Clarificar el flujo de entrada de mercancía; asegurar que al agregar una compra de proveedor, se vincule directamente al catálogo de productos existente y no se creen duplicados innecesarios.
5. **Fidelización Activa:** Implementar la UI para ver y canjear los puntos de clientes (ya habilitado en DB).
6. **Alertas Proactivas:**
   - Notificaciones push/internas de stock bajo.
   - Avisos automáticos de productos próximos a vencer (30 días).

### 🌟 Futuro y Escalamiento
1. **Sincronización Cloud:** Implementar Firebase o Supabase para respaldo en la nube y acceso desde múltiples dispositivos.
2. **Dashboard Web:** Panel de administración avanzado para PC.
3. **Modo Offline con Sincronización:** Asegurar que la app funcione 100% sin internet y sincronice datos al reconectar.

---

## 🏗️ Arquitectura de Software

- **Patrón:** Provider para la gestión de estados.
- **Inyección de Dependencias:** Uso de `MultiProvider` en la raíz de la aplicación.
- **Persistencia:** `sqflite` con inicialización robusta para múltiples plataformas (Android, Desktop).
- **Servicios API:** Centralizados en `lib/api/` para lógica de base de datos y utilidades externas.
