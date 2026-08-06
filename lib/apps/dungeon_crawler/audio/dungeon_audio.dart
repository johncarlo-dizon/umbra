import 'package:flame_audio/flame_audio.dart';
import 'package:audioplayers/audioplayers.dart';

class DungeonAudio {
  DungeonAudio._();

  static bool muted = false;
  static double _clock = 0;

  // One dedicated, persistent player for ALL voice lines — never goes
  // through FlameAudio's shared SFX pool, so nothing else can steal or
  // recycle it mid-clip. This is what actually fixes the cutoff bug.
  static final AudioPlayer _voicePlayer = AudioPlayer();
  static bool _voiceBusy = false;

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
    'opendoor.mp3',
  ];

  static Future<void> preload() => FlameAudio.audioCache.loadAll(_files);

  static void tick(double dt) => _clock += dt;

  static Future<void> _playVoice(
    String file, {
    double volume = 1.0,
    bool priority = false,
  }) async {
    if (muted) return;
    if (_voiceBusy) {
      if (!priority) return;
      await _voicePlayer.stop();
    }
    _voiceBusy = true;
    await _voicePlayer.play(AssetSource('audio/$file'), volume: volume);
    _voicePlayer.onPlayerComplete.first.then((_) => _voiceBusy = false);
  }

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

  static void doorUnlock() => _playSfx('opendoor.mp3', minInterval: 0.5);
  static void playerWin() => _playVoice('player_win.mp3', priority: true);
  static void playerDeath() => _playVoice('player_death.mp3', priority: true);
  static void playerAmbientMutter() => _playVoice('playerv2.mp3', volume: 0.8);
  static void chaseAggro() => _playVoice('chasev2.mp3');
  static void patrolBark() => _playVoice('patrolv2.mp3', volume: 0.7);

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
