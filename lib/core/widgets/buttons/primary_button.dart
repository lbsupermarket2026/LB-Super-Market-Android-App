import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  // NEW: both optional and default to the previous plain look — every
  // existing call site (signup, checkout, etc.) that doesn't pass
  // these is completely unaffected by this change.
  final List<Color>? gradientColors;
  final IconData? trailingIcon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.gradientColors,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 18, color: Colors.white),
              ],
            ],
          );

    if (gradientColors == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      );
    }

    // Gradient variant — ElevatedButton doesn't support a gradient
    // background directly, so this wraps a transparent ElevatedButton
    // in a gradient-decorated Container instead, keeping the same
    // ripple/disabled behavior.
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors!, begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: child,
        ),
      ),
    );
  }
}
