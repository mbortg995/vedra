import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vedra/main.dart';
import 'package:vedra/pantalla_onboarding.dart';

/// Verifica las guías de accesibilidad de Flutter (issue #14): contraste AA del
/// texto y que todo lo tocable tenga etiqueta para lectores de pantalla.
void main() {
  testWidgets('La pantalla de consulta cumple contraste y etiquetas', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completo': true});
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const VedraApp());
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets('El onboarding cumple contraste y etiquetas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: PantallaOnboarding(onListo: () {})),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets('Escala de fuente grande no rompe el layout', (tester) async {
    // Pantalla de móvil y una escala de fuente enorme: el clamp de la app la
    // acota, y como todo desplaza, no debe haber overflow.
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // Primero el onboarding (primer arranque)...
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const VedraApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // ...y luego la pantalla de consulta (onboarding ya visto).
    SharedPreferences.setMockInitialValues({'onboarding_completo': true});
    await tester.pumpWidget(const VedraApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
