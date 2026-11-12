import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Keeps every game ever played, plus which one is in progress.
class GameStorage {
  static const _gamesKey = 'games_v3';
  static const _currentKey = 'current_game_id';

  /// Single-game format used by earlier versions of the app.
  static const _legacyKey = 'current_game_v2';

  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      try {
        final g = Game.decode(legacy);
        await _write(prefs, [..._read(prefs), g]);
        await prefs.setString(_currentKey, g.id);
      } catch (_) {}
      await prefs.remove(_legacyKey);
    }
    return prefs;
  }

  static List<Game> _read(SharedPreferences prefs) {
    final s = prefs.getString(_gamesKey);
    if (s == null) return [];
    final games = <Game>[];
    for (final e in jsonDecode(s) as List) {
      try {
        games.add(Game.fromJson(e as Map<String, dynamic>));
      } catch (_) {}
    }
    return games;
  }

  static Future<void> _write(SharedPreferences prefs, List<Game> games) =>
      prefs.setString(
          _gamesKey, jsonEncode(games.map((g) => g.toJson()).toList()));

  /// All saved games, most recently played first.
  static Future<List<Game>> loadAll() async {
    final games = _read(await _prefs());
    games.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return games;
  }

  static Future<String?> currentId() async =>
      (await _prefs()).getString(_currentKey);

  static Future<Game?> loadCurrent() async {
    final prefs = await _prefs();
    final id = prefs.getString(_currentKey);
    if (id == null) return null;
    for (final g in _read(prefs)) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Saves (or adds) [game] and makes it the game in progress.
  static Future<void> save(Game game) async {
    final prefs = await _prefs();
    game.updatedAt = DateTime.now();
    final games = _read(prefs)..removeWhere((g) => g.id == game.id);
    games.add(game);
    await _write(prefs, games);
    await prefs.setString(_currentKey, game.id);
  }

  static Future<void> setCurrent(Game game) async =>
      (await _prefs()).setString(_currentKey, game.id);

  /// No game in progress (the old one stays in the saved list).
  static Future<void> clearCurrent() async =>
      (await _prefs()).remove(_currentKey);

  static Future<void> delete(String id) async {
    final prefs = await _prefs();
    await _write(prefs, _read(prefs)..removeWhere((g) => g.id == id));
    if (prefs.getString(_currentKey) == id) await prefs.remove(_currentKey);
  }
}
