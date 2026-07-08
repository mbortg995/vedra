import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vedra/main.dart';

void main() {
  testWidgets('Primer arranque: muestra el onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const VedraApp());
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a Vedra'), findsOneWidget);
    expect(find.text('Saltar'), findsOneWidget);
  });

  testWidgets('Onboarding ya visto: arranca en el semáforo', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completo': true});
    await tester.pumpWidget(const VedraApp());
    await tester.pumpAndSettle();
    expect(find.text('Vedra'), findsOneWidget);
    expect(find.text('¿Puedo hacerlo aquí hoy?'), findsOneWidget);
    expect(find.text('Consultar'), findsOneWidget);
  });
}
