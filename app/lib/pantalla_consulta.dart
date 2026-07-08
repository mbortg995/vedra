import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'actividades.dart';
import 'preferencias.dart';
import 'supabase_api.dart';
import 'semaforo.dart';
import 'theme.dart';
import 'ubicacion.dart';
import 'pantalla_mapa.dart';

/// Pestaña "Consulta": el semáforo contextual "aquí y ahora".
class ConsultaTab extends StatefulWidget {
  const ConsultaTab({super.key});
  @override
  State<ConsultaTab> createState() => _ConsultaTabState();
}

class _ConsultaTabState extends State<ConsultaTab> {
  final _api = SupabaseApi();
  String _actividad = 'pesca';
  double _lat = 39.9864;
  double _lon = -0.0513;
  String _ubicacionLabel = 'Castelló (interior CV)';
  bool _cargandoGps = false;
  Future<Resultado>? _futuro;

  @override
  void initState() {
    super.initState();
    _cargarActividadPreferida();
  }

  /// Preselecciona la primera actividad de interés elegida en el onboarding.
  Future<void> _cargarActividadPreferida() async {
    final interes = await Preferencias.actividadesInteres();
    final primera = interes.firstWhere(
        (a) => actividadesCatalogo.containsKey(a),
        orElse: () => '');
    if (primera.isNotEmpty && mounted) {
      setState(() => _actividad = primera);
    }
  }

  Future<void> _usarGps() async {
    setState(() => _cargandoGps = true);
    try {
      final u = await ServicioUbicacion.actual();
      setState(() {
        _lat = u.lat;
        _lon = u.lon;
        _ubicacionLabel = 'Mi ubicación';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _cargandoGps = false);
    }
  }

  Future<void> _elegirEnMapa() async {
    final punto = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => PantallaMapa(inicial: LatLng(_lat, _lon))),
    );
    if (punto != null) {
      setState(() {
        _lat = punto.latitude;
        _lon = punto.longitude;
        _ubicacionLabel = 'Punto en el mapa';
      });
    }
  }

  void _consultar() {
    final f = evaluar(_api, _actividad, _lat, _lon);
    setState(() {
      _futuro = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            items: actividadesCatalogo.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _actividad = v!),
          ),
          const SizedBox(height: 18),
          Text('Ubicación', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _cargandoGps ? null : _usarGps,
            icon: _cargandoGps
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: const Text('Usar mi ubicación'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _elegirEnMapa,
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Elegir en el mapa'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.place, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
                child: Text('Consultando en: $_ubicacionLabel',
                    style: Theme.of(context).textTheme.bodySmall)),
          ]),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _consultar,
            icon: const Icon(Icons.search),
            label: const Text('Consultar'),
          ),
          const SizedBox(height: 24),
          _resultado(),
        ],
      ),
    );
  }

  Widget _resultado() {
    if (_futuro == null) return const _EstadoVacio();
    return FutureBuilder<Resultado>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _EstadoCargando();
        }
        if (snap.hasError) {
          return _AvisoError(onReintentar: _consultar);
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

/// Estado inicial: aún no se ha consultado. Guía al siguiente paso.
class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Icon(Icons.eco_outlined, size: 56, color: muted),
          const SizedBox(height: 12),
          Text('Pulsa "Consultar" para ver tu semáforo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Te diremos si puedes, con la normativa oficial de tu zona.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Estado de carga con contexto (no un spinner suelto).
class _EstadoCargando extends StatelessWidget {
  const _EstadoCargando();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Consultando la normativa oficial…',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Error técnico (p. ej. sin conexión). Distinto del rojo normativo: aquí NO hay
/// veredicto — se ofrece reintentar y se recuerda no darlo por permitido.
class _AvisoError extends StatelessWidget {
  const _AvisoError({required this.onReintentar});
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.wifi_off_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text('No hemos podido consultar ahora mismo.',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            const Text('Parece un problema de conexión. Esto no es una respuesta '
                'oficial: mientras no podamos comprobarlo, no des por hecho que puedes.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
