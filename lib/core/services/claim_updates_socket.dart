import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Parses server-sent claim events from an already-authenticated WebSocket.
/// The caller must establish auth with its backend's supported mechanism; do
/// not put long-lived bearer tokens in the WebSocket URL.
class ClaimUpdatesSocket {
  ClaimUpdatesSocket(this._channel);

  final WebSocketChannel _channel;

  Stream<Map<String, dynamic>> get events => _channel.stream
      .map((frame) => jsonDecode(frame.toString()))
      .where((decoded) => decoded is Map<String, dynamic>)
      .cast<Map<String, dynamic>>();

  void sendAcknowledgement(String eventId) {
    _channel.sink.add(jsonEncode({'type': 'ack', 'eventId': eventId}));
  }

  Future<void> close() => _channel.sink.close();
}
