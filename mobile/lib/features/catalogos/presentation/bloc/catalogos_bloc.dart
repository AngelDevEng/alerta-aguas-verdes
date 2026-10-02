import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../domain/usecases/catalogo_usecases.dart';
import 'catalogos_event.dart';
import 'catalogos_state.dart';

/// ViewModel del catálogo de emergencias.
class CatalogosBloc extends Bloc<CatalogosEvent, CatalogosState> {
  CatalogosBloc(this._obtenerEmergencias) : super(const CatalogosCargando()) {
    on<CargarEmergencias>(_onCargar);
  }

  final ObtenerEmergenciasUseCase _obtenerEmergencias;

  Future<void> _onCargar(CargarEmergencias event, Emitter<CatalogosState> emit) async {
    emit(const CatalogosCargando());
    final res = await _obtenerEmergencias();
    switch (res) {
      case Ok(:final value):
        emit(CatalogosListos(value));
      case Err(:final failure):
        emit(CatalogosError(failure.message));
    }
  }
}