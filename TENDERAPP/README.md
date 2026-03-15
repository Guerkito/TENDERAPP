# TenderApp 🏪

**TenderApp** es una solución integral de gestión para pequeños negocios y tiendas de barrio, diseñada para funcionar de manera fluida en múltiples plataformas (Android, iOS, Windows y Linux). Enfocada en la simplicidad y la eficiencia, permite a los tenderos llevar un control profesional de su inventario, ventas, deudas de clientes y finanzas generales.

## ✨ Características Principales

- 📦 **Gestión de Inventario:** Control de stock, precios de costo/venta, alertas de caducidad y escaneo de códigos de barras.
- 💰 **Punto de Venta (POS):** Realiza ventas rápidas, gestiona métodos de pago y genera recibos en PDF.
- 👥 **Clientes y Crédito:** Directorio de clientes con seguimiento de saldos pendientes ("fiados"), límites de crédito y abonos.
- 🚛 **Proveedores y Compras:** Registro de facturas de compra para actualización automática de stock y costos.
- 📊 **Estadísticas Avanzadas:** Visualización de ventas, utilidad bruta y neta, gastos operativos y productos más rentables.
- 🗓️ **Calendario de Eventos:** Seguimiento de visitas de proveedores y vencimientos de productos.

## 🚀 Guía de Inicio Rápido

### Requisitos Previos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión >= 3.0.0)
- Dart SDK (versión >= 3.0.0 < 4.0.0)

### Instalación

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/tu-usuario/TenderApp.git
   cd TenderApp/TENDERAPP
   ```

2. **Instalar dependencias:**
   ```bash
   flutter pub get
   ```

3. **Ejecutar la aplicación:**
   ```bash
   # Para Android/iOS/Desktop
   flutter run
   ```

## 🛠️ Stack Tecnológico

- **Framework:** [Flutter](https://flutter.dev)
- **Base de Datos:** SQLite via `sqflite` (con soporte FFI para Desktop).
- **Gestión de Estado:** `Provider`.
- **Gráficos:** `fl_chart`.
- **Iconos:** `phosphor_flutter`.
- **Reportes:** `pdf` y `printing`.

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo `LICENSE` para más detalles.
