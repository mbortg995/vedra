import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedra/main.dart';
import 'package:vedra/semaforo.dart';

void main() {
  testWidgets('TarjetaSemaforo renderiza con datos de ejemplo', (tester) async {
    final r = Resultado()
      ..semaforo = 'verde'
      ..titulo = 'Adelante — cumples todo'
      ..territorios = ['Comunitat Valenciana', 'Zona 6 Previfoc']
      ..condicionNivel = '1'
      ..condicionFresca = true
      ..avisos = [
        const Item('Máximo 4 ejemplares por día.', Fuente('GVA', 'https://ejemplo.es'))
      ];
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: TarjetaSemaforo(res: r))));
    await tester.pump();
    expect(find.text('Adelante — cumples todo'), findsOneWidget);
    expect(find.textContaining('Máximo 4'), findsOneWidget);
  });
}
