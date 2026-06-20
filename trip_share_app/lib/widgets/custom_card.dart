import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../theme/design_system.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final bool glass;

  const CustomCard({
    Key? key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.glass = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: glass ? DesignColors.surface.withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (!glass)
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: kIsWeb
          ? card
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: card,
            ),
    );
  }
}
