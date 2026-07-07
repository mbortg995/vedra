import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_api.dart';
import 'semaforo.dart';
import 'theme.dart';

void main() => runApp(const VedraApp());

class VedraApp extends StatelessWidget {
  const VedraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vedra',
      debugShowCheckedModeBanner: false,
      theme: VedraTheme.light(),
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
    final f = evaluar(_api, _actividad, c[0], c[1]);
    setState(() {
      _futuro = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vedra', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('¿Puedo hacerlo aquí hoy?',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Elige la actividad y dónde estás.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _actividad,
              decoration: const InputDecoration(
                  labelText: 'Actividad', prefixIcon: Icon(Icons.category_outlined)),
              items: _actividades.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _actividad = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _ubicacion,
              decoration: const InputDecoration(
                  labelText: 'Ubicación', prefixIcon: Icon(Icons.place_outlined)),
              items: _ubicaciones.keys
                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) => setState(() => _ubicacion = v!),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _consultar,
              icon: const Icon(Icons.search),
              label: const Text('Consultar'),
            ),
            const SizedBox(height: 24),
            if (_futuro != null) _resultado(),
          ],
        ),
      ),
    );
  }

  Widget _resultado() {
    return FutureBuilder<Resultado>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return const _AvisoError();
        }
        return TarjetaSemaforo(res: snap.data!);
      },
    );
  }
}

/// Tarjeta protagonista: veredicto legible de un vistazo + detalle y fuentes.
class TarjetaSemaforo extends StatelessWidget {
  const TarjetaSemaforo({super.key, required this.res});
  final Resultado res;

  @override
  Widget build(BuildContext context) {
    final color = VedraTheme.color(res.semaforo);
    final sobre = VedraTheme.sobreColor(res.semaforo);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(VedraTheme.icono(res.semaforo), color: sobre, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(res.titulo,
                      style: TextStyle(
                          color: sobre,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.2)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (res.territorios.isNotEmpty)
                  _bloque(context, Icons.place_outlined, 'Dónde estás',
                      [for (final t in res.territorios) Text('• $t')]),
                if (res.condicionNivel != null)
                  _bloque(context, Icons.local_fire_department_outlined, 'Preemergencia', [
                    Text('Nivel ${res.condicionNivel} · '
                        '${res.condicionFresca ? 'dato de hoy' : 'dato caducado'}'),
                  ]),
                for (final b in res.bloqueos)
                  _razon(context, Icons.block_rounded, VedraTheme.rojo, b),
                for (final q in res.requisitos)
                  _razon(context, Icons.badge_outlined, VedraTheme.amarillo, q),
                for (final a in res.avisos)
                  _razon(context, Icons.info_outline, Colors.blueGrey, a),
                const SizedBox(height: 8),
                Text(res.disclaimer,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloque(BuildContext context, IconData icono, String titulo, List<Widget> hijos) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icono, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: hijos),
          ),
        ],
      ),
    );
  }

  Widget _razon(BuildContext context, IconData icono, Color color, Item item) {
    final f = item.fuente;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.texto, style: const TextStyle(fontSize: 16, height: 1.3)),
                if (f?.organismo != null)
                  TextButton.icon(
                    onPressed: f?.url == null
                        ? null
                        : () => launchUrl(Uri.parse(f!.url!),
                            mode: LaunchMode.externalApplication),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text('Fuente: ${f!.organismo}', textAlign: TextAlign.left),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoError extends StatelessWidget {
  const _AvisoError();
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.wifi_off_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No hemos podido consultar ahora mismo.',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Revisa tu conexión e inténtalo de nuevo.'),
            ]),
          ),
        ]),
      ),
    );
  }
}
