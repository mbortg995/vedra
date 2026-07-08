import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales del usuario (primer arranque y actividades de interés).
///
/// Persistencia sencilla en el dispositivo con `shared_preferences`. No guarda
/// nada sensible: solo si ya se vio el onboarding y qué actividades le interesan
/// al usuario, para preseleccionarlas en la consulta.
class Preferencias {
  static const _kOnboardingCompleto = 'onboarding_completo';
  static const _kActividadesInteres = 'actividades_interes';

  /// ¿Ya completó (o saltó) el usuario el onboarding alguna vez?
  static Future<bool> onboardingCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingCompleto) ?? false;
  }

  /// Marca el onboarding como visto para no volver a mostrarlo en el arranque.
  static Future<void> marcarOnboardingCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleto, true);
  }

  /// Vuelve a mostrar el onboarding en el próximo arranque ("repetir presentación").
  static Future<void> reiniciarOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleto, false);
  }

  /// Actividades marcadas como de interés (claves del catálogo). Puede estar vacía.
  static Future<List<String>> actividadesInteres() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kActividadesInteres) ?? const [];
  }

  static Future<void> guardarActividadesInteres(List<String> claves) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kActividadesInteres, claves);
  }
}
