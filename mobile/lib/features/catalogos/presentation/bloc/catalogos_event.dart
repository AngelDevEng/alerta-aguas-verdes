import 'package:equatable/equatable.dart';

sealed class CatalogosEvent extends Equatable {
  const CatalogosEvent();

  @override
  List<Object?> get props => [];
}

/// Pide la lista completa de contactos de emergencia.
class CargarEmergencias extends CatalogosEvent {
  const CargarEmergencias();
}