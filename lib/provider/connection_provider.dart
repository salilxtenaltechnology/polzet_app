// lib/provider/connection_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

enum ConnectionStatus { unknown, online, offline, serverDown }

class ServerMonitor {
  static final StreamController<bool> _serverDownController =
      StreamController<bool>.broadcast();
  static Stream<bool> get onServerDown => _serverDownController.stream;

  static void reportServerDown() {
    _serverDownController.add(true);
  }
}

class ConnectivityProvider extends ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.unknown;
  bool _isInitialized = false;
  Timer? _pollingTimer;

  bool get isOnline => _status == ConnectionStatus.online;
  bool get isOffline => _status == ConnectionStatus.offline;
  bool get isServerDown => _status == ConnectionStatus.serverDown;
  bool get isInitialized => _isInitialized;
  bool get hasConnection => isOnline;
  ConnectionStatus get status => _status;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    await _check();
    _startPolling();

    ServerMonitor.onServerDown.listen((_) {
      _updateStatus(ConnectionStatus.serverDown);
    });
  }

  bool _isChecking = false;

  Future<void> _check({bool isManualRetry = false}) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final hasInternet = await _checkInternet();

      if (!hasInternet) {
        _updateStatus(ConnectionStatus.offline);
      } else {
        // If we have internet, assume online.
        // Server down should only be triggered by API interceptors, not by polling google.com.
        if (_status != ConnectionStatus.serverDown || isManualRetry) {
          _updateStatus(ConnectionStatus.online);
        }
      }

      if (!_isInitialized) {
        _isInitialized = true;
        notifyListeners();
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 10));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on TimeoutException catch (_) {
      // If it times out, the network is likely just slow.
      // We return true to prevent the "No Internet" bottom sheet from showing.
      return true;
    } on SocketException catch (_) {
      // Socket exception indicates actual lack of connection or DNS failure.
      return false;
    } catch (_) {
      return false;
    }
  }

  void _updateStatus(ConnectionStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
    if (_isInitialized) _restartPolling();
  }

  void _restartPolling() {
    _pollingTimer?.cancel();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    final seconds = isOnline ? 10 : 4;
    _pollingTimer = Timer.periodic(Duration(seconds: seconds), (_) => _check());
  }

  Future<void> retryNow() async => _check(isManualRetry: true);

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
