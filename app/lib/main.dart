import 'package:flutter/material.dart';
import 'theme.dart';
import 'pantalla_consulta.dart';

void main() => runApp(const VedraApp());

class VedraApp extends StatelessWidget {
  const VedraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vedra',
      debugShowCheckedModeBanner: false,
      theme: VedraTheme.light(),
      home: const InicioVedra(),
    );
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
    _AjustesTab(),
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

class _LicenciasTab extends StatelessWidget {
  const _LicenciasTab();
  @override
  Widget build(BuildContext context) {
    return const _Proximamente(
      icono: Icons.badge_outlined,
      titulo: 'Tus licencias, en un sitio',
      texto:
          'Aquí guardarás tus licencias de pesca, caza y demás, y te avisaremos '
          'antes de que caduquen. Además, el semáforo tendrá en cuenta lo que ya tienes.',
    );
  }
}

class _AjustesTab extends StatelessWidget {
  const _AjustesTab();
  @override
  Widget build(BuildContext context) {
    return const _Proximamente(
      icono: Icons.settings_outlined,
      titulo: 'Ajustes',
      texto: 'Tus actividades de interés, avisos y preferencias de la app.',
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
            Text(titulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
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
