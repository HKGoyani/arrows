import 'package:flutter/material.dart';
import 'audio.dart';
import 'config.dart';
import 'prefs.dart';
import 'ui_kit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 18),
              child: Text('Settings', style: poppins(26, FontWeight.w800, AppColors.ink)),
            ),
            const SectionLabel('Audio & Haptics'),
            AppCard(
              child: Column(
                children: [
                  _toggle(AudioService.soundOn, Icons.volume_up_rounded, AppColors.blue,
                      'Sound effects', 'Tap, clash & win sounds', AudioService.setSound),
                  const _Divider(),
                  _toggle(AudioService.musicOn, Icons.music_note_rounded, AppColors.lavender,
                      'Music', 'Background music', AudioService.setMusic),
                  const _Divider(),
                  _toggle(AudioService.vibrationOn, Icons.vibration_rounded, AppColors.flame,
                      'Vibration', 'Haptic feedback', AudioService.setVibration),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Game'),
            AppCard(
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.menu_book_rounded,
                    tint: AppColors.blueSoft,
                    title: 'How to play',
                    subtitle: 'Quick rules',
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    onTap: () => _howToPlay(context),
                  ),
                  const _Divider(),
                  SettingsTile(
                    icon: Icons.restart_alt_rounded,
                    tint: AppColors.red,
                    title: 'Reset progress',
                    subtitle: 'Back to Level 1 & clear streak',
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    onTap: () => _confirmReset(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('About'),
            AppCard(
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.info_rounded,
                    tint: AppColors.navInk,
                    title: 'Arrows',
                    subtitle: 'Version 1.0.0',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text('Made with ♥ · Arrows',
                  style: poppins(12, FontWeight.w500, AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(ValueNotifier<bool> n, IconData icon, Color tint, String title,
      String subtitle, Future<void> Function(bool) setter) {
    return ValueListenableBuilder<bool>(
      valueListenable: n,
      builder: (_, v, __) => SettingsTile(
        icon: icon,
        tint: tint,
        title: title,
        subtitle: subtitle,
        trailing: ThemeSwitch(value: v, onChanged: (x) => setter(x)),
        onTap: () => setter(!v),
      ),
    );
  }

  void _howToPlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('How to play', style: poppins(20, FontWeight.w800, AppColors.ink)),
        content: Text(
          'Tap an arrow to fire it off the board.\n\n'
          '• If its path to the edge is clear, it flies off.\n'
          '• If it is blocked, it turns red and you lose a life.\n'
          '• You have 3 lives. Clear the whole board to win.\n\n'
          'Boards get bigger and busier as you level up.',
          style: poppins(14, FontWeight.w500, AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: poppins(15, FontWeight.w700, AppColors.blue)),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Reset progress?', style: poppins(19, FontWeight.w800, AppColors.ink)),
        content: Text(
          'This clears your level and streak. This cannot be undone.',
          style: poppins(14, FontWeight.w500, AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: poppins(15, FontWeight.w700, AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              await Prefs.resetProgress();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Reset', style: poppins(15, FontWeight.w700, AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.cardBorder, indent: 12, endIndent: 12);
}
