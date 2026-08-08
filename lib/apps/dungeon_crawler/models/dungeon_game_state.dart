import 'dart:async';
import 'package:flutter/foundation.dart';

enum RunStatus { playing, won, lost, downed }

class DungeonGameState {
  DungeonGameState({this.maxHp = 100}) : hp = ValueNotifier(maxHp);

  final int maxHp;
  final ValueNotifier<int> hp;
  final ValueNotifier<RunStatus> status = ValueNotifier(RunStatus.playing);
  final ValueNotifier<String?> banner = ValueNotifier(null);
  int revivesUsedThisRun = 0;
  int get reviveCost => 10 + (revivesUsedThisRun * 15); // 10, 25, 40, 55...
  final ValueNotifier<int> levelChangeCounter = ValueNotifier(0);
  void revive({int healTo = 50}) {
    if (status.value != RunStatus.downed) return;
    revivesUsedThisRun++;
    hp.value = healTo;
    status.value = RunStatus.playing;
  }

  void declineRevive() {
    if (status.value != RunStatus.downed) return;
    status.value = RunStatus.lost;
  }

  void damage(int amount) {
    if (status.value != RunStatus.playing) return;
    final next = (hp.value - amount).clamp(0, maxHp);
    hp.value = next;
    if (next <= 0) {
      Future.delayed(const Duration(milliseconds: 900), () {
        status.value = RunStatus.downed;
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
    levelChangeCounter.value = 0;
    hp.value = maxHp;
    status.value = RunStatus.playing;
    banner.value = null;
  }

  void dispose() {
    levelChangeCounter.dispose();
    hp.dispose();
    status.dispose();
    banner.dispose();
  }
}
