import 'package:flutter_test/flutter_test.dart';
import 'package:vedra/main.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla del semáforo', (tester) async {
    await tester.pumpWidget(const VedraApp());
    expect(find.text('Vedra'), findsOneWidget);
    expect(find.text('¿Puedo hacerlo aquí hoy?'), findsOneWidget);
    expect(find.text('Consultar'), findsOneWidget);
  });
}
