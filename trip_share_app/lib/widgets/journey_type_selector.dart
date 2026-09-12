import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:trip_share_app/theme/design_system.dart';

class JourneyTypeSelector extends StatefulWidget {
  final int selectedIndex;
  final int activeCount;
  final int idleCount;
  final ValueChanged<int> onChanged;

  static const String _activeImageUrl =
      'https://images.unsplash.com/photo-1770563181870-eca60076ffd8'
      '?auto=format&fit=crop&w=900&q=82';
  static const String _idleImageUrl =
      'https://images.unsplash.com/photo-1547730230-b27e72b46d53'
      '?auto=format&fit=crop&w=900&q=82';

  const JourneyTypeSelector({
    super.key,
    required this.selectedIndex,
    required this.activeCount,
    required this.idleCount,
    required this.onChanged,
  });

  @override
  State<JourneyTypeSelector> createState() => _JourneyTypeSelectorState();
}

class _JourneyTypeSelectorState extends State<JourneyTypeSelector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;
  int _flowDirection = 1;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void didUpdateWidget(covariant JourneyTypeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _flowDirection = widget.selectedIndex > oldWidget.selectedIndex ? 1 : -1;
      _flowController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 154,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: DesignColors.primaryDark.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _JourneyPanel(
                      title: 'Active Tours',
                      subtitle: 'Confirmed dates with travellers ready',
                      count: widget.activeCount,
                      imageUrl: JourneyTypeSelector._activeImageUrl,
                      selected: widget.selectedIndex == 0,
                      imageAlignment: Alignment.centerLeft,
                      contentAlignment: CrossAxisAlignment.start,
                      onTap: () => widget.onChanged(0),
                    ),
                  ),
                  Expanded(
                    child: _JourneyPanel(
                      title: 'Idle Tours ✦',
                      subtitle: 'Pick a tour and choose your own date',
                      count: widget.idleCount,
                      imageUrl: JourneyTypeSelector._idleImageUrl,
                      selected: widget.selectedIndex == 1,
                      imageAlignment: Alignment.centerRight,
                      contentAlignment: CrossAxisAlignment.end,
                      onTap: () => widget.onChanged(1),
                    ),
                  ),
                ],
              ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flowController,
                  builder: (context, _) => CustomPaint(
                    painter: _ColorFlowPainter(
                      progress: Curves.easeInOutCubic.transform(
                        _flowController.value,
                      ),
                      direction: _flowDirection,
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 460),
                  curve: Curves.easeInOutCubicEmphasized,
                  alignment: widget.selectedIndex == 0
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: const Color(
                            0xFFFFD18B,
                          ).withValues(alpha: 0.72),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: DesignColors.primaryLight.withValues(
                              alpha: 0.15,
                            ),
                            blurRadius: 13,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const IgnorePointer(child: CustomPaint(painter: _RiverDivider())),
              Center(
                child: Semantics(
                  button: true,
                  label: widget.selectedIndex == 0
                      ? 'Show idle tours'
                      : 'Show active tours',
                  child: GestureDetector(
                    onTap: () =>
                        widget.onChanged(widget.selectedIndex == 0 ? 1 : 0),
                    child: AnimatedBuilder(
                      animation: _flowController,
                      builder: (context, child) {
                        final pulse =
                            1 - ((_flowController.value * 2) - 1).abs();
                        return Transform.scale(
                          scale: 1 + (pulse * 0.06),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DesignColors.primaryLight,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: DesignColors.primaryLight.withValues(
                                alpha: 0.38,
                              ),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: AnimatedRotation(
                          turns: widget.selectedIndex == 0 ? 0 : 0.5,
                          duration: const Duration(milliseconds: 460),
                          curve: Curves.easeInOutBack,
                          child: const Icon(
                            Icons.explore_rounded,
                            color: DesignColors.primaryDark,
                            size: 29,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorFlowPainter extends CustomPainter {
  final double progress;
  final int direction;

  const _ColorFlowPainter({required this.progress, required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final travel = size.width * 1.5;
    final centerX = direction > 0
        ? -size.width * 0.25 + (travel * progress)
        : size.width * 1.25 - (travel * progress);
    final bandWidth = size.width * 0.52;
    final rect = Rect.fromLTWH(
      centerX - bandWidth / 2,
      0,
      bandWidth,
      size.height,
    );
    final intensity = 1 - ((progress - 0.5).abs() * 0.65);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            const Color(0xFFFFD18B).withValues(alpha: 0.07 * intensity),
            const Color(0xFFFFF4DF).withValues(alpha: 0.17 * intensity),
            const Color(0xFFC88A52).withValues(alpha: 0.08 * intensity),
            Colors.transparent,
          ],
          stops: const [0, 0.22, 0.5, 0.78, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _ColorFlowPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        direction != oldDelegate.direction;
  }
}

class _JourneyPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final String imageUrl;
  final bool selected;
  final Alignment imageAlignment;
  final CrossAxisAlignment contentAlignment;
  final VoidCallback onTap;

  const _JourneyPanel({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.imageUrl,
    required this.selected,
    required this.imageAlignment,
    required this.contentAlignment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final alignLeft = contentAlignment == CrossAxisAlignment.start;

    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $count available',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _JourneyImage(url: imageUrl, alignment: imageAlignment),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: alignLeft
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  end: alignLeft ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    const Color(0xE6352418),
                    const Color(0xA832241A),
                    const Color(0x382C2018),
                  ],
                  stops: const [0, 0.68, 1],
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              decoration: BoxDecoration(
                color: selected
                    ? DesignColors.primaryLight.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.16),
                border: Border(
                  top: BorderSide(
                    color: selected
                        ? DesignColors.primaryLight
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                alignLeft ? 15 : 30,
                14,
                alignLeft ? 30 : 15,
                12,
              ),
              child: Column(
                crossAxisAlignment: contentAlignment,
                children: [
                  Row(
                    mainAxisAlignment: alignLeft
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.end,
                    children: [
                      if (selected) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD18B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.15,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    textAlign: alignLeft ? TextAlign.left : TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 32,
                    padding: const EdgeInsets.only(left: 13, right: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFFF3DF)
                          : Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$count',
                          style: const TextStyle(
                            color: DesignColors.primaryDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          width: 21,
                          height: 21,
                          decoration: BoxDecoration(
                            color: DesignColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: DesignColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyImage extends StatelessWidget {
  final String url;
  final Alignment alignment;

  const _JourneyImage({required this.url, required this.alignment});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: alignment,
      placeholder: (_, _) => _fallback(),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Image.asset(
      'assets/bg.jpg',
      fit: BoxFit.cover,
      alignment: alignment,
    );
  }
}

class _RiverDivider extends CustomPainter {
  const _RiverDivider();

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final path = Path()
      ..moveTo(centerX - 17, -4)
      ..cubicTo(
        centerX + 30,
        size.height * 0.25,
        centerX - 30,
        size.height * 0.70,
        centerX + 18,
        size.height + 4,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFE7BF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RiverDivider oldDelegate) => false;
}
