import 'dart:async';

import '../../utils/logger.dart';
import 'proximity_transport.dart';

/// Web/desktop fallback for the mobile-only BLE peripheral transport.
class BleProximityTransport implements ProximityTransport {
  final _events = StreamController<ProximityEvent>.broadcast();

  @override
  Stream<ProximityEvent> get events => _events.stream;

  @override
  Future<void> startAdvertising({String? serviceUuid}) async {
    Logger.warning(
      'BLE proximity presentation is unavailable on this platform.',
    );
  }

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<void> sendData(List<int> data) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() => _events.close();
}
