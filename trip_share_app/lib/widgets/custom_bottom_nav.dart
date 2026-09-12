import 'package:flutter/material.dart';
import 'package:trip_share_app/theme/design_system.dart';

/// Floating navigation used by the main customer shell.
///
/// The middle action is kept separate from the four regular destinations so it
/// can sit above the navigation surface without squeezing or overflowing its
/// label row.
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 82,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: DesignColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: DesignColors.primaryDark.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        selected: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chats',
                        selected: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                    ),
                    const SizedBox(width: 70),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.luggage_outlined,
                        label: 'Bookings',
                        selected: currentIndex == 3,
                        onTap: () => onTap(3),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Profile',
                        selected: currentIndex == 4,
                        onTap: () => onTap(4),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                child: Semantics(
                  button: true,
                  selected: currentIndex == 2,
                  label: 'Offer a ride',
                  child: GestureDetector(
                    onTap: onCenterTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            DesignColors.primary,
                            DesignColors.primaryDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: DesignColors.surface,
                          width: 5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: DesignColors.primaryDark.withValues(
                              alpha: currentIndex == 2 ? 0.42 : 0.30,
                            ),
                            blurRadius: currentIndex == 2 ? 18 : 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_road_rounded,
                        color: Colors.white,
                        size: 28,
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected
                  ? DesignColors.primary
                  : DesignColors.textTertiary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? DesignColors.primary
                    : DesignColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
