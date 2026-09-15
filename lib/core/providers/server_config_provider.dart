import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';

enum ConnectionStatus { initial, connecting, connected, disconnected }
class ServerConfig {
  final String baseUrl;
  final ConnectionStatus status;
  final String? errorMessage;

  const ServerConfig({
    this.baseUrl = '',
    this.status = ConnectionStatus.initial,
    this.errorMessage,
  });

  ServerConfig copyWith({
    String? baseUrl,
    ConnectionStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ServerConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isConnected => status == ConnectionStatus.connected;
}

class ServerConfigNotifier extends Notifier<ServerConfig> {
  static const _prefsKey = 'ipon_server_base_url';
  static const _pollInterval = Duration(seconds: 12);

  Timer? _pollTimer;

  @override
  ServerConfig build() {
    ref.onDispose(() => _pollTimer?.cancel());
    _restoreSavedUrl();
    return const ServerConfig();
  }

  Future<void> _restoreSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(baseUrl: saved);
    }
  }

  String _normalize(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
  Future<void> connect(String rawUrl) async {
    final url = _normalize(rawUrl);

    if (url.isEmpty) {
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        errorMessage: 'Please enter a server address.',
      );
      return;
    }

    state = state.copyWith(
      baseUrl: url,
      status: ConnectionStatus.connecting,
      clearError: true,
    );

    final result = await ApiClient.pingRaw(url);

    if (result.ok) {
      state = state.copyWith(status: ConnectionStatus.connected, clearError: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, url);
      _startPolling();
    } else {
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        errorMessage: result.message ?? 'Could not connect to the server.',
      );
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _silentHealthCheck());
  }

  Future<void> _silentHealthCheck() async {
    if (state.status != ConnectionStatus.connected) return;
    final result = await ApiClient.pingRaw(state.baseUrl);
    if (!result.ok) {
      _markDisconnected(result.message);
    }
  }
  void reportRequestFailure(String reason) {
    if (state.status == ConnectionStatus.connected) {
      _markDisconnected(reason);
    }
  }
  void _markDisconnected(String? reason) {
    _pollTimer?.cancel();
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      errorMessage: reason ?? 'Lost connection to the server.',
    );
  }
  void resetToEntry() {
    _pollTimer?.cancel();
    state = state.copyWith(status: ConnectionStatus.initial, clearError: true);
  }
}

final serverConfigProvider =
NotifierProvider<ServerConfigNotifier, ServerConfig>(ServerConfigNotifier.new);

final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(serverConfigProvider).status == ConnectionStatus.connected;
});