import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/models/blockchain/blockchain.dart';

class TierBadge extends StatelessWidget {
  final MemberTier tier;
  final double size;

  const TierBadge({super.key, required this.tier, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(tier.color).withOpacity(0.9),
            Color(tier.color).withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(tier.color).withOpacity(0.3),
            spreadRadius: 4,
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, color: AppColors.surface, size: size * 0.4),
            const SizedBox(height: 4),
            Text(tier.name, style: TextStyle(color: AppColors.surface, fontSize: size * 0.15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}