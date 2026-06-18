import 'dart:async';
import 'package:flutter/material.dart';
import 'config.dart';
import 'ui_kit.dart';
import 'widgets.dart';

/// Brief level-intro card shown before each level; auto-advances to play.
class IntroScreen extends StatefulWidget {
  final int level;
  final VoidCallback onStart;
  const IntroScreen({super.key, required this.level, required this.onStart});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1150), widget.onStart);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _difficulty =>
      widget.level < 4 ? 'Easy' : (widget.level < 6 ? 'Medium' : 'Hard');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _timer?.cancel();
        widget.onStart();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ArrowsWordmark(),
              const SizedBox(height: 14),
              Text('Level ${widget.level}',
                  style: poppins(24, FontWeight.w700, AppColors.blue)),
              const SizedBox(height: 4),
              Text(_difficulty, style: poppins(18, FontWeight.w700, AppColors.blueSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
