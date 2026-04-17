import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class VelocityGauge extends StatelessWidget {
  final double velocity;
  const VelocityGauge({super.key, required this.velocity});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.velocityColor(velocity);
    final zone  = AppColors.velocityZoneLabel(velocity);
    final pct   = (velocity / 1.5).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Zone label
          Text(
            'VITESSE CONCENTRIQUE',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),

          // Big velocity number
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -2,
              height: 1,
            ),
            child: Text(velocity.toStringAsFixed(2)),
          ),
          Text('m/s', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 12),

          // Zone chip
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              zone,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0.0', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              Text('0.35', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              Text('0.50', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              Text('0.75', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
              Text('1.0+', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
