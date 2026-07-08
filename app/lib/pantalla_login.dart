import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'servicio_auth.dart';

/// Inicio de sesión / alta con correo + código OTP. Dos pasos: pides el código
/// a tu correo y luego lo introduces. Al validar, se devuelve `true` al llamador.
class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

enum _Paso { correo, codigo }

class _PantallaLoginState extends State<PantallaLogin> {
  final _auth = ServicioAuth();
  final _correoCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  _Paso _paso = _Paso.correo;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  String get _correo => _correoCtrl.text.trim();

  bool _correoValido(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

  Future<void> _enviarCodigo() async {
    if (!_correoValido(_correo)) {
      setState(() => _error = 'Escribe un correo válido.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _auth.enviarCodigo(_correo);
      if (mounted) setState(() => _paso = _Paso.codigo);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No hemos podido enviar el código. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verificar() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.length < 6) {
      setState(() => _error = 'El código tiene 6 dígitos.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _auth.verificarCodigo(_correo, codigo);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No hemos podido validar el código. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _paso == _Paso.correo ? _pasoCorreo() : _pasoCodigo(),
        ),
      ),
    );
  }

  Widget _pasoCorreo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.mail_outline, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text('Entra con tu correo',
              style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: 8),
        Text('Te enviamos un código de 6 dígitos. Sin contraseñas que recordar. '
            'Lo necesitas para guardar tus licencias.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        TextField(
          controller: _correoCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _cargando ? null : _enviarCodigo(),
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        if (_error != null) _avisoError(_error!),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _cargando ? null : _enviarCodigo,
          icon: _cargando
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          label: const Text('Enviar código'),
        ),
      ],
    );
  }

  Widget _pasoCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text('Introduce el código',
              style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: 8),
        Text('Hemos enviado un código a $_correo. Míralo en tu correo y escríbelo aquí.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        TextField(
          controller: _codigoCtrl,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          onSubmitted: (_) => _cargando ? null : _verificar(),
          decoration: const InputDecoration(
            labelText: 'Código de 6 dígitos',
            prefixIcon: Icon(Icons.pin_outlined),
            counterText: '',
          ),
        ),
        if (_error != null) _avisoError(_error!),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _cargando ? null : _verificar,
          icon: _cargando
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          label: const Text('Entrar'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _cargando
              ? null
              : () => setState(() {
                    _paso = _Paso.correo;
                    _error = null;
                    _codigoCtrl.clear();
                  }),
          child: const Text('Usar otro correo'),
        ),
      ],
    );
  }

  Widget _avisoError(String mensaje) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 20, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(mensaje,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }
}
