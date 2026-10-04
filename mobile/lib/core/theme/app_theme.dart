import 'package:flutter/material.dart';

/// Paleta heredada de `AppSerenazgoseguro-legacy`.
///
/// En el legacy estos colores vivian embebidos en cada layout (`#D32F2F`,
/// `#FF9800`, `#2196F3`...) y `colors.xml` solo declaraba tres. Se reunen
/// aca para que la identidad visual se cambie en un solo lugar.
abstract final class Paleta {
  /// Verde institucional: unico color de marca declarado en `colors.xml`.
  static const verde = Color(0xFF4CAF50);
  static const verdeOscuro = Color(0xFF2E7D32);

  /// Rojo de "Reportar Incidencia": la accion mas urgente del menu.
  static const rojo = Color(0xFFD32F2F);

  /// Naranja de "Mapa de Calor".
  static const naranja = Color(0xFFFF9800);

  static const azul = Color(0xFF2196F3);
  static const amarillo = Color(0xFFFFEB3B);
  static const gris = Color(0xFF9E9E9E);
}

/// Colores del legacy con rol semantico.
///
/// Material 3 ya cubre superficie, texto y contenedores, asi que solo se
/// agregan los que la app usa como codigo de operacion (prioridad, tipo de
/// boton). Se expone como [ThemeExtension] para que los colores acompanen a los
/// cambios de tema en vez de quedar escritos en cada widget.
@immutable
class ColoresLegacy extends ThemeExtension<ColoresLegacy> {
  const ColoresLegacy({
    required this.rojo,
    required this.naranja,
    required this.amarillo,
    required this.verde,
    required this.azul,
    required this.gris,
  });

  /// Rojo de accion urgente. Legible sobre superficie clara.
  final Color rojo;

  /// Naranja de advertencia operativa.
  final Color naranja;

  /// Amarillo de atencion. No usar como fondo: falla contraste con texto claro.
  final Color amarillo;

  /// Verde de operacion correcta / unidad disponible.
  final Color verde;

  /// Azul informativo.
  final Color azul;

  /// Gris neutro: estados terminados, Prioridad BAJA, texto secundario.
  final Color gris;

  @override
  ColoresLegacy copyWith({
    Color? rojo,
    Color? naranja,
    Color? amarillo,
    Color? verde,
    Color? azul,
    Color? gris,
  }) =>
      ColoresLegacy(
        rojo: rojo ?? this.rojo,
        naranja: naranja ?? this.naranja,
        amarillo: amarillo ?? this.amarillo,
        verde: verde ?? this.verde,
        azul: azul ?? this.azul,
        gris: gris ?? this.gris,
      );

  @override
  ColoresLegacy lerp(covariant ColoresLegacy? other, double t) {
    if (other == null) return this;
    return ColoresLegacy(
      rojo: Color.lerp(rojo, other.rojo, t)!,
      naranja: Color.lerp(naranja, other.naranja, t)!,
      amarillo: Color.lerp(amarillo, other.amarillo, t)!,
      verde: Color.lerp(verde, other.verde, t)!,
      azul: Color.lerp(azul, other.azul, t)!,
      gris: Color.lerp(gris, other.gris, t)!,
    );
  }
}

/// Tema unico de la app.
///
/// Semilla desde el verde institucional para conservar la identidad del legacy
/// manteniendo contraste accesible en toda la gama, en vez del hexadecimal
/// suelto sobre fondo variable que usaba el legacy.
abstract final class AppTheme {
  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Paleta.verde,
      brightness: brightness,
    );

    final claro = brightness == Brightness.light;
    final legacy = ColoresLegacy(
      rojo: claro ? Paleta.rojo : const Color(0xFFEF5350),
      naranja: claro ? Paleta.naranja : const Color(0xFFFFB74D),
      amarillo: claro ? Paleta.amarillo : const Color(0xFFFFD54F),
      verde: claro ? Paleta.verde : const Color(0xFF81C784),
      azul: claro ? Paleta.azul : const Color(0xFF64B5F6),
      gris: claro ? Paleta.gris : const Color(0xFF9E9E9E),
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: [legacy],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        isDense: true,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);
}

/// Acceso tipado a [ColoresLegacy] desde cualquier widget.
///
/// Evita el `Theme.of(context).extension<ColoresLegacy>()!` repetido y el
/// `!` que viene con el.
extension ColoresLegacyContext on BuildContext {
  ColoresLegacy get legacy => Theme.of(this).extension<ColoresLegacy>()!;
}