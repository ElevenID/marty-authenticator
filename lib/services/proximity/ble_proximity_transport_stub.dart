import 'dart:async';
import 'proximity_transport.dart';
import '../../utils/logger.dart';

/// Stub implementation of BleProximityTransport for platforms that don't support it
class BleProximityTransport implements ProximityTransport {
  final _eventController = StreamController<ProximityEvent>.broadcast();

  @override
  Stream<ProximityEvent> get events => _eventController.stream;

  @override
  Future<void> startAdvertising({String? serviceUuid}) async {
    Logger.warning('BleProximityTransport is not supported on this platform.');
  }

  @override
  Future<void> stopAdvertising() async {
    // No-op
  }

  @override
  Future<void> sendData(List<int> data) async {
    // No-op
  }

  @override
  Future<void> disconnect() async {
    // No-op
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
