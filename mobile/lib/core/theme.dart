/// Identidade visual. Os valores são os mesmos tokens do site
/// (site/src/app/globals.css): superfícies neutras, um acento e cores de
/// situação que sempre vêm acompanhadas de texto.
library;

import 'package:material_ui/material_ui.dart';

import '../domain/regras.dart';

const fonteUi = 'SchibstedGrotesk';

/// Par texto/fundo de um selo de situação.
typedef CorDeTom = ({Color cor, Color fundo});

@immutable
class Paleta extends ThemeExtension<Paleta> {
  const Paleta({
    required this.fundo,
    required this.superficie,
    required this.superficie2,
    required this.borda,
    required this.bordaForte,
    required this.texto,
    required this.texto2,
    required this.texto3,
    required this.acento,
    required this.sobreAcento,
    required this.tons,
  });

  final Color fundo;
  final Color superficie;
  final Color superficie2;
  final Color borda;
  final Color bordaForte;
  final Color texto;
  final Color texto2;
  final Color texto3;
  final Color acento;
  final Color sobreAcento;
  final Map<Tom, CorDeTom> tons;

  Color get critico => tons[Tom.critico]!.cor;

  static const claro = Paleta(
    fundo: Color(0xFFF6F6F3),
    superficie: Color(0xFFFFFFFF),
    superficie2: Color(0xFFF1F1ED),
    borda: Color(0xFFE2E2DC),
    bordaForte: Color(0xFFC9C9C1),
    texto: Color(0xFF1A1A1E),
    texto2: Color(0xFF5C5C66),
    texto3: Color(0xFF85858F),
    acento: Color(0xFF1D4ED8),
    sobreAcento: Color(0xFFFFFFFF),
    tons: {
      Tom.ok: (cor: Color(0xFF17753F), fundo: Color(0xFFE3F4E9)),
      Tom.calmo: (cor: Color(0xFF1F5FAE), fundo: Color(0xFFE4EEFB)),
      Tom.atencao: (cor: Color(0xFF8A5A00), fundo: Color(0xFFFBF0D0)),
      Tom.apertado: (cor: Color(0xFFB0460B), fundo: Color(0xFFFDE8D8)),
      Tom.critico: (cor: Color(0xFFB3261E), fundo: Color(0xFFFBE4E2)),
      Tom.neutro: (cor: Color(0xFF5C5C66), fundo: Color(0xFFECECE7)),
    },
  );

  static const escuro = Paleta(
    fundo: Color(0xFF111214),
    superficie: Color(0xFF191A1D),
    superficie2: Color(0xFF222327),
    borda: Color(0xFF2C2D32),
    bordaForte: Color(0xFF44464D),
    texto: Color(0xFFEDEDF0),
    texto2: Color(0xFFA5A5B0),
    texto3: Color(0xFF7D7D88),
    acento: Color(0xFF8AB0FF),
    sobreAcento: Color(0xFF0B1020),
    tons: {
      Tom.ok: (cor: Color(0xFF6FD69A), fundo: Color(0xFF16301F)),
      Tom.calmo: (cor: Color(0xFF8FBCF5), fundo: Color(0xFF16273D)),
      Tom.atencao: (cor: Color(0xFFE8BF5A), fundo: Color(0xFF33290F)),
      Tom.apertado: (cor: Color(0xFFF39A62), fundo: Color(0xFF3A2114)),
      Tom.critico: (cor: Color(0xFFF58A82), fundo: Color(0xFF3D1A18)),
      Tom.neutro: (cor: Color(0xFFA5A5B0), fundo: Color(0xFF26272B)),
    },
  );

  static Paleta of(BuildContext context) =>
      Theme.of(context).extension<Paleta>()!;

  @override
  Paleta copyWith() => this;

  @override
  Paleta lerp(Paleta? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

ThemeData temaDoApp(Brightness brilho) {
  final c = brilho == Brightness.dark ? Paleta.escuro : Paleta.claro;
  final esquema = ColorScheme.fromSeed(seedColor: c.acento, brightness: brilho)
      .copyWith(
        primary: c.acento,
        onPrimary: c.sobreAcento,
        surface: c.fundo,
        onSurface: c.texto,
        onSurfaceVariant: c.texto2,
        surfaceContainerLow: c.superficie,
        surfaceContainer: c.superficie,
        surfaceContainerHigh: c.superficie,
        surfaceContainerHighest: c.superficie2,
        outline: c.bordaForte,
        outlineVariant: c.borda,
        error: c.critico,
        secondaryContainer: c.superficie2,
        onSecondaryContainer: c.texto,
      );
  final borda = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: c.bordaForte),
  );
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  const rotulo = TextStyle(
    fontFamily: fonteUi,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brilho,
    colorScheme: esquema,
    fontFamily: fonteUi,
    scaffoldBackgroundColor: c.fundo,
    extensions: [c],
    dividerTheme: DividerThemeData(color: c.borda, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: c.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borda),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.superficie,
      border: borda,
      enabledBorder: borda,
      focusedBorder: borda.copyWith(
        borderSide: BorderSide(color: c.acento, width: 2),
      ),
      labelStyle: TextStyle(color: c.texto2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: forma,
        textStyle: rotulo,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: c.texto,
        side: BorderSide(color: c.bordaForte),
        shape: forma,
        textStyle: rotulo.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: forma, textStyle: rotulo),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.superficie2,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: fonteUi,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.texto,
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.acento,
      thumbColor: c.acento,
      inactiveTrackColor: c.borda,
      trackHeight: 4,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.texto,
      contentTextStyle: TextStyle(fontFamily: fonteUi, color: c.fundo),
    ),
  );
}
