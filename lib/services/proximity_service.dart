import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import 'proximity/proximity_transport.dart';
import 'proximity/mock_proximity_transport.dart';
import 'proximity/ble_proximity_transport.dart'
    if (dart.library.js_interop) 'proximity/ble_proximity_transport_stub.dart';

/// Provider for the ProximityService
final proximityServiceProvider = Provider<ProximityService>((ref) {
  // Use Mock transport for Web (Chrome) and Desktop development
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    return ProximityService(MockProximityTransport());
  }

  // Use Real BLE transport for Mobile (Android & iOS)
  return ProximityService(BleProximityTransport());
});

/// Service to handle ISO 18013-5 proximity presentation
class ProximityService {
  final ProximityTransport _transport;
  StreamSubscription? _transportSubscription;

  ProximityService(this._transport);

  /// Initialize and start listening for proximity requests
  Future<void> startPresentation() async {
    _transportSubscription?.cancel();
    _transportSubscription = _transport.events.listen(_handleTransportEvent);

    // Start advertising mDL service
    await _transport.startAdvertising(
      serviceUuid: '000018013-0000-1000-8000-00805f9b34fb',
    );
  }

  /// Stop presentation
  Future<void> stopPresentation() async {
    await _transport.stopAdvertising();
    await _transportSubscription?.cancel();
    _transportSubscription = null;
  }

  void _handleTransportEvent(ProximityEvent event) {
    if (event is DeviceConnectedEvent) {
      Logger.info('ProximityService: Device connected: ${event.deviceId}');
      // TODO: Notify UI
    } else if (event is DataReceivedEvent) {
      Logger.info('ProximityService: Received ${event.data.length} bytes');
      _processRequest(event.data);
    } else if (event is DeviceDisconnectedEvent) {
      Logger.info('ProximityService: Device disconnected');
      // TODO: Notify UI
    } else if (event is TransportErrorEvent) {
      Logger.error('ProximityService: Error: ${event.message}');
    }
  }

  Future<void> _processRequest(Uint8List data) async {
    // TODO: Pass data to SpruceID SDK for processing
    // final response = await spruceSdk.processMdocRequest(data);

    // For now, just echo back a dummy response
    Logger.info('ProximityService: Processing request...');
    await Future.delayed(const Duration(milliseconds: 500));

    final dummyResponse = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
    await _transport.sendData(dummyResponse);
  }

  void dispose() {
    stopPresentation();
    _transport.dispose();
  }
}
