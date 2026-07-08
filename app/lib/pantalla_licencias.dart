import 'package:flutter/material.dart';
import 'licencia.dart';
import 'servicio_licencias.dart';
import 'theme.dart';

/// Cartera de licencias del usuario (con sesión): lista con avisos de caducidad
/// y alta / edición / borrado. Se muestra dentro de la pestaña "Mis licencias".
class CarteraLicencias extends StatefulWidget {
  const CarteraLicencias({super.key});

  @override
  State<CarteraLicencias> createState() => _CarteraLicenciasState();
}

class _CarteraLicenciasState extends State<CarteraLicencias> {
  final _servicio = ServicioLicencias();
  Future<List<Licencia>>? _futuro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    setState(() => _futuro = _servicio.misLicencias());
  }

  Future<void> _abrirFormulario({Licencia? licencia}) async {
    final cambiado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FormularioLicencia(servicio: _servicio, licencia: licencia),
    );
    if (cambiado == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Licencia>>(
          future: _futuro,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _Error(onReintentar: _cargar);
            }
            final licencias = snap.data ?? const [];
            if (licencias.isEmpty) {
              return _Vacia(onAnadir: () => _abrirFormulario());
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: licencias.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _TarjetaLicencia(
                licencia: licencias[i],
                onTocar: () => _abrirFormulario(licencia: licencias[i]),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
    );
  }
}

/// Tarjeta de una licencia con su aviso de caducidad.
class _TarjetaLicencia extends StatelessWidget {
  const _TarjetaLicencia({required this.licencia, required this.onTocar});
  final Licencia licencia;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    final estado = estadoVencimiento(licencia.vence);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTocar,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.badge_outlined, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(licencia.tipoNombre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _AvisoCaducidad(vence: licencia.vence, estado: estado),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de estado del vencimiento (color + texto), legible por lectores.
class _AvisoCaducidad extends StatelessWidget {
  const _AvisoCaducidad({required this.vence, required this.estado});
  final DateTime? vence;
  final EstadoVencimiento estado;

  @override
  Widget build(BuildContext context) {
    final (color, icono, texto) = _presentacion(context);
    return Row(
      children: [
        Icon(icono, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  (Color, IconData, String) _presentacion(BuildContext context) {
    switch (estado) {
      case EstadoVencimiento.caducada:
        return (VedraTheme.rojo, Icons.error_outline, 'Caducada (venció el ${_fecha(vence!)})');
      case EstadoVencimiento.caducaPronto:
        final dias = diasHastaVencimiento(vence);
        final cuando = dias == 0 ? 'hoy' : (dias == 1 ? 'mañana' : 'en $dias días');
        return (const Color(0xFFB26A00), Icons.warning_amber_rounded,
            'Caduca $cuando (${_fecha(vence!)})');
      case EstadoVencimiento.vigente:
        return (VedraTheme.verde, Icons.check_circle_outline, 'Vigente hasta ${_fecha(vence!)}');
      case EstadoVencimiento.sinFecha:
        return (Theme.of(context).colorScheme.outline, Icons.event_busy_outlined,
            'Sin fecha de vencimiento');
    }
  }
}

String _fecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Estado vacío: aún no hay licencias. Invita a añadir la primera.
class _Vacia extends StatelessWidget {
  const _Vacia({required this.onAnadir});
  final VoidCallback onAnadir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text('Aún no has añadido licencias',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(
              'Guarda aquí tus licencias (como la de pesca) y te avisaremos antes '
              'de que caduquen. El semáforo las tendrá en cuenta.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAnadir,
              icon: const Icon(Icons.add),
              label: const Text('Añadir mi primera licencia'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error al cargar (p. ej. sin conexión), con reintento.
class _Error extends StatelessWidget {
  const _Error({required this.onReintentar});
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('No hemos podido cargar tus licencias.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario de alta / edición en hoja inferior. En alta se elige el tipo; en
/// edición el tipo es fijo y se cambia la fecha o se borra.
class _FormularioLicencia extends StatefulWidget {
  const _FormularioLicencia({required this.servicio, this.licencia});
  final ServicioLicencias servicio;
  final Licencia? licencia;

  @override
  State<_FormularioLicencia> createState() => _FormularioLicenciaState();
}

class _FormularioLicenciaState extends State<_FormularioLicencia> {
  bool get _esEdicion => widget.licencia != null;
  List<TipoRequisito> _tipos = [];
  String? _tipoId;
  DateTime? _vence;
  bool _cargandoTipos = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vence = widget.licencia?.vence;
    _tipoId = widget.licencia?.tipoRequisitoId;
    _cargarTipos();
  }

  Future<void> _cargarTipos() async {
    try {
      final t = await widget.servicio.tiposDisponibles();
      if (mounted) {
        setState(() {
          _tipos = t;
          _cargandoTipos = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargandoTipos = false;
          _error = 'No hemos podido cargar los tipos de licencia.';
        });
      }
    }
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _vence ?? ahora,
      firstDate: DateTime(ahora.year - 5),
      lastDate: DateTime(ahora.year + 10),
      helpText: 'Fecha de vencimiento',
    );
    if (elegida != null) setState(() => _vence = elegida);
  }

  Future<void> _guardar() async {
    if (_tipoId == null) {
      setState(() => _error = 'Elige el tipo de licencia.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      if (_esEdicion) {
        await widget.servicio.actualizarVence(widget.licencia!.id, _vence);
      } else {
        await widget.servicio.anadir(_tipoId!, _vence);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No hemos podido guardar. Revisa tu conexión.';
        });
      }
    }
  }

  Future<void> _borrar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar esta licencia?'),
        content: const Text('Dejará de contar para el semáforo. Puedes volver a añadirla.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _guardando = true);
    try {
      await widget.servicio.borrar(widget.licencia!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No hemos podido eliminarla. Revisa tu conexión.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(_esEdicion ? 'Editar licencia' : 'Añadir licencia',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 20),
          if (_esEdicion)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined),
              title: Text(widget.licencia!.tipoNombre),
            )
          else if (_cargandoTipos)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _tipoId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Tipo de licencia', prefixIcon: Icon(Icons.badge_outlined)),
              items: [
                for (final t in _tipos)
                  DropdownMenuItem(value: t.id, child: Text(t.nombre, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _tipoId = v),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _elegirFecha,
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                alignment: Alignment.centerLeft),
            icon: const Icon(Icons.event_outlined),
            label: Text(_vence == null
                ? 'Fecha de vencimiento (opcional)'
                : 'Vence el ${_fecha(_vence!)}'),
          ),
          if (_vence != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _vence = null),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Quitar fecha'),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_esEdicion ? 'Guardar cambios' : 'Guardar'),
          ),
          if (_esEdicion)
            TextButton.icon(
              onPressed: _guardando ? null : _borrar,
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              label: Text('Eliminar',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
