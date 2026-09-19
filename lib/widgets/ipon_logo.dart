import 'package:flutter/cupertino.dart';
import '../core/theme/app_theme.dart';

class IponLogo extends StatelessWidget {
  final double size;

  const IponLogo({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.heroGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.moneyGreen.withOpacity(0.35),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.02,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '₱', // ₱
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            color: CupertinoColors.black,
            height: 1,
          ),
        ),
      ),
    );
  }
}