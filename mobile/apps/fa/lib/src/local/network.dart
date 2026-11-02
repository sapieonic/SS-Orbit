// Online / Wi-Fi state as the offline engine sees it. Pure Dart (the
// Riverpod provider is in device/connectivity.dart, which re-exports this).

import 'dart:async';

/// Whether the phone has a network, and whether it is Wi-Fi.
///
/// Being "online" only means a network is up; the engine still treats a
/// failed call as offline. A connectivity_plus implementation replaces the
/// mock when the real API lands.
abstract interface class ConnectivityService {
  /// A network is up.
  bool get isOnline;

  /// The network is Wi-Fi (for "Upload photos on Wi-Fi only").
  bool get isOnWifi;

  /// Fires [isOnline] each time the network changes: it went up or down,
  /// or moved between Wi-Fi and mobile data ([isOnWifi]).
  Stream<bool> get changes;
}

/// [ConnectivityService] driven by hand: by the mock scenario in the app, by
/// tests directly.
final class MockConnectivityService implements ConnectivityService {
  /// Starts [online] and on Wi-Fi when [wifi].
  MockConnectivityService({this._online = true, this._wifi = true});

  bool _online;
  bool _wifi;
  final _changes = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _online;

  @override
  bool get isOnWifi => _online && _wifi;

  @override
  Stream<bool> get changes => _changes.stream;

  /// Goes online or offline (fires [changes] when it differs).
  void setOnline(bool online) {
    if (online == _online) return;
    _online = online;
    _changes.add(online);
  }

  /// Switches between Wi-Fi and mobile data (fires [changes] when online
  /// and it differs).
  void setWifi(bool wifi) {
    if (wifi == _wifi) return;
    _wifi = wifi;
    if (_online) _changes.add(_online);
  }

  /// Closes [changes].
  Future<void> dispose() => _changes.close();
}
