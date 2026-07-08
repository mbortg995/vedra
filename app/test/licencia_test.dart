import 'package:flutter_test/flutter_test.dart';
import 'package:vedra/licencia.dart';

void main() {
  final hoy = DateTime(2026, 7, 8);

  group('estadoVencimiento', () {
    test('sin fecha', () {
      expect(estadoVencimiento(null, hoy: hoy), EstadoVencimiento.sinFecha);
    });

    test('vencida (ayer)', () {
      expect(estadoVencimiento(DateTime(2026, 7, 7), hoy: hoy),
          EstadoVencimiento.caducada);
    });

    test('caduca hoy cuenta como caduca pronto', () {
      expect(estadoVencimiento(DateTime(2026, 7, 8), hoy: hoy),
          EstadoVencimiento.caducaPronto);
    });

    test('dentro de 30 días: caduca pronto', () {
      expect(estadoVencimiento(DateTime(2026, 8, 7), hoy: hoy),
          EstadoVencimiento.caducaPronto);
    });

    test('a más de 30 días: vigente', () {
      expect(estadoVencimiento(DateTime(2026, 12, 31), hoy: hoy),
          EstadoVencimiento.vigente);
    });
  });

  group('diasHastaVencimiento', () {
    test('null sin fecha', () {
      expect(diasHastaVencimiento(null, hoy: hoy), isNull);
    });
    test('negativo si ya venció', () {
      expect(diasHastaVencimiento(DateTime(2026, 7, 1), hoy: hoy), -7);
    });
    test('positivo a futuro', () {
      expect(diasHastaVencimiento(DateTime(2026, 7, 18), hoy: hoy), 10);
    });
  });

  test('Licencia.desdeJson lee el nombre del tipo embebido', () {
    final l = Licencia.desdeJson({
      'id': 'abc',
      'tipo_requisito_id': 'xyz',
      'vence': '2026-12-31',
      'tipos_requisito': {'nombre': 'Licencia de pesca', 'slug': 'licencia_pesca_cv'},
    });
    expect(l.tipoNombre, 'Licencia de pesca');
    expect(l.vence, DateTime(2026, 12, 31));
  });
}
