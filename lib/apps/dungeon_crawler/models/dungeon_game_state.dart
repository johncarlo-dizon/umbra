import 'dart:async';
import 'package:flutter/foundation.dart';

enum RunStatus { playing, won, lost }

class DungeonGameState {
  DungeonGameState({this.maxHp = 100}) : hp = ValueNotifier(maxHp);

  final int maxHp;
  final ValueNotifier<int> hp;
  final ValueNotifier<RunStatus> status = ValueNotifier(RunStatus.playing);

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

  void reset() {
    hp.value = maxHp;
    status.value = RunStatus.playing;
  }

  void dispose() {
    hp.dispose();
    status.dispose();
  }
}
