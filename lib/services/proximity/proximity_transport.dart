import 'dart:async';
import 'dart:typed_data';

/// Base class for proximity transport events
abstract class ProximityEvent {}

/// Event triggered when a remote device (Verifier) connects
class DeviceConnectedEvent extends ProximityEvent {
  final String deviceId;
  DeviceConnectedEvent(this.deviceId);
}

/// Event triggered when a remote device disconnects
class DeviceDisconnectedEvent extends ProximityEvent {}

/// Event triggered when data is received from the remote device
class DataReceivedEvent extends ProximityEvent {
  final Uint8List data;
  DataReceivedEvent(this.data);
}

/// Event triggered when an error occurs
class TransportErrorEvent extends ProximityEvent {
  final String message;
  final dynamic error;
  TransportErrorEvent(this.message, [this.error]);
}

/// Abstract interface for ISO 18013-5 proximity transport (BLE, NFC, etc.)
abstract class ProximityTransport {
  /// Stream of events from the transport layer
  Stream<ProximityEvent> get events;

  /// Start advertising/listening for connections
  /// [serviceUuid] is the UUID to advertise (e.g. for mDL)
  Future<void> startAdvertising({String? serviceUuid});

  /// Stop advertising/listening
  Future<void> stopAdvertising();

  /// Send data to the connected remote device
  Future<void> sendData(Uint8List data);

  /// Disconnect from the remote device
  Future<void> disconnect();

  /// Dispose resources
  void dispose();
}
