# Documentación de Cambios — TenderApp v9

Este documento resume las mejoras, correcciones y cambios de diseño implementados en la versión 9 de TenderApp, siguiendo los lineamientos del brief técnico y de diseño.

## 1. Mejoras de UI/UX y Diseño Visual

Se realizó un rediseño general para modernizar la interfaz, basándose en la paleta de colores y referencias visuales proporcionadas.

-   **Paleta de Colores Corporativa**:
    -   `#1A3C2B` (Verde Oscuro) para headers y barras de navegación.
    -   `#00DF82` (Verde Brillante) para botones de acción principal (FABs, Cobrar, etc.) e indicadores de selección.
    -   `#F5F7FA` (Gris Claro) para los fondos de pantalla, generando un contraste limpio.
    -   `#FFFFFF` (Blanco) para las tarjetas de contenido, aportando luminosidad.
-   **Nuevo Dashboard Principal (`HomeScreen`)**:
    -   La pantalla de inicio ahora es un **Dashboard** que muestra las métricas clave del día: **Ventas, Gastos y Utilidad** (calculada como ventas - gastos).
    -   Incluye un **Header Proactivo** de color verde oscuro que saluda al usuario y muestra un banner de alerta si hay productos con stock bajo o próximos a vencer.
-   **Navegación Inferior (Material 3)**:
    -   Se implementó un `NavigationBar` moderno con fondo verde oscuro.
    -   El tab activo se resalta con una "píldora" de color verde brillante, mejorando la visibilidad.
    -   Los íconos ahora son `PhosphorIcons` para un look más estilizado y consistente.
    -   Se reorganizaron los tabs a: **Inicio, Caja (POS), Inventario, Clientes, Más**.
-   **Formateo de Moneda Unificado**:
    -   Todos los campos de entrada de dinero (`TextField`) ahora usan un `ThousandSeparatorInputFormatter` que añade separadores de miles con punto (`.`) y el prefijo `$` mientras el usuario escribe, mejorando la legibilidad. El valor guardado en la base de datos sigue siendo un número limpio.

## 2. Mejoras Funcionales y de Flujo

Se optimizaron los flujos de trabajo más críticos para hacer la aplicación más rápida y eficiente.

-   **Flujo de POS (Punto de Venta) Optimizado**:
    -   El acceso a la **Caja (POS)** es ahora un tab principal en la barra de navegación para acceso inmediato.
    -   Al seleccionar "Fiar (Crédito)", ahora se abre un **BottomSheet** que permite buscar un cliente existente o **crear uno nuevo sin salir de la venta**, evitando la pérdida del carrito.
-   **Flujo de Compras a Proveedor Corregido**:
    -   Se verificó y aseguró la lógica en `PurchaseProvider` para que al registrar una compra **se actualice el stock y el precio de costo de un producto existente** del catálogo, eliminando la creación de productos duplicados.
-   **Sistema de Lotes (FEFO) y Vencimientos**:
    -   La lógica de la aplicación ahora opera sobre la tabla `product_batches`.
    -   Al vender, se descuenta automáticamente el stock del lote más próximo a vencer (**First-Expired, First-Out**), optimizando la gestión de inventario perecedero.
-   **Fidelización de Clientes (Puntos)**:
    -   El sistema de puntos está activo: se suman **1 punto por cada $1.000** en ventas a clientes registrados.
    -   La pantalla de detalle del cliente ahora muestra los puntos acumulados y permite **canjearlos por un descuento** en su deuda.

## 3. Reportes y Exportación

Se expandió la capacidad de análisis de datos del negocio.

-   **Exportación a PDF y Excel**:
    -   Desde la pantalla de **Estadísticas**, ahora se pueden exportar los reportes financieros en dos formatos:
        1.  **PDF**: Un reporte visualmente limpio.
        2.  **Excel (.xlsx)**: Un archivo con hojas separadas para el resumen, el ranking de productos y las ventas diarias.
    -   Se integró la funcionalidad de **compartir** para enviar fácilmente los archivos generados por WhatsApp, correo, etc.

## 4. Correcciones Técnicas

-   **Inicialización de Base de Datos para Desktop**:
    -   Se corrigió el error `Bad state: databaseFactory not initialized` que ocurría al ejecutar la aplicación en plataformas de escritorio (Windows, Linux, macOS). Se añadió la inicialización de `sqflite_common_ffi` en el `main.dart`.
-   **Análisis de Código y Depuración**:
    -   Se corrigieron múltiples errores y advertencias reportados por `flutter analyze`, incluyendo el uso de constructores `const` inválidos con métodos, importaciones no utilizadas y miembros deprecados.
    -   Se limpió el código de `print()` innecesarios para un build de producción más limpio.

---

A continuación, procederé a generar el archivo APK.
