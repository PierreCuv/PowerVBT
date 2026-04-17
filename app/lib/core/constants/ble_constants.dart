class BleConstants {
  // Device name (advertised by firmware)
  static const deviceName = 'PowerVBT';

  // Service UUID
  static const serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  // Characteristics
  static const liveVelocityCharUuid  = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const repCompletedCharUuid  = 'beb5483f-36e1-4688-b7f5-ea07361b26a8';
  static const deviceStatusCharUuid  = 'beb54840-36e1-4688-b7f5-ea07361b26a8';
  static const commandCharUuid       = 'beb54841-36e1-4688-b7f5-ea07361b26a8';

  // Commands (write to commandCharUuid)
  static const cmdStartSession  = 0x01;
  static const cmdStopSession   = 0x02;
  static const cmdCalibrate     = 0x03;

  // Packet sizes
  static const livePacketBytes = 3;   // int16 velocity + uint8 state
  static const repPacketBytes  = 12;  // full rep data

  // Rep states
  static const stateIdle        = 0;
  static const stateConcentric  = 1;
  static const stateEccentric   = 2;
}
