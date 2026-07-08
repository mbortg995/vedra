import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'actividades.dart';
import 'config.dart';
import 'preferencias.dart';
import 'pantalla_login.dart';
import 'pantalla_onboarding.dart';
import 'servicio_auth.dart';
import 'theme.dart';
import 'pantalla_consulta.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicia Supabase (restaura la sesión guardada, si la hay). La anon key es
  // pública por diseño; la RLS protege los datos de usuario por auth.uid().
  await Supabase.initialize(
    url: Config.supabaseUrl,
    // Nuestra clave es la anon key (JWT legacy). El SDK la renombró a
    // `publishableKey`, pero `anonKey` sigue funcionando y describe lo que es.
    // ignore: deprecated_member_use
    anonKey: Config.supabaseAnonKey,
  );
  ServicioAuth.inicializado = true;
  runApp(const VedraApp());
}

class VedraApp extends StatelessWidget {
  const VedraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vedra',
      debugShowCheckedModeBanner: false,
      theme: VedraTheme.light(),
      home: const _Arranque(),
      // Respeta el escalado de fuente del sistema (accesibilidad), pero lo acota
      // para que un tamaño extremo no rompa el layout. Todas las pantallas
      // desplazan su contenido, así que dentro de este margen nada se recorta.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6),
          ),
          child: child!,
        );
      },
    );
  }
}

/// Decide qué mostrar en el primer frame: onboarding si es el primer arranque,
/// la app si ya se vio. Mientras carga la preferencia, un splash mínimo.
class _Arranque extends StatefulWidget {
  const _Arranque();
  @override
  State<_Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<_Arranque> {
  bool? _mostrarOnboarding;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    bool completo;
    try {
      completo = await Preferencias.onboardingCompleto();
    } catch (e) {
      // Si las preferencias fallan, no bloqueamos el arranque: mostramos el
      // onboarding (comportamiento del primer uso) en vez de colgarnos.
      debugPrint('Preferencias no disponibles: $e');
      completo = false;
    }
    if (mounted) setState(() => _mostrarOnboarding = !completo);
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_mostrarOnboarding!) {
      return PantallaOnboarding(
        onListo: () => setState(() => _mostrarOnboarding = false),
      );
    }
    return const InicioVedra();
  }
}

/// Shell de la app con navegación inferior. Pocas pestañas, siempre visibles.
class InicioVedra extends StatefulWidget {
  const InicioVedra({super.key});
  @override
  State<InicioVedra> createState() => _InicioVedraState();
}

class _InicioVedraState extends State<InicioVedra> {
  int _indice = 0;

  static const _titulos = ['Vedra', 'Mis licencias', 'Ajustes'];
  static const _paginas = [
    ConsultaTab(),
    _LicenciasTab(),
    AjustesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_indice], style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: IndexedStack(index: _indice, children: _paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.travel_explore_outlined),
              selectedIcon: Icon(Icons.travel_explore),
              label: 'Consulta'),
          NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: 'Licencias'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Ajustes'),
        ],
      ),
    );
  }
}

/// Pestaña "Mis licencias". Necesita sesión: sin ella, invita a entrar; con
/// ella, la cartera (CRUD en un PR posterior). Se refresca al cambiar la sesión.
class _LicenciasTab extends StatefulWidget {
  const _LicenciasTab();
  @override
  State<_LicenciasTab> createState() => _LicenciasTabState();
}

class _LicenciasTabState extends State<_LicenciasTab> {
  final _auth = ServicioAuth();
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _auth.cambios.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _login() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_auth.haySesion) {
      return _InvitaLogin(onLogin: _login);
    }
    return const _Proximamente(
      icono: Icons.badge_outlined,
      titulo: 'Tus licencias, en un sitio',
      texto:
          'Aquí guardarás tus licencias de pesca, caza y demás, y te avisaremos '
          'antes de que caduquen. El semáforo tendrá en cuenta lo que ya tienes.',
    );
  }
}

/// Invitación a iniciar sesión desde la pestaña de licencias (sin sesión).
class _InvitaLogin extends StatelessWidget {
  const _InvitaLogin({required this.onLogin});
  final VoidCallback onLogin;

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
              child: Text('Guarda tus licencias',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(
              'Entra con tu correo para guardar tus licencias y que el semáforo '
              'cuente con ellas. Consultar el semáforo no necesita cuenta.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login),
              label: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ajustes: actividades de interés (editables), cuenta (iniciar/cerrar sesión) y
/// volver a ver la presentación. El sitio donde el usuario cambia lo que eligió
/// en el onboarding (acceptación del issue #11).
class AjustesTab extends StatefulWidget {
  const AjustesTab({super.key});
  @override
  State<AjustesTab> createState() => _AjustesTabState();
}

class _AjustesTabState extends State<AjustesTab> {
  final _auth = ServicioAuth();
  Set<String> _actividades = {};
  bool _cargado = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _cargar();
    _sub = _auth.cambios.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final a = await Preferencias.actividadesInteres();
    if (mounted) {
      setState(() {
        _actividades = a.toSet();
        _cargado = true;
      });
    }
  }

  Future<void> _guardar(Set<String> nueva) async {
    setState(() => _actividades = nueva);
    await Preferencias.guardarActividadesInteres(nueva.toList());
  }

  Future<void> _login() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _cerrarSesion() async {
    await _auth.cerrarSesion();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sesión cerrada.')));
    }
  }

  Future<void> _repetirPresentacion() async {
    await Preferencias.reiniciarOnboarding();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaOnboarding(
          actividadesIniciales: _actividades.toList(),
          onListo: () => Navigator.of(context).pop(),
        ),
      ),
    );
    // Al volver, recarga por si cambió la selección durante la presentación.
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cargado) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Semantics(
            header: true,
            child: Text('Tus actividades', style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 4),
          Text('Las que te interesan aparecen a mano al consultar.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          SelectorActividades(seleccion: _actividades, onCambio: _guardar),
          const SizedBox(height: 28),
          const Divider(),
          _seccionCuenta(),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.slideshow_outlined),
            title: const Text('Ver la presentación de nuevo'),
            subtitle: const Text('Repasa cómo funciona el semáforo y los permisos.'),
            onTap: _repetirPresentacion,
          ),
        ],
      ),
    );
  }

  Widget _seccionCuenta() {
    if (_auth.haySesion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Tu cuenta'),
            subtitle: Text(_auth.correo ?? 'Sesión iniciada'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.login),
      title: const Text('Iniciar sesión'),
      subtitle: const Text('Para guardar tus licencias y sincronizar.'),
      onTap: _login,
    );
  }
}

/// Placeholder amable para las secciones aún por construir.
class _Proximamente extends StatelessWidget {
  const _Proximamente({required this.icono, required this.titulo, required this.texto});
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: muted),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(titulo,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(texto,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            Chip(
              avatar: const Icon(Icons.hourglass_top, size: 18),
              label: const Text('Muy pronto'),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
      ),
    );
  }
}
