import 'package:umbra/core/supabase_client.dart';
import 'package:umbra/apps/fitlog/models/exercise.dart';
import 'package:umbra/apps/fitlog/models/workout.dart';
import 'package:umbra/apps/fitlog/models/workout_exercise.dart';
import 'package:umbra/apps/fitlog/models/workout_set.dart';

/// User-facing exception type for FitLog — never let a raw Supabase/Postgrest
/// exception reach the UI. Follows the resilience pattern established in
/// mangahub_service.dart.
class FitlogException implements Exception {
  final String message;
  const FitlogException(this.message);

  @override
  String toString() => message;
}

class FitlogService {
  static const _timeout = Duration(seconds: 10);

  static String get _requireUserId {
    final id = SupabaseService.currentSession?.user.id;
    if (id == null) {
      throw const FitlogException('Sign in to log a workout.');
    }
    return id;
  }

  // ---------------------------------------------------------------------
  // Exercise library (shared reference data — no auth required to read)
  // ---------------------------------------------------------------------

  /// Fetches exercises from the shared library, optionally filtered by a
  /// search term (matches on name), category, equipment, or a set of
  /// target muscles (matches if the exercise's primary_muscles overlaps
  /// with any of the given muscle values — used for muscle-group browsing).
  static Future<List<Exercise>> getExercises({
    String? searchTerm,
    String? category,
    String? equipment,
    List<String>? muscles,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = SupabaseService.client
          .schema('fitlog')
          .from('exercise_library')
          .select();

      if (searchTerm != null && searchTerm.trim().isNotEmpty) {
        query = query.ilike('name', '%${searchTerm.trim()}%');
      }
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (equipment != null && equipment.isNotEmpty) {
        query = query.eq('equipment', equipment);
      }
      if (muscles != null && muscles.isNotEmpty) {
        query = query.overlaps('primary_muscles', muscles);
      }

      final response = await query
          .order('name')
          .range(offset, offset + limit - 1)
          .timeout(_timeout);

      return (response as List)
          .map((row) => Exercise.fromJson(row as Map<String, dynamic>))
          .toList();
    } on FitlogException {
      rethrow;
    } catch (e) {
      throw const FitlogException(
        'Could not load exercises. Check your connection and try again.',
      );
    }
  }

