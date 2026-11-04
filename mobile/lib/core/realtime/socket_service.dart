import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  SocketService({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  io.Socket? _socket;
  int _attempt = 0;
  Timer? _reconnectTimer;
  bool _disposed = false;

  final _positionController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get positions => _positionController.stream;

  void connect() {
    if (_disposed) return;
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );
    _socket!.onConnect((_) {
      _attempt = 0;
    });
    _socket!.on('posicion_unidad', (data) {
      if (data is Map) {
        _positionController.add(Map<String, dynamic>.from(data));
      }
    });
    _socket!.onDisconnect((_) => _scheduleReconnect());
    _socket!.onConnectError((_) => _scheduleReconnect());
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (1 << _attempt.clamp(0, 5)).clamp(1, 30));
    _attempt++;
    _reconnectTimer = Timer(delay, connect);
  }

  void publishPosition(Map<String, dynamic> payload) {
    _socket?.emit('posicion_unidad', payload);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _socket?.dispose();
    _positionController.close();
  }
}
