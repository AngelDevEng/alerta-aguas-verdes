import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_store.dart';

/// Inyecta `Authorization: Bearer <access>` en cada peticion.
///
/// Una peticion se declara publica en el *call site*:
///
/// ```dart
/// api.post<AuthSessionDto>('/auth/login', body: {...}, publico: true, parse: ...);
/// ```
///
/// No se deduce del path. Antes habia una lista `publicPaths` con
/// `'/incidencias'` en ella, que era peor que no tenerla: el mismo path sirve
/// para el `POST` de reportar y para el `GET` de listar, y el segundo si exige
/// token (`@Roles('SERENO','OPERADOR','ADMIN','DIRECTIVO')`). Cualquier
/// casamiento por prefijo habria desautorizado la lista. El opt-in explicito
/// no puede tener ese error.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokens});

  final TokenStore tokens;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!options.extra.containsKey('public')) {
      final token = await tokens.readAccess();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

/// Renueva el access token una sola vez ante un 401 y reintenta la peticion.
///
/// Sin el lock, varias peticiones concurrentes (mapa + GPS + lista) dispararian
/// N refreshes y N rotaciones, y el backend invalida el refresh en cada uso.
///
/// Depende de que `ApiClient` deje que los 4xx lleguen hasta aca como
/// `DioException`. Si `validateStatus` los acepta, `onError` no corre y el
/// refresh queda muerto sin que nada avise: ver el comentario en
/// `ApiClient` sobre ese flag.
class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({required this.tokens, required this.dio});

  final TokenStore tokens;
  final Dio dio;

  Future<bool>? _inFlight;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (status != 401 || alreadyRetried || _isRefreshCall(err.requestOptions)) {
      return handler.next(err);
    }

    final refreshed = await (_inFlight ??= _doRefresh().whenComplete(() => _inFlight = null));
    if (!refreshed) {
      await tokens.clear();
      return handler.next(err);
    }

    try {
      final token = await tokens.readAccess();
      final opts = err.requestOptions;
      opts.extra['retried'] = true;
      opts.headers['Authorization'] = 'Bearer $token';
      final res = await dio.fetch<dynamic>(opts);
      return handler.resolve(res);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _isRefreshCall(RequestOptions o) => o.path.contains('/auth/refresh');

  Future<bool> _doRefresh() async {
    final refresh = await tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await dio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = res.data as Map<String, dynamic>;
      await tokens.save(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
      return true;
    } catch (e) {
      debugPrint('[RefreshInterceptor] refresh fallido: $e');
      return false;
    }
  }
}