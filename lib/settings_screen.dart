import 'package:flutter/material.dart';
import 'audio.dart';
import 'config.dart';
import 'prefs.dart';
import 'ui_kit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language, Vibrations, Sounds, Dark mode
            _SettingsCard(
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.language_rounded,
                    tint: AppColors.navInk,
                    title: 'Language',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('English', style: poppins(14, FontWeight.w500, AppColors.muted)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                      ],
                    ),
                  ),
                  const _Divider(),
                  _toggle(AudioService.vibrationOn, Icons.waves_rounded, AppColors.navInk,
                      'Vibrations', null, AudioService.setVibration),
                  const _Divider(),
                  _toggle(AudioService.soundOn, Icons.volume_up_rounded, AppColors.navInk,
                      'Sounds', null, AudioService.setSound),
                  const _Divider(),
                  _toggle(AudioService.musicOn, Icons.music_note_rounded, AppColors.navInk,
                      'Music', null, AudioService.setMusic),
                  const _Divider(),
                  SettingsTile(
                    icon: Icons.dark_mode_rounded,
                    tint: AppColors.navInk,
                    title: 'Dark mode',
                    trailing: ThemeSwitch(
                      value: Prefs.darkMode,
                      onChanged: (v) { Prefs.setDarkMode(v); setState(() {}); },
                    ),
                    onTap: () { Prefs.setDarkMode(!Prefs.darkMode); setState(() {}); },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Account Connection
            _SettingsCard(
              child: SettingsTile(
                icon: Icons.person_rounded,
                tint: AppColors.navInk,
                title: 'Account Connection',
                trailing: ThemeSwitch(
                  value: Prefs.accountConnection,
                  onChanged: (v) { Prefs.setAccountConnection(v); setState(() {}); },
                ),
                onTap: () { Prefs.setAccountConnection(!Prefs.accountConnection); setState(() {}); },
              ),
            ),
            const SizedBox(height: 16),
            // Remove Ads, Restore purchases
            _SettingsCard(
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.block_rounded,
                    tint: AppColors.navInk,
                    title: 'Remove Ads',
                    trailing: ThemeSwitch(
                      value: Prefs.removeAds,
                      onChanged: (v) { Prefs.setRemoveAds(v); setState(() {}); },
                    ),
                    onTap: () { Prefs.setRemoveAds(!Prefs.removeAds); setState(() {}); },
                  ),
                  const _Divider(),
                  SettingsTile(
                    icon: Icons.refresh_rounded,
                    tint: AppColors.navInk,
                    title: 'Restore purchases',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // How to play, Reset progress
            _SettingsCard(
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.menu_book_rounded,
                    tint: AppColors.navInk,
                    title: 'How to play',
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    onTap: () => _howToPlay(context),
                  ),
                  const _Divider(),
                  SettingsTile(
                    icon: Icons.restart_alt_rounded,
                    tint: AppColors.navInk,
                    title: 'Reset progress',
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    onTap: () => _confirmReset(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Rate us, Write us
            _SettingsCard(
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.star_rounded,
                    tint: AppColors.navInk,
                    title: 'Rate us',
                  ),
                  const _Divider(),
                  SettingsTile(
                    icon: Icons.edit_rounded,
                    tint: AppColors.navInk,
                    title: 'Write us',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Privacy, Terms
            _SettingsCard(
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.description_rounded,
                    tint: AppColors.navInk,
                    title: 'Privacy',
                  ),
                  const _Divider(),
                  SettingsTile(
                    icon: Icons.info_outline_rounded,
                    tint: AppColors.navInk,
                    title: 'Terms of Service',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }



  Widget _toggle(ValueNotifier<bool> n, IconData icon, Color tint, String title,
      String? subtitle, Future<void> Function(bool) setter) {
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

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.cardBorder, indent: 12, endIndent: 12);
}
