import 'package:flame_audio/flame_audio.dart';

/// Thin wrapper around FlameAudio for all Dungeon Crawler sound effects.
///
/// Two different overlap-prevention strategies are used here:
/// - Voice lines (player hurt/death/win, chase aggro, patrol bark) share
///   one exclusive "voice channel" — only one can play at a time, and a
///   new voice line is simply dropped if another is still speaking. This
///   is what stops the "everyone barks at once" echo/overlap problem.
/// - Everything else (attack whiff/hit, enemy attack, pickups) uses a
///   much shorter per-file debounce, since those are short percussive
///   SFX that are fine layering with each other and with voice lines —
///   they just shouldn't double-fire from the same event in one frame.
class DungeonAudio {
  DungeonAudio._();

  static bool muted = false;
  static double _clock = 0;

  static double _voiceBusyUntil = 0;
  static final Map<String, double> _lastPlayedAt = {};

  static const _files = [
    'player_win.mp3',
    'player_death.mp3',
    'playerv2.mp3',
    'chasev2.mp3',
    'patrolv2.mp3',
    'enemy_death.mp3',
    'player_attack_no_hitting_enemy.mp3',
    'enemy_attack.mp3',
    'player_attack_hitting_enemy.mp3',
    'item_pickup.mp3',
    'potion_drink.mp3',
    'coin_collect.mp3',
  ];

  static Future<void> preload() => FlameAudio.audioCache.loadAll(_files);

  /// Call once per frame — see `DungeonGame.update()`.
  static void tick(double dt) => _clock += dt;

  /// Voice lines: player hurt/death/win + enemy barks. Only one plays at
  /// a time; if the channel is busy, the new one is dropped entirely
  /// rather than queued (queuing barks would make reactions feel laggy
  /// and out of sync with what's actually happening on screen).
  static void _playVoice(
    String file, {
    double duration = 1.2,
    double volume = 1.0,
  }) {
    if (muted) return;
    if (_clock < _voiceBusyUntil) return;
    _voiceBusyUntil = _clock + duration;
    FlameAudio.play(file, volume: volume);
  }

  /// Short action SFX — brief per-file debounce only, no shared channel.
  static void _playSfx(
    String file, {
    double volume = 1.0,
    double minInterval = 0.1,
  }) {
    if (muted) return;
    final last = _lastPlayedAt[file];
    if (last != null && (_clock - last) < minInterval) return;
    _lastPlayedAt[file] = _clock;
    FlameAudio.play(file, volume: volume);
  }

  // --- voice lines (exclusive channel) ---
  static void playerWin() => _playVoice('player_win.mp3', duration: 1.5);
  static void playerDeath() => _playVoice('player_death.mp3', duration: 1.5);
  static void playerHurt() =>
      _playVoice('playerv2.mp3', duration: 1.0, volume: 0.8);
  static void chaseAggro() => _playVoice('chasev2.mp3', duration: 1.8);
  static void patrolBark() =>
      _playVoice('patrolv2.mp3', duration: 1.8, volume: 0.7);

  // --- short SFX (independent channel, layerable) ---
  static void enemyDeath() => _playSfx('enemy_death.mp3', minInterval: 0.2);
  static void attackWhiff() => _playSfx(
    'player_attack_no_hitting_enemy.mp3',
    volume: 0.6,
    minInterval: 0.3,
  );
  static void attackHit() =>
      _playSfx('player_attack_hitting_enemy.mp3', minInterval: 0.15);
  static void enemyAttack() => _playSfx('enemy_attack.mp3', minInterval: 0.5);
  static void itemPickup() => _playSfx('item_pickup.mp3', volume: 0.7);
  static void potionDrink() => _playSfx('potion_drink.mp3');
  static void coinCollect() =>
      _playSfx('coin_collect.mp3', volume: 0.7, minInterval: 0.1);
}
