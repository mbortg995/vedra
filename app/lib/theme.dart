import 'package:flutter/material.dart';

/// Sistema de diseño de Vedra.
///
/// Pensado para un público de +35 que consulta al aire libre: tipografía grande
/// y de alto contraste, áreas de toque amplias (>= 56 dp en acciones), lenguaje
/// visual tranquilo con el semáforo como protagonista. Respeta el escalado de
/// fuente del sistema (no fija tamaños absolutos en el contenido).
class VedraTheme {
  static const _semilla = Color(0xFF2E7D32);

  // Colores del semáforo (contraste cuidado).
  static const verde = Color(0xFF2E7D32);
  static const amarillo = Color(0xFFF9A825);
  static const rojo = Color(0xFFC62828);

  static Color color(String s) =>
      {'verde': verde, 'amarillo': amarillo, 'rojo': rojo}[s] ?? verde;

  /// Texto/icono sobre el color: el amarillo necesita texto oscuro; verde y rojo, blanco.
  static Color sobreColor(String s) =>
      s == 'amarillo' ? const Color(0xFF1A1A1A) : Colors.white;

  static IconData icono(String s) => {
        'verde': Icons.check_circle_rounded,
        'amarillo': Icons.warning_amber_rounded,
        'rojo': Icons.block_rounded,
      }[s] ?? Icons.help_rounded;

  static ThemeData light() {
    final base = ThemeData(
      colorSchemeSeed: _semilla,
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F9F4),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(centerTitle: false),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
