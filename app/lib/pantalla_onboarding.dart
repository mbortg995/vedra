import 'package:flutter/material.dart';
import 'actividades.dart';
import 'preferencias.dart';
import 'theme.dart';
import 'ubicacion.dart';

/// Primer arranque: 3 pantallas breves (bienvenida + semáforo, actividades de
/// interés y permiso de ubicación justificado). Se puede saltar en cualquier
/// momento y todo se cambia luego en Ajustes.
///
/// Al terminar (o saltar) guarda la selección, marca el onboarding como visto y
/// llama a [onListo] para que el arranque muestre la app.
class PantallaOnboarding extends StatefulWidget {
  const PantallaOnboarding({
    super.key,
    required this.onListo,
    this.actividadesIniciales = const [],
  });
  final VoidCallback onListo;

  /// Actividades ya elegidas (al repetir la presentación desde Ajustes).
  final List<String> actividadesIniciales;

  @override
  State<PantallaOnboarding> createState() => _PantallaOnboardingState();
}

class _PantallaOnboardingState extends State<PantallaOnboarding> {
  final _controlador = PageController();
  int _pagina = 0;
  late Set<String> _actividades = widget.actividadesIniciales.toSet();
  bool _permisoConcedido = false;
  bool _pidiendoPermiso = false;

  static const _ultima = 2;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _terminar() async {
    await Preferencias.guardarActividadesInteres(_actividades.toList());
    await Preferencias.marcarOnboardingCompleto();
    if (mounted) widget.onListo();
  }

  void _siguiente() {
    if (_pagina < _ultima) {
      _controlador.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _terminar();
    }
  }

  Future<void> _pedirPermiso() async {
    setState(() => _pidiendoPermiso = true);
    final ok = await ServicioUbicacion.solicitarPermiso();
    if (mounted) {
      setState(() {
        _permisoConcedido = ok;
        _pidiendoPermiso = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // "Saltar" siempre visible en la parte superior (acceptación #11).
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  onPressed: _terminar,
                  child: const Text('Saltar'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controlador,
                onPageChanged: (i) => setState(() => _pagina = i),
                children: [
                  const _PaginaBienvenida(),
                  _PaginaActividades(
                    seleccion: _actividades,
                    onCambio: (s) => setState(() => _actividades = s),
                  ),
                  _PaginaUbicacion(
                    concedido: _permisoConcedido,
                    pidiendo: _pidiendoPermiso,
                    onPermitir: _pedirPermiso,
                  ),
                ],
              ),
            ),
            _Controles(
              pagina: _pagina,
              total: _ultima + 1,
              onSiguiente: _siguiente,
            ),
          ],
        ),
      ),
    );
  }
}

/// Puntos de página + botón de avance (Siguiente / Empezar en la última).
class _Controles extends StatelessWidget {
  const _Controles(
      {required this.pagina, required this.total, required this.onSiguiente});
  final int pagina;
  final int total;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ultima = pagina == total - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == pagina ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == pagina ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onSiguiente,
            child: Text(ultima ? 'Empezar' : 'Siguiente'),
          ),
        ],
      ),
    );
  }
}

/// Envoltorio común de página: icono, título grande y contenido, con scroll por
/// si la fuente del sistema es muy grande (accesibilidad).
class _Pagina extends StatelessWidget {
  const _Pagina({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.hijos,
  });
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Icon(icono, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(titulo, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitulo, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          ...hijos,
        ],
      ),
    );
  }
}

class _PaginaBienvenida extends StatelessWidget {
  const _PaginaBienvenida();

  @override
  Widget build(BuildContext context) {
    return _Pagina(
      icono: Icons.eco,
      titulo: 'Bienvenido a Vedra',
      subtitulo:
          '¿Puedo pescar, hacer fuego o coger setas aquí hoy? Vedra lo cruza '
          'con la normativa oficial de tu zona y te responde con un semáforo.',
      hijos: const [
        _FilaSemaforo(
          color: VedraTheme.verde,
          icono: Icons.check_circle_rounded,
          titulo: 'Verde: adelante',
          texto: 'Cumples todo lo que exige la norma en ese punto y día.',
        ),
        _FilaSemaforo(
          color: VedraTheme.amarillo,
          icono: Icons.warning_amber_rounded,
          titulo: 'Amarillo: puedes, pero ojo',
          texto: 'Te falta un requisito (una licencia) o hay condiciones.',
        ),
        _FilaSemaforo(
          color: VedraTheme.rojo,
          icono: Icons.block_rounded,
          titulo: 'Rojo: hoy no',
          texto: 'Está prohibido o no podemos confirmarlo. Ante la duda, rojo.',
        ),
      ],
    );
  }
}

class _FilaSemaforo extends StatelessWidget {
  const _FilaSemaforo({
    required this.color,
    required this.icono,
    required this.titulo,
    required this.texto,
  });
  final Color color;
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: VedraTheme.sobreColor(_nombre(color)), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold, height: 1.2)),
                const SizedBox(height: 2),
                Text(texto, style: const TextStyle(fontSize: 15, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // El contraste del texto sobre el color lo decide el tema por nombre.
  String _nombre(Color c) => c == VedraTheme.amarillo ? 'amarillo' : 'verde';
}

class _PaginaActividades extends StatelessWidget {
  const _PaginaActividades({required this.seleccion, required this.onCambio});
  final Set<String> seleccion;
  final ValueChanged<Set<String>> onCambio;

  @override
  Widget build(BuildContext context) {
    return _Pagina(
      icono: Icons.interests_outlined,
      titulo: '¿Qué te interesa?',
      subtitulo:
          'Elige tus actividades para tenerlas a mano. Podrás cambiarlas '
          'cuando quieras en Ajustes.',
      hijos: [
        SelectorActividades(seleccion: seleccion, onCambio: onCambio),
      ],
    );
  }
}

class _PaginaUbicacion extends StatelessWidget {
  const _PaginaUbicacion({
    required this.concedido,
    required this.pidiendo,
    required this.onPermitir,
  });
  final bool concedido;
  final bool pidiendo;
  final VoidCallback onPermitir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Pagina(
      icono: Icons.place_outlined,
      titulo: 'Dónde estás importa',
      subtitulo:
          'Las normas cambian de un sitio a otro: comarca, coto, zona de '
          'preemergencia… Necesitamos tu punto exacto para acertar.',
      hijos: [
        if (concedido)
          Row(children: [
            Icon(Icons.check_circle, color: VedraTheme.verde),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Ubicación activada. Ya podemos localizarte con el GPS.',
                  style: TextStyle(fontSize: 16)),
            ),
          ])
        else
          FilledButton.tonalIcon(
            onPressed: pidiendo ? null : onPermitir,
            icon: pidiendo
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: const Text('Permitir ubicación'),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(Icons.map_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Si prefieres no dar el GPS, siempre puedes elegir un punto en '
                'el mapa al consultar.',
                style: TextStyle(fontSize: 15, height: 1.3),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
