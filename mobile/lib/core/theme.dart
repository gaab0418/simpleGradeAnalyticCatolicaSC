/// Identidade visual herdada do boletim web: caderno quadriculado no claro,
/// lousa e giz no escuro.
library;

import 'package:material_ui/material_ui.dart';

import '../domain/regras.dart';

const fonteUi = 'SchibstedGrotesk';
const fonteMao = 'Kalam';

@immutable
class Caderno extends ThemeExtension<Caderno> {
  const Caderno({
    required this.papel,
    required this.folha,
    required this.grade,
    required this.linha,
    required this.tinta,
    required this.lapis,
    required this.canetaVermelha,
    required this.tracoVazio,
    required this.marcaTexto,
  });

  final Color papel;
  final Color folha;
  final Color grade;
  final Color linha;
  final Color tinta;
  final Color lapis;
  final Color canetaVermelha;
  final Color tracoVazio;
  final Map<Tom, Color> marcaTexto;

  static const claro = Caderno(
    papel: Color(0xFFF6F8FB),
    folha: Color(0xFFFFFFFF),
    grade: Color(0xFFE2E9F2),
    linha: Color(0xFFC9D3E1),
    tinta: Color(0xFF1C2B4A),
    lapis: Color(0xFF6E7891),
    canetaVermelha: Color(0xFFC8102E),
    tracoVazio: Color(0xFFD3DCE8),
    marcaTexto: {
      Tom.ok: Color(0xFFBDF0A8),
      Tom.calmo: Color(0xFFBFE6FF),
      Tom.atencao: Color(0xFFFFE66D),
      Tom.apertado: Color(0xFFFFC48C),
      Tom.critico: Color(0xFFFFA3B8),
      Tom.neutro: Color(0xFFE3E7EE),
    },
  );

  static const lousa = Caderno(
    papel: Color(0xFF1D2824),
    folha: Color(0xFF23302B),
    grade: Color(0x09FFFFFF),
    linha: Color(0x24E9EEE8),
    tinta: Color(0xFFE9EEE8),
    lapis: Color(0xFF95A59E),
    canetaVermelha: Color(0xFFFF8F8F),
    tracoVazio: Color(0x21E9EEE8),
    marcaTexto: {
      Tom.ok: Color(0x4D8CE178),
      Tom.calmo: Color(0x4282C8FF),
      Tom.atencao: Color(0x4DFFE15A),
      Tom.apertado: Color(0x52FFAA64),
      Tom.critico: Color(0x57FF7896),
      Tom.neutro: Color(0x1AE9EEE8),
    },
  );

  static Caderno of(BuildContext context) =>
      Theme.of(context).extension<Caderno>()!;

  TextStyle get mao => TextStyle(fontFamily: fonteMao, color: lapis);

  @override
  Caderno copyWith() => this;

  @override
  Caderno lerp(Caderno? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

ThemeData temaDoApp(Brightness brilho) {
  final c = brilho == Brightness.dark ? Caderno.lousa : Caderno.claro;
  final esquema = ColorScheme.fromSeed(seedColor: c.tinta, brightness: brilho)
      .copyWith(
        primary: c.tinta,
        onPrimary: c.papel,
        surface: c.papel,
        onSurface: c.tinta,
        onSurfaceVariant: c.lapis,
        surfaceContainer: c.folha,
        surfaceContainerHigh: c.folha,
        surfaceContainerHighest: c.folha,
        outline: c.lapis,
        outlineVariant: c.linha,
        error: c.canetaVermelha,
        secondaryContainer: c.tinta.withValues(alpha: 0.12),
        onSecondaryContainer: c.tinta,
      );
  final borda = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c.linha),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brilho,
    colorScheme: esquema,
    fontFamily: fonteUi,
    scaffoldBackgroundColor: c.papel,
    extensions: [c],
    dividerTheme: DividerThemeData(color: c.linha, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: c.folha,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.linha),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.folha,
      border: borda,
      enabledBorder: borda,
      focusedBorder: borda.copyWith(
        borderSide: BorderSide(color: c.tinta, width: 2),
      ),
      labelStyle: TextStyle(color: c.lapis),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: fonteUi,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.folha,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.tinta.withValues(alpha: 0.12),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: fonteUi,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.tinta,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.tinta,
      thumbColor: c.tinta,
      inactiveTrackColor: c.tracoVazio,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.tinta,
      contentTextStyle: TextStyle(fontFamily: fonteUi, color: c.papel),
    ),
  );
}
