import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class CustomButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool loading;
  final double borderRadius;
  final EdgeInsets padding;
  final Gradient? gradient;
  final Color? backgroundColor;
  final BoxBorder? border;
  final Color? textColor;

  const CustomButton({
    Key? key,
    required this.child,
    required this.onPressed,
    this.loading = false,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    this.gradient,
    this.backgroundColor,
    this.border,
    this.textColor,
  }) : super(key: key);

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null || widget.loading;
    final gradient =
        widget.gradient ??
        LinearGradient(colors: [DesignColors.primary, DesignColors.accent]);
    final bg = widget.backgroundColor;
    final textColor = widget.textColor ?? Colors.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.identity()..scale(_pressed ? 0.985 : 1.0),
        decoration: BoxDecoration(
          gradient: disabled ? null : (bg == null ? gradient : null),
          color: disabled ? Colors.grey.shade300 : (bg ?? null),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.border,
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: DesignColors.primary.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        padding: widget.padding,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: widget.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : DefaultTextStyle(
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    child: widget.child,
                  ),
          ),
        ),
      ),
    );
  }
}
