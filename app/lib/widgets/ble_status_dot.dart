import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/ble_provider.dart';
import '../services/ble/ble_service.dart';

class BleStatusDot extends ConsumerWidget {
  const BleStatusDot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bleConnectionProvider).valueOrNull
        ?? BleConnectionState.disconnected;

    final (color, label) = switch (state) {
      BleConnectionState.connected    => (AppColors.green, 'Connecté'),
      BleConnectionState.connecting   => (AppColors.yellow, 'Connexion…'),
      BleConnectionState.scanning     => (AppColors.blue, 'Scan…'),
      BleConnectionState.disconnected => (AppColors.textMuted, 'Déconnecté'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulsingDot(color: color, pulse: state != BleConnectionState.disconnected),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _PulsingDot({required this.color, required this.pulse});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _anim = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color));
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}
