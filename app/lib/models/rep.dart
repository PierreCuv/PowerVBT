class Rep {
  final int?   id;
  final int    setId;
  final int    repIndex;
  final double peakVelocity;    // m/s
  final double meanVelocity;    // m/s
  final int    tutMs;           // time under tension (ms)
  final int    tempoConcentricMs;
  final int    tempoEccentricMs;
  final bool   isManual;

  const Rep({
    this.id,
    required this.setId,
    required this.repIndex,
    required this.peakVelocity,
    required this.meanVelocity,
    required this.tutMs,
    this.tempoConcentricMs = 0,
    this.tempoEccentricMs  = 0,
    this.isManual = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'set_id': setId,
    'rep_index': repIndex,
    'peak_velocity': peakVelocity,
    'mean_velocity': meanVelocity,
    'tut_ms': tutMs,
    'tempo_concentric_ms': tempoConcentricMs,
    'tempo_eccentric_ms': tempoEccentricMs,
    'is_manual': isManual ? 1 : 0,
  };

  factory Rep.fromMap(Map<String, dynamic> map) => Rep(
    id: map['id'],
    setId: map['set_id'],
    repIndex: map['rep_index'],
    peakVelocity: map['peak_velocity'],
    meanVelocity: map['mean_velocity'],
    tutMs: map['tut_ms'],
    tempoConcentricMs: map['tempo_concentric_ms'] ?? 0,
    tempoEccentricMs: map['tempo_eccentric_ms'] ?? 0,
    isManual: map['is_manual'] == 1,
  );

  // Factory from BLE packet (12 bytes)
  factory Rep.fromBlePacket(List<int> bytes, int setId, int repIndex) {
    if (bytes.length < 12) throw Exception('Invalid BLE packet size');
    int peakRaw  = bytes[2] | (bytes[3] << 8);
    int meanRaw  = bytes[4] | (bytes[5] << 8);
    int tutRaw   = bytes[6] | (bytes[7] << 8);
    int concRaw  = bytes[8] | (bytes[9] << 8);
    int eccRaw   = bytes[10] | (bytes[11] << 8);
    return Rep(
      setId: setId,
      repIndex: repIndex,
      peakVelocity: peakRaw / 1000.0,
      meanVelocity: meanRaw / 1000.0,
      tutMs: tutRaw,
      tempoConcentricMs: concRaw,
      tempoEccentricMs: eccRaw,
    );
  }
}
