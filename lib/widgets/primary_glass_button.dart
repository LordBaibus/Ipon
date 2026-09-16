import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class PrimaryGlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  const PrimaryGlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = isLoading || onPressed == null;

    return SizedBox(
      width: double.infinity,
      child: GlassButton.custom(
        onTap: isDisabled ? () {} : onPressed!,
        enabled: !isDisabled,
        width: double.infinity,
        height: height,
        shape: const LiquidRoundedSuperellipse(borderRadius: 14),
        child: isLoading
            ? const GlassProgressIndicator.circular(size: 20)
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: CupertinoColors.white),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubtleGlassLink extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const SubtleGlassLink({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CupertinoColors.activeBlue,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}