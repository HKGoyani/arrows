import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'ui_kit.dart';

const _appStoreId = '6785821757';
const _playStoreId = 'com.shayona.arrows';
const _supportEmail = 'akashmangukiya10@gmail.com';

/// Opens the platform store listing in the browser/store app. Used for
/// user-initiated "Rate us" taps (Settings), where the user explicitly asked
/// to rate so we must reliably take them somewhere.
void openAppStore() {
  final uri = Uri.parse(
    defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/app/id$_appStoreId'
        : 'https://play.google.com/store/apps/details?id=$_playStoreId',
  );
  launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Requests the native in-app review sheet (Apple SKStoreReviewController /
/// Google Play In-App Review). The OS throttles this — it may show nothing —
/// so only use it for passive, contextual prompts (e.g. after a win), never
/// for a button the user explicitly tapped. Falls back to the store listing
/// if the native flow isn't available.
Future<void> requestNativeReview() async {
  try {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    } else {
      openAppStore();
    }
  } catch (_) {
    openAppStore();
  }
}

/// The "Enjoying Arrows?" love-gate dialog. 1-4 stars always routes to the
/// feedback form; 5 stars runs [onFiveStars] — Settings passes [openAppStore]
/// (reliable, user-initiated), the after-win prompt passes [requestNativeReview]
/// (native in-app sheet, stays in the game).
Future<void> showRateDialog(BuildContext context,
    {required VoidCallback onFiveStars}) {
  return showDialog(
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
                showFeedbackDialog(context);
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
                onFiveStars();
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

/// Free-text feedback form that emails [_supportEmail]. Shown when a user
/// picks 1-4 stars in the rate dialog.
void showFeedbackDialog(BuildContext context) {
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

/// Decides when the after-win rate prompt may appear. Kept deliberately
/// conservative so the prompt only surfaces at genuine high points and never
/// nags: main-progression wins only, at least level 7, on a clean win (no
/// hearts lost), once per app session, spaced by 10 levels (no lifetime cap).
class RatePrompt {
  static bool _shownThisSession = false;
  static int _lastWinLevel = 0;
  static bool _lastWinClean = false;

  /// Called by the game screen when a main-progression level is won, recording
  /// the win so the navigation flow can decide whether to show the prompt.
  static void noteWin({required int level, required bool cleanWin}) {
    _lastWinLevel = level;
    _lastWinClean = cleanWin;
  }

  /// Whether the after-win prompt should show for the most recently noted win.
  /// Evaluated from the win-navigation flow only on the no-celebration path.
  static bool shouldShowForNotedWin() {
    if (_shownThisSession) return false;
    if (!_lastWinClean) return false; // only ask on a positive moment
    if (_lastWinLevel < 7) return false;
    // No lifetime cap: the prompt may recur (once per session, spaced ≥10
    // levels, clean wins only). Apple still throttles the native 5★ sheet
    // to ~3×/year on its own.
    if (Prefs.ratePromptCount > 0 &&
        _lastWinLevel - Prefs.ratePromptLastAtLevel < 10) {
      return false;
    }
    return true;
  }

  static void markShown() {
    _shownThisSession = true;
    Prefs.setRatePromptCount(Prefs.ratePromptCount + 1);
    Prefs.setRatePromptLastAtLevel(_lastWinLevel);
  }
}