  static Future<List<String>> getCategories() async {
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('exercise_library')
          .select('category')
          .not('category', 'is', null)
          .timeout(_timeout);

      final categories =
          (response as List)
              .map((row) => row['category'] as String)
              .toSet()
              .toList()
            ..sort();
      return categories;
    } catch (e) {
      return [];
    }
  }

  static Future<List<String>> getEquipmentOptions() async {
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('exercise_library')
          .select('equipment')
          .not('equipment', 'is', null)
          .timeout(_timeout);

      final equipment =
          (response as List)
              .map((row) => row['equipment'] as String)
              .toSet()
              .toList()
            ..sort();
      return equipment;
    } catch (e) {
      return [];
    }
  }

  /// Full exercise details (including form instructions) by its library
  /// external_id — used for the "How to" view on a session's exercise
  /// cards, since workout_exercises only snapshots the name, not the
  /// full instructions text.
  static Future<Exercise?> getExerciseByExternalId(String externalId) async {
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('exercise_library')
          .select()
          .eq('external_id', externalId)
          .maybeSingle()
          .timeout(_timeout);

      if (response == null) return null;
      return Exercise.fromJson(response);
    } catch (e) {
      throw const FitlogException(
        'Could not load instructions. Check your connection and try again.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Workouts (user data — requires auth; RLS scopes every query/write to
  // the signed-in user automatically, so reads never need an explicit
  // .eq('user_id', ...) filter)
  // ---------------------------------------------------------------------

  /// Creates a new workout session and returns it.
  static Future<Workout> createWorkout({
    String? name,
    DateTime? date,
    String? notes,
  }) async {
    final userId = _requireUserId;
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('workouts')
          .insert({
            'user_id': userId,
            'name': name,
            'workout_date': (date ?? DateTime.now())
                .toIso8601String()
                .split('T')
                .first,
            'notes': notes,
          })
          .select()
          .single()
          .timeout(_timeout);

      return Workout.fromJson(response);
    } on FitlogException {
      rethrow;
    } catch (e) {
      throw const FitlogException(
        'Could not start the workout. Check your connection and try again.',
      );
    }
  }

  /// Workout history, newest first.
  static Future<List<Workout>> getWorkouts({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('workouts')
          .select()
          .order('workout_date', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .timeout(_timeout);

      return (response as List)
          .map((row) => Workout.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw const FitlogException(
        'Could not load your workout history. Check your connection and try again.',
      );
    }
  }

  /// A single workout by id (without nested exercises — call
  /// getWorkoutExercises separately, which already embeds sets).
  static Future<Workout> getWorkoutById(String workoutId) async {
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('workouts')
          .select()
          .eq('id', workoutId)
          .single()
          .timeout(_timeout);

      return Workout.fromJson(response);
    } catch (e) {
      throw const FitlogException(
        'Could not load this workout. Check your connection and try again.',
      );
    }
  }

  /// The exercises (with their sets) for a given workout, ordered for display.
  static Future<List<WorkoutExercise>> getWorkoutExercises(
    String workoutId,
  ) async {
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('workout_exercises')
          .select('*, sets(*)')
          .eq('workout_id', workoutId)
          .order('sort_order')
          .timeout(_timeout);

      return (response as List)
          .map((row) => WorkoutExercise.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw const FitlogException(
        'Could not load exercises for this workout. Check your connection and try again.',
      );
    }
  }

  static Future<void> deleteWorkout(String workoutId) async {
    try {
      await SupabaseService.client
          .schema('fitlog')
          .from('workouts')
          .delete()
          .eq('id', workoutId)
          .timeout(_timeout);
    } catch (e) {
      throw const FitlogException(
        'Could not delete this workout. Check your connection and try again.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Workout exercises
  // ---------------------------------------------------------------------

  /// Adds an exercise to a workout. [exerciseExternalId] is null for a
  /// manually-typed exercise not picked from the library — exerciseName
  /// is always required and snapshotted regardless, so history stays
  /// readable even if the library is later re-seeded with different ids.
  static Future<WorkoutExercise> addExerciseToWorkout({
    required String workoutId,
    required String exerciseName,
    String? exerciseExternalId,
    required int sortOrder,
  }) async {
    final userId = _requireUserId;
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('workout_exercises')
          .insert({
            'workout_id': workoutId,
            'user_id': userId,
            'exercise_external_id': exerciseExternalId,
            'exercise_name': exerciseName,
            'sort_order': sortOrder,
          })
          .select()
          .single()
          .timeout(_timeout);

      return WorkoutExercise.fromJson(response);
    } on FitlogException {
      rethrow;
    } catch (e) {
      throw const FitlogException(
        'Could not add that exercise. Check your connection and try again.',
      );
    }
  }

  static Future<void> deleteWorkoutExercise(String workoutExerciseId) async {
    try {
      await SupabaseService.client
          .schema('fitlog')
          .from('workout_exercises')
          .delete()
          .eq('id', workoutExerciseId)
          .timeout(_timeout);
    } catch (e) {
      throw const FitlogException(
        'Could not remove that exercise. Check your connection and try again.',
      );
    }
  }

  /// The most recent past instance of this exercise for the current user
  /// (excluding the given workout, so logging "again" in the same session
  /// doesn't show itself) — powers the "last time you did this" recall.
  static Future<WorkoutExercise?> getLastTimeForExercise(
    String exerciseName, {
    String? excludingWorkoutId,
  }) async {
    try {
      var query = SupabaseService.client
          .schema('fitlog')
          .from('workout_exercises')
          .select('*, sets(*)')
          .eq('exercise_name', exerciseName);

      if (excludingWorkoutId != null) {
        query = query.neq('workout_id', excludingWorkoutId);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(1)
          .timeout(_timeout);

      final rows = response as List;
      if (rows.isEmpty) return null;
      return WorkoutExercise.fromJson(rows.first as Map<String, dynamic>);
    } catch (e) {
      // Non-critical for logging to function — fail soft, just don't show
      // the recall card rather than blocking the whole screen.
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Sets
  // ---------------------------------------------------------------------

  static Future<WorkoutSet> addSet({
    required String workoutExerciseId,
    required int setNumber,
    double? weight,
    int? reps,
  }) async {
    final userId = _requireUserId;
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('sets')
          .insert({
            'workout_exercise_id': workoutExerciseId,
            'user_id': userId,
            'set_number': setNumber,
            'weight': weight,
            'reps': reps,
          })
          .select()
          .single()
          .timeout(_timeout);

      return WorkoutSet.fromJson(response);
    } on FitlogException {
      rethrow;
    } catch (e) {
      throw const FitlogException(
        'Could not save that set. Check your connection and try again.',
      );
    }
  }

  static Future<WorkoutSet> updateSet(
    String setId, {
    double? weight,
    int? reps,
  }) async {
    try {
      final response = await SupabaseService.client
          .schema('fitlog')
          .from('sets')
          .update({
            if (weight != null) 'weight': weight,
            if (reps != null) 'reps': reps,
          })
          .eq('id', setId)
          .select()
          .single()
          .timeout(_timeout);

      return WorkoutSet.fromJson(response);
    } catch (e) {
      throw const FitlogException(
        'Could not update that set. Check your connection and try again.',
      );
    }
  }

  static Future<void> deleteSet(String setId) async {
    try {
      await SupabaseService.client
          .schema('fitlog')
          .from('sets')
          .delete()
          .eq('id', setId)
          .timeout(_timeout);
    } catch (e) {
      throw const FitlogException(
        'Could not delete that set. Check your connection and try again.',
      );
    }
  }
}
