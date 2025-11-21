import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'proximity_transport.dart';
import '../../utils/logger.dart';

/// BLE implementation of ProximityTransport using flutter_ble_peripheral
class BleProximityTransport implements ProximityTransport {
  final _eventController = StreamController<ProximityEvent>.broadcast();
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  // ISO 18013-5 Service UUID
  static const String _mdlServiceUuid = '000018013-0000-1000-8000-00805f9b34fb';

  @override
  Stream<ProximityEvent> get events => _eventController.stream;

  @override
  Future<void> startAdvertising({String? serviceUuid}) async {
    final uuid = serviceUuid ?? _mdlServiceUuid;

    // Note: Ensure permissions (BLUETOOTH_ADVERTISE, BLUETOOTH_CONNECT) are granted before calling this.

    final AdvertiseData advertiseData = AdvertiseData(
      serviceUuid: uuid,
      includeDeviceName: true,
      localName: 'mDL Wallet',
    );

    final AdvertiseSettings advertiseSettings = AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeBalanced,
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
      connectable: true,
    );

    Logger.info('BleProximityTransport: Starting advertising for $uuid');
    await _blePeripheral.start(
      advertiseData: advertiseData,
      advertiseSettings: advertiseSettings,
    );

    // Listen for connection state changes
    _blePeripheral.onPeripheralStateChanged?.listen((state) {
      if (state == PeripheralState.connected) {
        _eventController.add(DeviceConnectedEvent('unknown-verifier'));
      } else if (state == PeripheralState.idle) {
        _eventController.add(DeviceDisconnectedEvent());
      }
    });

    // TODO: Setup GATT characteristics for ISO 18013-5
    // State Characteristic: 00000001-0000-1000-8000-00805f9b34fb
    // Client2Server Characteristic: 00000002-0000-1000-8000-00805f9b34fb
    // Server2Client Characteristic: 00000003-0000-1000-8000-00805f9b34fb
  }

  @override
  Future<void> stopAdvertising() async {
    await _blePeripheral.stop();
    Logger.info('BleProximityTransport: Stopped advertising');
  }

  @override
  Future<void> sendData(Uint8List data) async {
    // TODO: Write to Server2Client characteristic
    Logger.info(
      'BleProximityTransport: Sending ${data.length} bytes (Mock implementation for now)',
    );
  }

  @override
  Future<void> disconnect() async {
    await _blePeripheral.stop();
    _eventController.add(DeviceDisconnectedEvent());
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
