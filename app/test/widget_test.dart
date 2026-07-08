import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vedra/main.dart';
import 'package:vedra/servicio_auth.dart';

void main() {
  test('ServicioAuth sin inicializar se comporta como sin sesión', () {
    // En los tests Supabase no se inicializa; el servicio no debe reventar.
    expect(ServicioAuth.inicializado, isFalse);
    final auth = ServicioAuth();
    expect(auth.haySesion, isFalse);
    expect(auth.correo, isNull);
  });

  testWidgets('Sin sesión, Licencias invita a iniciar sesión', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completo': true});
    await tester.pumpWidget(const VedraApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Licencias'));
    await tester.pumpAndSettle();

    expect(find.text('Guarda tus licencias'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

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
