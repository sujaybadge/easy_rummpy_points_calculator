import 'dart:convert';

class Player {
  String name;

  /// Points the player started with (can be negative when continuing a game).
  int startPoints;

  /// Whether the player takes part in new rounds.
  bool playing;

  Player({required this.name, this.startPoints = 0, this.playing = true});

  Map<String, dynamic> toJson() =>
      {'name': name, 'startPoints': startPoints, 'playing': playing};

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        name: j['name'] as String,
        startPoints: j['startPoints'] as int? ?? 0,
        playing: j['playing'] as bool? ?? true,
      );
}

class GameSettings {
  int dropPoints;
  int middleDropPoints;
  int fullCountPoints;

  GameSettings({
    this.dropPoints = 20,
    this.middleDropPoints = 40,
    this.fullCountPoints = 80,
  });

  Map<String, dynamic> toJson() => {
        'dropPoints': dropPoints,
        'middleDropPoints': middleDropPoints,
        'fullCountPoints': fullCountPoints,
      };

  factory GameSettings.fromJson(Map<String, dynamic> j) => GameSettings(
        dropPoints: j['dropPoints'] as int? ?? 20,
        middleDropPoints: j['middleDropPoints'] as int? ?? 40,
        fullCountPoints: j['fullCountPoints'] as int? ?? 80,
      );
}

/// One round: a single winner collects the points every loser gives up.
/// Stored as player index -> signed score (winner positive, losers negative),
/// so each round sums to zero.
class Round {
  final int winner;

  /// Loser index -> points lost (stored as a positive number).
  final Map<int, int> losses;

  Round({required this.winner, required this.losses});

  int get winnerGain => losses.values.fold(0, (a, b) => a + b);

  /// Signed score for [player] this round, or null if they didn't play.
  int? scoreFor(int player) {
    if (player == winner) return winnerGain;
    final l = losses[player];
    return l == null ? null : -l;
  }

  Set<int> get players => {winner, ...losses.keys};

  Map<String, dynamic> toJson() => {
        'winner': winner,
        'losses': losses.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory Round.fromJson(Map<String, dynamic> j) => Round(
        winner: j['winner'] as int,
        losses: (j['losses'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as int)),
      );
}

class Game {
  final String id;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<Player> players;
  final GameSettings settings;
  final List<Round> rounds;

  Game({
    required this.players,
    required this.settings,
    List<Round>? rounds,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : rounds = rounds ?? [],
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  /// Player indexes sorted by total, highest first.
  List<int> get ranking => List.generate(players.length, (i) => i)
    ..sort((a, b) => totalFor(b).compareTo(totalFor(a)));

  int totalFor(int player) {
    var total = players[player].startPoints;
    for (final r in rounds) {
      total += r.scoreFor(player) ?? 0;
    }
    return total;
  }

  int winsFor(int player) => rounds.where((r) => r.winner == player).length;

  List<int> get playingIndexes => [
        for (var i = 0; i < players.length; i++)
          if (players[i].playing) i,
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'players': players.map((p) => p.toJson()).toList(),
        'settings': settings.toJson(),
        'rounds': rounds.map((r) => r.toJson()).toList(),
      };

  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: j['id'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
        players: (j['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
        settings: GameSettings.fromJson(j['settings'] as Map<String, dynamic>),
        rounds: (j['rounds'] as List)
            .map((e) => Round.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String encode() => jsonEncode(toJson());
  static Game decode(String s) =>
      Game.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
