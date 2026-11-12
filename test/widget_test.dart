import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rummy_points_calculator/models.dart';
import 'package:rummy_points_calculator/storage.dart';

void main() {
  test('winner collects what the losers lose; each round sums to zero', () {
    final g = Game(
      players: [Player(name: 'A'), Player(name: 'B'), Player(name: 'C')],
      settings: GameSettings(),
      rounds: [
        Round(winner: 0, losses: {1: 20, 2: 35}),
        Round(winner: 1, losses: {0: 40, 2: 80}),
      ],
    );
    expect(g.rounds[0].scoreFor(0), 55);
    expect(g.rounds[0].scoreFor(1), -20);
    expect(g.totalFor(0), 15); // +55 - 40
    expect(g.totalFor(1), 100); // -20 + 120
    expect(g.totalFor(2), -115); // -35 - 80
    expect(g.totalFor(0) + g.totalFor(1) + g.totalFor(2), 0);
    expect(g.winsFor(1), 1);
  });

  test('negative start points carry through and survive save/load', () {
    final g = Game(
      players: [Player(name: 'A', startPoints: -30), Player(name: 'B')],
      settings: GameSettings(),
      rounds: [
        Round(winner: 1, losses: {0: 20}),
      ],
    );
    expect(g.totalFor(0), -50);
    expect(g.totalFor(1), 20);
    final restored = Game.decode(g.encode());
    expect(restored.totalFor(0), -50);
    expect(restored.rounds.single.winner, 1);
  });

  test('player who sits out a round scores nothing for it', () {
    final g = Game(
      players: [Player(name: 'A'), Player(name: 'B'), Player(name: 'C')],
      settings: GameSettings(),
      rounds: [
        Round(winner: 0, losses: {1: 20}),
      ],
    );
    expect(g.rounds[0].scoreFor(2), isNull);
    expect(g.totalFor(2), 0);
  });

  test('old single-game save is moved into saved games', () async {
    final old = Game(
      players: [Player(name: 'A', startPoints: -25), Player(name: 'B')],
      settings: GameSettings(),
      rounds: [Round(winner: 1, losses: {0: 20})],
    );
    final json = old.toJson()..remove('id')..remove('createdAt')..remove('updatedAt');
    SharedPreferences.setMockInitialValues(
        {'current_game_v2': Game.fromJson(json).encode()});

    final current = await GameStorage.loadCurrent();
    expect(current, isNotNull);
    expect(current!.totalFor(0), -45);
    expect((await GameStorage.loadAll()).length, 1);
  });

  test('new game keeps the old one in the saved list', () async {
    SharedPreferences.setMockInitialValues({});
    final g1 = Game(players: [Player(name: 'A'), Player(name: 'B')],
        settings: GameSettings(), createdAt: DateTime(2026, 11, 1));
    await GameStorage.save(g1);
    await GameStorage.clearCurrent();
    final g2 = Game(players: [Player(name: 'C'), Player(name: 'D')],
        settings: GameSettings());
    await GameStorage.save(g2);

    final all = await GameStorage.loadAll();
    expect(all.map((g) => g.id), [g2.id, g1.id]);
    expect(all.last.createdAt, DateTime(2026, 11, 1));
    expect((await GameStorage.loadCurrent())!.id, g2.id);

    await GameStorage.delete(g1.id);
    expect((await GameStorage.loadAll()).length, 1);
  });
}
