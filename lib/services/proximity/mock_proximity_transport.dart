import 'dart:async';
import 'dart:typed_data';
import 'proximity_transport.dart';
import '../../utils/logger.dart';

/// Mock implementation of ProximityTransport for testing without devices
class MockProximityTransport implements ProximityTransport {
  final _eventController = StreamController<ProximityEvent>.broadcast();
  Timer? _simulationTimer;
  bool _isAdvertising = false;

  @override
  Stream<ProximityEvent> get events => _eventController.stream;

  @override
  Future<void> startAdvertising({String? serviceUuid}) async {
    if (_isAdvertising) return;
    _isAdvertising = true;
    Logger.info('MockProximityTransport: Started advertising...');

    // Simulate a Verifier connecting after 2 seconds
    _simulationTimer = Timer(const Duration(seconds: 2), () {
      if (!_isAdvertising) return;
      Logger.info('MockProximityTransport: Device connected');
      _eventController.add(DeviceConnectedEvent('mock-verifier-id'));

      // Simulate receiving a request after connection (another 1 second)
      Timer(const Duration(seconds: 1), () {
        if (!_isAdvertising) return;
        Logger.info('MockProximityTransport: Received mock request data');
        // Mock mDoc request bytes (just dummy data for now)
        final mockRequest = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
        _eventController.add(DataReceivedEvent(mockRequest));
      });
    });
  }

  @override
  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    _simulationTimer?.cancel();
    Logger.info('MockProximityTransport: Stopped advertising');
  }

  @override
  Future<void> sendData(Uint8List data) async {
    Logger.info(
      'MockProximityTransport: Sending ${data.length} bytes to verifier',
    );
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    Logger.info('MockProximityTransport: Data sent successfully');
  }

  @override
  Future<void> disconnect() async {
    _simulationTimer?.cancel();
    _eventController.add(DeviceDisconnectedEvent());
    Logger.info('MockProximityTransport: Disconnected');
  }

  @override
  void dispose() {
    _eventController.close();
    _simulationTimer?.cancel();
  }
}
