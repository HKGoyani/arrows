import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'audio.dart';
import 'config.dart';
import 'main.dart' show appKey;
import 'l10n.dart';
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
                    title: Tr.get('language'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Prefs.language, style: poppins(14, FontWeight.w800, AppColors.muted)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                      ],
                    ),
                    onTap: () => _showLanguage(context),
                  ),
                  _toggle(AudioService.vibrationOn, Icons.waves_rounded, AppColors.navInk,
                      Tr.get('vibrations'), null, AudioService.setVibration),
                  _toggle(AudioService.soundOn, Icons.volume_up_rounded, AppColors.navInk,
                      Tr.get('sounds'), null, AudioService.setSound),
                  _toggle(AudioService.musicOn, Icons.music_note_rounded, AppColors.navInk,
                      Tr.get('music'), null, AudioService.setMusic),
                  SettingsTile(
                    icon: Icons.dark_mode_rounded,
                    tint: AppColors.navInk,
                    title: Tr.get('darkMode'),
                    trailing: ThemeSwitch(
                      value: Prefs.darkMode,
                      onChanged: (v) {
                        Prefs.setDarkMode(v);
                        setState(() {});
                        appKey.currentState?.rebuildTheme();
                      },
                    ),
                    onTap: () {
                      Prefs.setDarkMode(!Prefs.darkMode);
                      setState(() {});
                      appKey.currentState?.rebuildTheme();
                    },
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
                title: Tr.get('accountConnection'),
                trailing: _comingSoon(),
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
                    title: Tr.get('removeAds'),
                    trailing: ThemeSwitch(
                      value: Prefs.removeAds,
                      onChanged: (v) { Prefs.setRemoveAds(v); setState(() {}); },
                    ),
                    onTap: () { Prefs.setRemoveAds(!Prefs.removeAds); setState(() {}); },
                  ),
                  SettingsTile(
                    icon: Icons.refresh_rounded,
                    tint: AppColors.navInk,
                    title: Tr.get('restorePurchases'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // How to play, Restore progress, Reset progress
            _SettingsCard(
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.menu_book_rounded,
                    tint: AppColors.navInk,
                    title: Tr.get('howToPlay'),
                    trailing: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    onTap: () => _howToPlay(context),
                  ),
                  SettingsTile(
                    icon: Icons.cloud_download_rounded,
                    tint: AppColors.navInk,
                    title: Tr.get('restoreProgress'),
                    trailing: _comingSoon(),
                  ),
                  SettingsTile(
                    icon: Icons.restart_alt_rounded,
                    tint: AppColors.navInk,
                    title: Tr.get('resetProgress'),
                    trailing: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
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
                    title: Tr.get('rateUs'),
                    onTap: () => _rateUs(context),
                  ),
                  SettingsTile(
                    icon: Icons.edit_rounded,
                    tint: AppColors.navInk,
                    title: Tr.get('writeUs'),
                    trailing: _comingSoon(),
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
                    title: Tr.get('privacy'),
                  ),
                  SettingsTile(
                    icon: Icons.info_outline_rounded,
                    tint: AppColors.navInk,
                    title: Tr.get('termsOfService'),
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



  static Widget _comingSoon() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.btnBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(Tr.get('comingSoon'),
        style: poppins(11, FontWeight.w800, AppColors.muted)),
  );

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

  static const _appStoreId = ''; // TODO: add App Store ID after publishing
  static const _playStoreId = 'com.shoolin.arrows_game';
  static const _supportEmail = 'akashmangukiya10@gmail.com';

  void _openStore() {
    final uri = Uri.parse(
      defaultTargetPlatform == TargetPlatform.iOS
          ? 'https://apps.apple.com/app/id$_appStoreId'
          : 'https://play.google.com/store/apps/details?id=$_playStoreId',
    );
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static const _languages = [
    'English', 'Deutsch', 'français', 'italiano', '日本語',
    '한국어', 'português (Brasil)', 'русский', 'español', 'Türkçe',
  ];

  void _showLanguage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selected = Prefs.language;
          return Dialog(
            backgroundColor: AppColors.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Tr.get('language'),
                      style: poppins(22, FontWeight.w900, AppColors.muted)),
                  const SizedBox(height: 14),
                  ...List.generate(_languages.length, (i) {
                    final lang = _languages[i];
                    final isSelected = lang == selected;
                    return Column(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Prefs.setLanguage(lang);
                            setDialogState(() {});
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(lang,
                                      style: poppins(16, FontWeight.w800,
                                          isSelected ? AppColors.blue : AppColors.ink)),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle,
                                      color: AppColors.blue, size: 24),
                              ],
                            ),
                          ),
                        ),
                        if (i < _languages.length - 1)
                          Divider(height: 1, thickness: 1, color: AppColors.cardBorder),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  Pressable(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.cardBorder, width: 1.5),
                      ),
                      child: Center(
                        child: Text(Tr.get('close'),
                            style: poppins(17, FontWeight.w800, AppColors.muted)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFeedback(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Tr.get('howCanWeImprove'),
                  style: poppins(22, FontWeight.w800, AppColors.ink)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: Tr.get('enterYourFeedback'),
                    hintStyle: poppins(14, FontWeight.w800, AppColors.muted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: poppins(14, FontWeight.w800, AppColors.ink),
                ),
              ),
              const SizedBox(height: 24),
              Pressable(
                onTap: () {
                  Navigator.pop(context);
                  if (controller.text.trim().isNotEmpty) {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: _supportEmail,
                      queryParameters: {
                        'subject': 'Arrow Escape Feedback',
                        'body': controller.text.trim(),
                      },
                    );
                    launchUrl(uri);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Text(Tr.get('submit'),
                        style: poppins(17, FontWeight.w800, Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Pressable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.cardBorder, width: 1),
                  ),
                  child: Center(
                    child: Text(Tr.get('cancel'),
                        style: poppins(16, FontWeight.w800, AppColors.muted)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _rateUs(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Tr.get('enjoyingArrows'),
                  style: poppins(22, FontWeight.w800, AppColors.ink)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.star_rounded, size: 42, color: Color(0xFFFFB800)),
                )),
              ),
              const SizedBox(height: 18),
              Text(Tr.get('rateMessage'),
                  textAlign: TextAlign.center,
                  style: poppins(14, FontWeight.w800, AppColors.muted, height: 1.4)),
              const SizedBox(height: 24),
              Pressable(
                onTap: () {
                  Navigator.pop(context);
                  _showFeedback(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.cardBorder, width: 1),
                  ),
                  child: Center(
                    child: Text(Tr.get('oneToFourStars'),
                        style: poppins(16, FontWeight.w800, AppColors.muted)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Pressable(
                onTap: () {
                  Navigator.pop(context);
                  _openStore();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Text(Tr.get('fiveStars'),
                        style: poppins(17, FontWeight.w800, Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Pressable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.cardBorder, width: 1),
                  ),
                  child: Center(
                    child: Text(Tr.get('close'),
                        style: poppins(16, FontWeight.w800, AppColors.muted)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _howToPlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(Tr.get('howToPlay'), style: poppins(20, FontWeight.w800, AppColors.ink)),
        content: Text(
          Tr.get('howToPlayText'),
          style: poppins(14, FontWeight.w800, AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Tr.get('gotIt'), style: poppins(15, FontWeight.w800, AppColors.blue)),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(Tr.get('resetProgressQuestion'), style: poppins(19, FontWeight.w800, AppColors.ink)),
        content: Text(
          Tr.get('resetWarning'),
          style: poppins(14, FontWeight.w800, AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Tr.get('cancel'), style: poppins(15, FontWeight.w800, AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              await Prefs.resetProgress();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(Tr.get('reset'), style: poppins(15, FontWeight.w800, AppColors.red)),
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
        color: AppColors.surface,
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
      Divider(height: 1, thickness: 1, color: AppColors.cardBorder, indent: 12, endIndent: 12);
}
