import 'dart:async';
import 'package:flutter/foundation.dart';

enum RunStatus { playing, won, lost }

class DungeonGameState {
  DungeonGameState({this.maxHp = 100}) : hp = ValueNotifier(maxHp);

  final int maxHp;
  final ValueNotifier<int> hp;
  final ValueNotifier<RunStatus> status = ValueNotifier(RunStatus.playing);
  final ValueNotifier<String?> banner = ValueNotifier(null);

  void damage(int amount) {
    if (status.value != RunStatus.playing) return;
    final next = (hp.value - amount).clamp(0, maxHp);
    hp.value = next;
    if (next <= 0) {
      // give the death animation (~4 frames @ 0.18s ≈ 0.7s) time to play
      // before the Game Over overlay covers the screen
      Future.delayed(const Duration(milliseconds: 900), () {
        status.value = RunStatus.lost;
      });
    }
  }

  void heal(int amount) {
    if (status.value != RunStatus.playing) return;
    hp.value = (hp.value + amount).clamp(0, maxHp);
  }

  void reachExit() {
    if (status.value != RunStatus.playing) return;
    // give the victory pose a moment on screen before the overlay appears
    Future.delayed(const Duration(milliseconds: 700), () {
      status.value = RunStatus.won;
    });
  }

  /// Shows a brief centered banner (e.g. "Level 2") that auto-dismisses.
  /// Used for level transitions — separate from `RunStatus`, since a
  /// level change isn't a win/lose state.
  void showBanner(
    String text, {
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    banner.value = text;
    Future.delayed(duration, () {
      if (banner.value == text) banner.value = null;
    });
  }

  void reset() {
    hp.value = maxHp;
    status.value = RunStatus.playing;
    banner.value = null;
  }

  void dispose() {
    hp.dispose();
    status.dispose();
    banner.dispose();
  }
}
