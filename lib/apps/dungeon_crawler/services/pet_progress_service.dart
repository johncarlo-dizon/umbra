import '../../../core/supabase_client.dart';
import '../models/pet_definition.dart';

class PetProgress {
  final int gems;
  final List<String> unlockedPetIds;
  final String? equippedPetId;

  const PetProgress({
    required this.gems,
    required this.unlockedPetIds,
    this.equippedPetId,
  });

  factory PetProgress.empty() =>
      const PetProgress(gems: 0, unlockedPetIds: [], equippedPetId: null);

  factory PetProgress.fromMap(Map<String, dynamic> m) => PetProgress(
    gems: m['gems'] as int? ?? 0,
    unlockedPetIds: (m['unlocked_pets'] as List?)?.cast<String>() ?? [],
    equippedPetId: m['equipped_pet'] as String?,
  );
}

/// Reads/writes `dungeon_crawler.player_progress` — gems, unlocked pets,
/// currently equipped pet. Guests get an empty progress object (no pets,
/// no gems) rather than an error, since the dungeon crawler already
/// requires login before entry — this service should never actually be
/// called while logged out, but stays defensive regardless.
class PetProgressService {
  PetProgressService._();

  static final _schema = SupabaseService.client.schema('dungeon_crawler');
  static const _table = 'player_progress';

  static Future<PetProgress> fetch() async {
    if (!SupabaseService.isLoggedIn) return PetProgress.empty();
    final userId = SupabaseService.currentSession!.user.id;
    final row = await _schema
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return PetProgress.empty();
    return PetProgress.fromMap(row);
  }

  static Future<void> addGems(int amount) async {
    if (!SupabaseService.isLoggedIn || amount <= 0) return;
    final userId = SupabaseService.currentSession!.user.id;
    final current = await fetch();
    await _schema.from(_table).upsert({
      'user_id': userId,
      'gems': current.gems + amount,
    }, onConflict: 'user_id');
  }

  static Future<void> addGemsEarned(int amount) async {
    if (!SupabaseService.isLoggedIn || amount <= 0) return;
    await _schema.rpc('add_gems', params: {'p_amount': amount});
  }

  static Future<bool> purchasePet(String petId) async {
    if (!SupabaseService.isLoggedIn) return false;
    final userId = SupabaseService.currentSession!.user.id;
    final def = PetDefinition.byId(petId);
    final current = await fetch();
    if (current.gems < def.cost || current.unlockedPetIds.contains(petId))
      return false;

    await _schema.from(_table).upsert({
      'user_id': userId,
      'gems': current.gems - def.cost,
      'unlocked_pets': [...current.unlockedPetIds, petId],
    }, onConflict: 'user_id');
    return true;
  }

  static Future<void> equipPet(String? petId) async {
    if (!SupabaseService.isLoggedIn) return;
    final userId = SupabaseService.currentSession!.user.id;
    await _schema
        .from(_table)
        .update({'equipped_pet': petId})
        .eq('user_id', userId);
  }
}
