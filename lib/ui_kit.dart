import 'package:flutter/material.dart';
import 'config.dart';
import 'l10n.dart';

TextStyle poppins(double size, FontWeight w, Color c, {double? ls, double? height}) =>
    TextStyle(
        fontFamily: 'Area',
        fontFamilyFallback: const ['Poppins'],
        fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: height);

/// Faint dot-grid backdrop (echoes the game board) for menu screens.
class DotGridPainter extends CustomPainter {
  final bool isDark;
  const DotGridPainter({this.isDark = false});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.dot.withValues(alpha: 0.55);
    const gap = 34.0;
    for (double x = gap; x < size.width; x += gap) {
      for (double y = gap; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 2.0, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter old) => old.isDark != isDark;
}

/// Scales down briefly while pressed.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Alignment alignment;
  const Pressable({super.key, required this.child, required this.onTap, this.alignment = Alignment.center});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  double _s = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _s = 0.95),
      onTapCancel: () => setState(() => _s = 1),
      onTapUp: (_) => setState(() => _s = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _s,
        alignment: widget.alignment,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color color;
  final double width;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = AppColors.blue,
    this.width = 240,
  });
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
            ],
            Text(label, style: poppins(22, FontWeight.w900, Colors.white).copyWith(
              shadows: [const Shadow(color: Colors.white, blurRadius: 1)],
            )),
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(8)});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0A111430), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  const StatCard(
      {super.key,
      required this.icon,
      required this.tint,
      required this.value,
      required this.label});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, color: tint, size: 24),
          ),
          const SizedBox(height: 10),
          Text(value, style: poppins(22, FontWeight.w800, AppColors.ink)),
          const SizedBox(height: 2),
          Text(label, style: poppins(12, FontWeight.w800, AppColors.muted)),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
        child: Text(text.toUpperCase(),
            style: poppins(12, FontWeight.w800, AppColors.muted, ls: 1.2)),
      );
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const SettingsTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: tint, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: poppins(15.5, FontWeight.w800, AppColors.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: poppins(12.5, FontWeight.w800, AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Custom rounded toggle in theme colors.
class ThemeSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const ThemeSwitch({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.blue : AppColors.heartEmpty,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  final int index;
  final int level;
  final bool showCollectionBadge;
  final bool showChallengeBadge;
  final ValueChanged<int> onTap;
  const AppBottomNav({
    super.key,
    required this.index,
    required this.level,
    required this.onTap,
    this.showCollectionBadge = false,
    this.showChallengeBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final collectionUnlocked = level >= 10;
    final level20Unlocked = level >= 20;
    final items = [
      (Icons.home_rounded, Tr.get('home'), true),
      (level20Unlocked ? Icons.calendar_month_rounded : Icons.lock_rounded,
          level20Unlocked ? Tr.get('challenge') : 'Level 20', level20Unlocked),
      (collectionUnlocked ? Icons.hotel_class : Icons.lock_rounded,
          collectionUnlocked ? Tr.get('collection') : 'Level 10', collectionUnlocked),
      (Icons.settings_rounded, Tr.get('settings'), true),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBg,
        boxShadow: [BoxShadow(color: Color(0x0A111430), blurRadius: 14, offset: Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == index;
          final unlocked = items[i].$3;
          final color = !unlocked
              ? AppColors.lock
              : active
                  ? AppColors.navInk
                  : AppColors.navInk.withValues(alpha: 0.6);
          return Pressable(
            onTap: () {
              if (unlocked) onTap(i);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: active && unlocked ? AppColors.navPill : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(items[i].$1, size: 28, color: color),
                      if ((i == 2 && collectionUnlocked && showCollectionBadge) ||
                          (i == 1 && level20Unlocked && showChallengeBadge))
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(items[i].$2, style: poppins(12, FontWeight.w800, color)),
              ],
            ),
          );
        }),
      ),
    );
  }
}
