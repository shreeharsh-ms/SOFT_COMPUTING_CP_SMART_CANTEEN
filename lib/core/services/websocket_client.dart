import "dart:async";
import "dart:convert";
import "dart:math";
import "package:flutter/foundation.dart";
import "package:web_socket_channel/web_socket_channel.dart";
import "package:web_socket_channel/status.dart" as status;
import "api_client.dart";

enum WsConnectionStatus { disconnected, connecting, authenticating, connected }

class WebSocketClient {
  static const String wsBaseUrl = "ws://localhost:8000/api/v1/ws/connect";
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  
  int _reconnectAttempts = 0;
  static const int _baseDelayMs = 1000;
  static const int _maxDelayMs = 30000;
  
  bool _isDisposed = false;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<WsConnectionStatus>.broadcast();
  
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<WsConnectionStatus> get statusStream => _statusController.stream;
  
  WsConnectionStatus _currentStatus = WsConnectionStatus.disconnected;
  WsConnectionStatus get currentStatus => _currentStatus;

  void _setStatus(WsConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void connect() {
    _isDisposed = false;
    _establishConnection();
  }

  Future<void> _establishConnection() async {
    if (_currentStatus == WsConnectionStatus.connecting || _currentStatus == WsConnectionStatus.connected) {
      return;
    }

    _setStatus(WsConnectionStatus.connecting);
    final token = await ApiClient.getToken();

    if (token == null || token.isEmpty) {
      _setStatus(WsConnectionStatus.disconnected);
      return;
    }

    try {
      final uri = Uri.parse(wsBaseUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _setStatus(WsConnectionStatus.authenticating);
      
      // First-Frame Authentication: Send token over WS message frame
      _channel!.sink.add(jsonEncode({
        "type": "AUTH",
        "token": token,
      }));

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            if (decoded["type"] == "AUTH_OK") {
              _setStatus(WsConnectionStatus.connected);
              _reconnectAttempts = 0; // Reset backoff on success
            } else {
              _messageController.add(decoded);
            }
          } catch (e) {
            debugPrint("WS parse error: $e");
          }
        },
        onError: (error) {
          debugPrint("WS error: $error");
          _handleDisconnect();
        },
        onDone: () {
          final closeCode = _channel?.closeCode;
          debugPrint("WS closed code: $closeCode, reason: ${_channel?.closeReason}");
          // Policy violation: stop retrying and clear auth
          if (closeCode == 1008) {
            _setStatus(WsConnectionStatus.disconnected);
            ApiClient.clearAuth();
            return;
          }
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint("WS connection failed: $e");
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _cleanup();
    _setStatus(WsConnectionStatus.disconnected);

    if (_isDisposed) return;

    final randomJitter = Random().nextInt(500);
    final delayMs = min(_baseDelayMs * pow(2, _reconnectAttempts) + randomJitter, _maxDelayMs).toInt();
    _reconnectAttempts++;

    debugPrint("Scheduling WS reconnect attempt $_reconnectAttempts in ${delayMs}ms");
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_isDisposed) {
        _establishConnection();
      }
    });
  }

  void send(Map<String, dynamic> data) {
    if (_currentStatus == WsConnectionStatus.connected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _cleanup();
    _messageController.close();
    _statusController.close();
  }
}
