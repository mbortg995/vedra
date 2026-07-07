import 'package:flutter/material.dart';
import 'supabase_api.dart';
import 'semaforo.dart';

void main() => runApp(const VedraApp());

class VedraApp extends StatelessWidget {
  const VedraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vedra',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const PantallaSemaforo(),
    );
  }
}

/// Ubicaciones de prueba (hasta que integremos el GPS del dispositivo).
const _ubicaciones = {
  'Castelló (interior CV)': [39.9864, -0.0513],
  'Penyagolosa (CV)': [40.22, -0.30],
  'Madrid (fuera de la CV)': [40.42, -3.70],
};
const _actividades = {
  'pesca': 'Pesca',
  'quema': 'Quema de residuos',
  'fuego_recreativo': 'Fuego recreativo',
  'setas': 'Setas',
};

class PantallaSemaforo extends StatefulWidget {
  const PantallaSemaforo({super.key});
  @override
  State<PantallaSemaforo> createState() => _PantallaSemaforoState();
}

class _PantallaSemaforoState extends State<PantallaSemaforo> {
  final _api = SupabaseApi();
  String _actividad = 'pesca';
  String _ubicacion = 'Castelló (interior CV)';
  Future<Resultado>? _futuro;

  void _consultar() {
    final c = _ubicaciones[_ubicacion]!;
    setState(() => _futuro = evaluar(_api, _actividad, c[0], c[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vedra — ¿puedo hacerlo aquí hoy?')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _actividad,
              decoration: const InputDecoration(labelText: 'Actividad'),
              items: _actividades.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _actividad = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _ubicacion,
              decoration: const InputDecoration(labelText: 'Ubicación'),
              items: _ubicaciones.keys
                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) => setState(() => _ubicacion = v!),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _consultar,
              icon: const Icon(Icons.search),
              label: const Text('Consultar'),
            ),
            const SizedBox(height: 16),
            Expanded(child: _resultado()),
          ],
        ),
      ),
    );
  }

  Widget _resultado() {
    if (_futuro == null) {
      return const Center(child: Text('Elige actividad y ubicación, y pulsa Consultar.'));
    }
    return FutureBuilder<Resultado>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        return _TarjetaSemaforo(res: snap.data!);
      },
    );
  }
}

class _TarjetaSemaforo extends StatelessWidget {
  const _TarjetaSemaforo({required this.res});
  final Resultado res;

  static const _colores = {
    'verde': Color(0xFF2E7D32),
    'amarillo': Color(0xFFF9A825),
    'rojo': Color(0xFFC62828),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colores[res.semaforo]!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(radius: 16, backgroundColor: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(res.titulo,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ),
          ]),
          const SizedBox(height: 12),
          if (res.territorios.isNotEmpty)
            _seccion('Dónde estás', [
              for (final t in res.territorios) '• ${t['nombre']}',
            ]),
          if (res.condicion != null)
            _seccion('Preemergencia', [
              '• Nivel ${res.condicion!['nivel']} '
                  '(${res.condicionFresca ? 'fresco' : 'CADUCO'})',
            ]),
          if (res.bloqueos.isNotEmpty)
            _seccion('Bloqueos', [for (final b in res.bloqueos) '⛔ ${b['detalle']}']),
          if (res.requisitos.isNotEmpty)
            _seccion('Requisitos', [for (final q in res.requisitos) '✗ ${q['detalle']}']),
          if (res.avisos.isNotEmpty)
            _seccion('A tener en cuenta', [for (final a in res.avisos) 'ℹ $a']),
          const SizedBox(height: 12),
          Text(res.disclaimer, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, List<String> lineas) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            for (final l in lineas) Text(l),
          ],
        ),
      );
}
