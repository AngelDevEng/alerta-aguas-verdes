import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_store.dart';

/// Inyecta `Authorization: Bearer <access>` en cada peticion.
///
/// Las rutas publicas (emergencias, crear alerta SOS) no llevan token: asi
/// siguen funcionando con la sesion caida, que es el requisito del caso SOS.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokens});

  final TokenStore tokens;

  static const publicPaths = <String>[
    '/auth/login',
    '/auth/refresh',
    '/catalogos/emergencias',
    '/alertas',
    '/incidencias', // POST: ciudadano puede reportar sin operacion previa
  ];

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