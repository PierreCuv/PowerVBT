import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import '../../models/rep.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected }

class LiveVelocityData {
  final double velocity;   // m/s
  final int    state;      // 0=idle, 1=concentric, 2=eccentric

  const LiveVelocityData({required this.velocity, required this.state});
}

class BleService {
  BleService._();
  static final instance = BleService._();

  // Controllers
  final _connectionState = StreamController<BleConnectionState>.broadcast();
  final _liveVelocity    = StreamController<LiveVelocityData>.broadcast();
  final _repCompleted    = StreamController<Rep>.broadcast();
  final _batteryLevel    = StreamController<int>.broadcast();

  // Exposed streams
  Stream<BleConnectionState> get connectionStream => _connectionState.stream;
  Stream<LiveVelocityData>   get liveVelocityStream => _liveVelocity.stream;
  Stream<Rep>                get repCompletedStream => _repCompleted.stream;
  Stream<int>                get batteryStream => _batteryLevel.stream;

  BluetoothDevice?        _device;
  BluetoothCharacteristic? _liveVelChar;
  BluetoothCharacteristic? _repChar;
  BluetoothCharacteristic? _cmdChar;
  StreamSubscription?      _scanSub;

  BleConnectionState _state = BleConnectionState.disconnected;
  BleConnectionState get state => _state;

  int? _currentSetId;
  int  _repCounter = 0;

  // ── Public API ────────────────────────────────────────────

  Future<void> startScan() async {
    if (_state != BleConnectionState.disconnected) return;
    _setState(BleConnectionState.scanning);

    await FlutterBluePlus.startScan(
      withServices: [Guid(BleConstants.serviceUuid)],
      timeout: const Duration(seconds: 10),
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (results.isNotEmpty) {
        final result = results.firstWhere(
          (r) => r.device.advName == BleConstants.deviceName,
          orElse: () => results.first,
        );
        FlutterBluePlus.stopScan();
        _connect(result.device);
      }
    });
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _cleanup();
  }

  Future<void> startSession(int setId) async {
    _currentSetId = setId;
    _repCounter   = 0;
    await _writeCommand(BleConstants.cmdStartSession);
  }

  Future<void> stopSession() async {
    await _writeCommand(BleConstants.cmdStopSession);
    _currentSetId = null;
    _repCounter   = 0;
  }

  Future<void> calibrate() async {
    await _writeCommand(BleConstants.cmdCalibrate);
  }

  // ── Internal ──────────────────────────────────────────────

  Future<void> _connect(BluetoothDevice device) async {
    _setState(BleConnectionState.connecting);
    _device = device;

    try {
      await device.connect(autoConnect: false);
      _setState(BleConnectionState.connected);
      await _discoverServices();

      device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _cleanup();
          // Auto-reconnect after 2s
          Future.delayed(const Duration(seconds: 2), startScan);
        }
      });
    } catch (e) {
      _cleanup();
    }
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;
    final services = await _device!.discoverServices();

    for (final service in services) {
      if (service.uuid.toString() != BleConstants.serviceUuid) continue;

      for (final char in service.characteristics) {
        final uuid = char.uuid.toString();

        if (uuid == BleConstants.liveVelocityCharUuid) {
          _liveVelChar = char;
          await char.setNotifyValue(true);
          char.onValueReceived.listen(_onLiveVelocity);
        }

        if (uuid == BleConstants.repCompletedCharUuid) {
          _repChar = char;
          await char.setNotifyValue(true);
          char.onValueReceived.listen(_onRepCompleted);
        }

        if (uuid == BleConstants.commandCharUuid) {
          _cmdChar = char;
        }

        if (uuid == BleConstants.deviceStatusCharUuid) {
          await char.setNotifyValue(true);
          char.onValueReceived.listen(_onDeviceStatus);
        }
      }
    }
  }

  void _onLiveVelocity(List<int> bytes) {
    if (bytes.length < BleConstants.livePacketBytes) return;
    // int16 velocity (×1000) + uint8 state
    final raw = ByteData.sublistView(Uint8List.fromList(bytes));
    final vel = raw.getInt16(0, Endian.little) / 1000.0;
    final state = bytes[2];
    _liveVelocity.add(LiveVelocityData(velocity: vel, state: state));
  }

  void _onRepCompleted(List<int> bytes) {
    if (bytes.length < BleConstants.repPacketBytes) return;
    if (_currentSetId == null) return;
    _repCounter++;
    final rep = Rep.fromBlePacket(bytes, _currentSetId!, _repCounter);
    _repCompleted.add(rep);
  }

  void _onDeviceStatus(List<int> bytes) {
    if (bytes.isEmpty) return;
    _batteryLevel.add(bytes[0]); // first byte = battery %
  }

  Future<void> _writeCommand(int cmd) async {
    await _cmdChar?.write([cmd], withoutResponse: false);
  }

  void _setState(BleConnectionState s) {
    _state = s;
    _connectionState.add(s);
  }

  void _cleanup() {
    _scanSub?.cancel();
    _scanSub = null;
    _device = null;
    _liveVelChar = null;
    _repChar = null;
    _cmdChar = null;
    _setState(BleConnectionState.disconnected);
  }

  void dispose() {
    _connectionState.close();
    _liveVelocity.close();
    _repCompleted.close();
    _batteryLevel.close();
  }
}
