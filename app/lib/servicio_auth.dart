import 'package:supabase_flutter/supabase_flutter.dart';

/// Autenticación con Supabase por **correo + código OTP** de un solo uso.
///
/// Envuelve el SDK para que la UI no dependa de sus tipos y sea fácil de razonar.
/// `inicializado` lo pone `main()` tras `Supabase.initialize`: mientras es false
/// (p. ej. en los tests, que no arrancan Supabase) todo se comporta como "sin
/// sesión" en vez de reventar al leer `Supabase.instance`.
class ServicioAuth {
  static bool inicializado = false;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  bool get haySesion => inicializado && _auth.currentSession != null;

  /// Correo de la sesión actual, si la hay (para mostrarlo en Ajustes).
  String? get correo => inicializado ? _auth.currentUser?.email : null;

  /// Cambios de sesión (login/logout) para que la UI se refresque sola.
  Stream<AuthState> get cambios =>
      inicializado ? _auth.onAuthStateChange : const Stream.empty();

  /// Envía un código de acceso al correo. Sirve para alta e inicio de sesión
  /// (`shouldCreateUser: true`): quien no exista, se crea.
  Future<void> enviarCodigo(String email) =>
      _auth.signInWithOtp(email: email, shouldCreateUser: true);

  /// Verifica el código de 6 dígitos recibido por correo e inicia sesión.
  Future<void> verificarCodigo(String email, String codigo) =>
      _auth.verifyOTP(email: email, token: codigo, type: OtpType.email);

  Future<void> cerrarSesion() => _auth.signOut();
}
