import 'package:flutter/material.dart';

/// Catálogo de actividades del MVP (Comunitat Valenciana): clave interna que
/// entiende el motor -> etiqueta legible. Fuente única para consulta, onboarding
/// y ajustes, para no duplicarlo. Orden pensado para la app: pesca y fuego
/// delante (las cabecera del MVP).
///
/// Se usa un `Map<String, String>` tipado (valores String, no `dynamic`): el
/// acceso por clave dinámico en el árbol de widgets casca en dart2js release.
const actividadesCatalogo = <String, String>{
  'pesca': 'Pesca',
  'fuego_recreativo': 'Fuego recreativo',
  'quema': 'Quema de residuos',
  'setas': 'Setas',
};

/// Icono representativo de cada actividad (se lee por clave conocida, no dinámica).
IconData iconoActividad(String clave) {
  switch (clave) {
    case 'pesca':
      return Icons.phishing;
    case 'fuego_recreativo':
      return Icons.local_fire_department;
    case 'quema':
      return Icons.local_fire_department_outlined;
    case 'setas':
      return Icons.grass;
    default:
      return Icons.category_outlined;
  }
}

/// Selector multi-opción de actividades de interés, en chips grandes y legibles.
/// Reutilizado en el onboarding y en Ajustes. No persiste: el padre decide qué
/// hacer con la selección (lo mantiene la lógica separada de la UI).
class SelectorActividades extends StatelessWidget {
  const SelectorActividades({
    super.key,
    required this.seleccion,
    required this.onCambio,
  });

  final Set<String> seleccion;
  final ValueChanged<Set<String>> onCambio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entrada in actividadesCatalogo.entries)
          FilterChip(
            selected: seleccion.contains(entrada.key),
            avatar: Icon(
              iconoActividad(entrada.key),
              size: 20,
              color: seleccion.contains(entrada.key)
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
            label: Text(entrada.value),
            labelStyle: const TextStyle(fontSize: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onSelected: (marcado) {
              final nueva = Set<String>.from(seleccion);
              if (marcado) {
                nueva.add(entrada.key);
              } else {
                nueva.remove(entrada.key);
              }
              onCambio(nueva);
            },
          ),
      ],
    );
  }
}
