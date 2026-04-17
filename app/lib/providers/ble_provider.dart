import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble/ble_service.dart';
import '../models/rep.dart';

// Connection state
final bleConnectionProvider = StreamProvider<BleConnectionState>((ref) {
  return BleService.instance.connectionStream;
});

// Live velocity
final liveVelocityProvider = StreamProvider<LiveVelocityData>((ref) {
  return BleService.instance.liveVelocityStream;
});

// Rep completed events
final repCompletedProvider = StreamProvider<Rep>((ref) {
  return BleService.instance.repCompletedStream;
});

// Battery level
final batteryLevelProvider = StreamProvider<int>((ref) {
  return BleService.instance.batteryStream;
});
