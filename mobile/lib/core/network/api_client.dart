import 'dart:async';

import 'package:dio/dio.dart';

import '../error/result.dart';

/// Cliente HTTP unico de la app.
///
/// Configura timeouts y SSL de Supabase/Render una sola vez. Los headers de
/// autorizacion y la logica de refresh viven en los interceptores.
class ApiClient {
  ApiClient({required String baseUrl, Dio? dio})
      : dio = dio ?? Dio() {
    this.dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // Render y Supabase presents certificates validos; si se usa un
      // certificado autofirmado en staging, extraer la excepcion aqui.
      validateStatus: (status) => status != null && status < 500,
    );
  }

  final Dio dio;

  /// Error de red/envio a un [Result] tipado segun el status recibido.
  static Failure toFailure(Object error, {int? statusCode}) {
    if (error is DioException) {
      final code = statusCode ?? error.response?.statusCode;
      if (code == 401) return const AuthFailure();
      if (code == 404) return const NotFoundFailure();
      if (code != null && code >= 500) {
        return ServerFailure(code, 'El servidor fallo ($code). Intenta de nuevo.');
      }
      final data = error.response?.data;
      final msg = data is Map && data['message'] != null
          ? data['message'].toString()
          : null;
      return NetworkFailure(msg ?? 'No se pudo completar la operacion.');
    }
    return NetworkFailure(error.toString());
  }

  /// GET tipado. Devuelve [Result] para que el llamador no Lance excepciones.
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await dio.get<dynamic>(path, queryParameters: query);
      return Ok<T>(parse(res.data));
    } catch (e) {
      return Err<T>(toFailure(e));
    }
  }

  /// POST tipado.
  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await dio.post<dynamic>(path, data: body);
      return Ok<T>(parse(res.data));
    } catch (e) {
      return Err<T>(toFailure(e));
    }
  }

  /// POST multipart para evidencias (foto/audio).
  Future<Result<T>> upload<T>(
    String path, {
    required FormData formData,
    ProgressCallback? onProgress,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final res = await dio.post<dynamic>(
        path,
        data: formData,
        onSendProgress: onProgress,
      );
      return Ok<T>(parse(res.data));
    } catch (e) {
      return Err<T>(toFailure(e));
    }
  }
}