import 'package:supabase_flutter/supabase_flutter.dart';
import 'licencia.dart';

/// Acceso a la cartera de licencias del usuario. Usa el cliente de Supabase
/// autenticado: la RLS garantiza que cada uno solo ve/gestiona las suyas
/// (auth.uid() = usuario_id). Las escrituras van con el JWT de la sesión.
class ServicioLicencias {
  SupabaseClient get _c => Supabase.instance.client;

  /// Tipos que el usuario puede declarar: credenciales que uno porta (ámbito
  /// estatal/ccaa), no condiciones locales de un sitio (paellero, plan de quemas).
  Future<List<TipoRequisito>> tiposDisponibles() async {
    final rows = await _c
        .from('tipos_requisito')
        .select('id, slug, nombre, url_tramite')
        .inFilter('ambito', ['estatal', 'ccaa']).order('nombre', ascending: true);
    return rows
        .map((j) => TipoRequisito.desdeJson(j))
        .toList();
  }

  /// Licencias del usuario, con el nombre del tipo, ordenadas por vencimiento
  /// más próximo (las que no tienen fecha, al final).
  Future<List<Licencia>> misLicencias() async {
    final rows = await _c
        .from('licencias_usuario')
        .select('id, tipo_requisito_id, vence, tipos_requisito(nombre, slug)')
        .order('vence', ascending: true, nullsFirst: false);
    return rows.map((j) => Licencia.desdeJson(j)).toList();
  }

  Future<void> anadir(String tipoRequisitoId, DateTime? vence) async {
    final uid = _c.auth.currentUser!.id;
    await _c.from('licencias_usuario').insert({
      'usuario_id': uid,
      'tipo_requisito_id': tipoRequisitoId,
      'vence': _fecha(vence),
    });
  }

  Future<void> actualizarVence(String id, DateTime? vence) async {
    await _c
        .from('licencias_usuario')
        .update({'vence': _fecha(vence)}).eq('id', id);
  }

  Future<void> borrar(String id) async {
    await _c.from('licencias_usuario').delete().eq('id', id);
  }

  /// La columna `vence` es DATE: se envía 'YYYY-MM-DD' (o null).
  String? _fecha(DateTime? d) => d?.toIso8601String().substring(0, 10);
}
