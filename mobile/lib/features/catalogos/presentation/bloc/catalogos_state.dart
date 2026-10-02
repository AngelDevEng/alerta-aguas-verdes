import 'package:equatable/equatable.dart';

import '../../domain/entities/catalogo.dart';

sealed class CatalogosState extends Equatable {
  const CatalogosState();

  @override
  List<Object?> get props => [];
}

class CatalogosCargando extends CatalogosState {
  const CatalogosCargando();
}

class CatalogosListos extends CatalogosState {
  const CatalogosListos(this.emergencias);

  final List<ContactoEmergencia> emergencias;

  @override
  List<Object?> get props => [emergencias];
}

class CatalogosError extends CatalogosState {
  const CatalogosError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => [mensaje];
}