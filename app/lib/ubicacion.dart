import 'package:geolocator/geolocator.dart';

class Ubicacion {
  final double lat;
  final double lon;
  const Ubicacion(this.lat, this.lon);
}

/// Obtiene la ubicación del dispositivo, con mensajes legibles si no se puede.
/// Lanza un String (mensaje para el usuario) en caso de fallo controlado.
class ServicioUbicacion {
  static Future<Ubicacion> actual() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'La ubicación está desactivada en tu dispositivo. Actívala o elige un punto.';
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw 'Necesitamos permiso de ubicación. Puedes elegir un punto manualmente.';
    }
    final pos = await Geolocator.getCurrentPosition();
    return Ubicacion(pos.latitude, pos.longitude);
  }
}
