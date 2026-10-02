import 'package:equatable/equatable.dart';

/// DTO de `GET /catalogos/emergencias` y `/catalogos/emergencias/whatsapp`.
class ContactoEmergenciaDto extends Equatable {
  const ContactoEmergenciaDto({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.esWhatsapp,
    required this.orden,
    this.activo = true,
  });

  final int id;
  final String nombre;
  final String telefono;
  final bool esWhatsapp;
  final int orden;
  final bool activo;

  /// El backend ya devuelve `esWhatsapp` en camelCase, pero acepta `es_whatsapp`
  /// para no romper si el mapeo del servidor cambia.
  factory ContactoEmergenciaDto.fromJson(Map<String, dynamic> json) =>
      ContactoEmergenciaDto(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nombre: json['nombre']?.toString() ?? '',
        telefono: json['telefono']?.toString() ?? '',
        esWhatsapp: (json['esWhatsapp'] ?? json['es_whatsapp']) == true,
        orden: (json['orden'] as num?)?.toInt() ?? 0,
        activo: json['activo'] != false,
      );

  @override
  List<Object?> get props => [id, nombre, telefono, esWhatsapp, orden, activo];
}

/// DTO de `GET /catalogos/asociaciones` (requiere rol de operador).
class AsociacionDto extends Equatable {
  const AsociacionDto({required this.id, required this.nombre});

  final int id;
  final String nombre;

  factory AsociacionDto.fromJson(Map<String, dynamic> json) => AsociacionDto(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nombre: json['nombre']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [id, nombre];
}