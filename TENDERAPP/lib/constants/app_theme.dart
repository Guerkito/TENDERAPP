import 'package:flutter/material.dart';

/// Sistema de diseño de TenderApp.
/// Personalidad: verde lima eléctrico + verde profundo + crema, tipografía
/// display muy gruesa, tarjetas gordas y pills. Todo lo nuevo debería usar
/// estos tokens en lugar de hex sueltos.
class AppColors {
  /// Verde lima de marca: rellenos, botones, selección. Nunca como texto
  /// sobre fondos claros.
  static const Color lime = Color(0xFFC6F24E);

  /// Lima suave sólido: fondos de íconos y chips sobre superficies claras
  /// (los tintes translúcidos se pierden sobre el crema).
  static const Color limeSoft = Color(0xFFE7F7BE);

  /// Verde profundo: cabeceras, tarjetas destacadas, texto sobre lima.
  static const Color forest = Color(0xFF143122);

  /// Tinta para títulos y texto principal.
  static const Color ink = Color(0xFF0F1D14);

  /// Fondo general crema con tinte verde.
  static const Color cream = Color(0xFFF3F7EA);

  /// Texto secundario (contraste AA sobre blanco).
  static const Color muted = Color(0xFF5F6B63);

  /// Error / dinero que sale.
  static const Color danger = Color(0xFFFF3B30);
}

/// Estilos tipográficos. Nunito para todo; Archivo Black solo para piezas
/// display (saludos, cifras grandes, títulos de héroe).
class AppText {
  static const TextStyle display = TextStyle(
    fontFamily: 'Anton',
    color: AppColors.ink,
    letterSpacing: -0.5,
    height: 1.05,
  );

  static const TextStyle displayOnDark = TextStyle(
    fontFamily: 'Anton',
    color: Colors.white,
    letterSpacing: -0.5,
    height: 1.05,
  );

  static const TextStyle title = TextStyle(
    fontWeight: FontWeight.w900,
    color: AppColors.ink,
    letterSpacing: -0.4,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.ink,
    fontWeight: FontWeight.w600,
  );
}

/// Radios estándar del sistema.
class AppRadius {
  static const double pill = 999;
  static const double card = 24;
  static const double big = 28;
}
