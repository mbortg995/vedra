import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Selector de punto en un mapa. Se toca para colocar el marcador y se devuelve
/// el `LatLng` elegido. Permite planificar desde casa sin depender del GPS.
class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key, required this.inicial});
  final LatLng inicial;

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  late LatLng _punto = widget.inicial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elige un punto')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.touch_app_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Toca el mapa para marcar el punto que quieres consultar.'),
              ),
            ]),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: widget.inicial,
                initialZoom: 9,
                onTap: (_, latlng) => setState(() => _punto = latlng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'es.vedra.vedra',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: _punto,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: Color(0xFFC62828), size: 44),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, _punto),
            icon: const Icon(Icons.check),
            label: const Text('Usar este punto'),
          ),
        ),
      ),
    );
  }
}
