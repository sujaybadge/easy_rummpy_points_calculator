import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../signed_input.dart';
import '../storage.dart';
import 'game_screen.dart';
import 'saved_games_screen.dart';

class SetupScreen extends StatefulWidget {
  /// Pre-filled players (e.g. carried over from the previous game).
  final List<Player>? initialPlayers;
  final GameSettings? initialSettings;

  const SetupScreen({super.key, this.initialPlayers, this.initialSettings});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _PlayerRow {
  final name = TextEditingController();
  final start = TextEditingController();
  void dispose() {
    name.dispose();
    start.dispose();
  }
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final List<_PlayerRow> _rows = _initialRows();
  late final _drop = TextEditingController(
      text: '${widget.initialSettings?.dropPoints ?? 20}');
  late final _midDrop = TextEditingController(
      text: '${widget.initialSettings?.middleDropPoints ?? 40}');
  late final _full = TextEditingController(
      text: '${widget.initialSettings?.fullCountPoints ?? 80}');

  List<_PlayerRow> _initialRows() {
    final rows = [
      for (final p in widget.initialPlayers ?? <Player>[])
        _PlayerRow()
          ..name.text = p.name
          ..start.text = p.startPoints == 0 ? '' : '${p.startPoints}',
    ];
    while (rows.length < 2) {
      rows.add(_PlayerRow());
    }
    return rows;
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _drop.dispose();
    _midDrop.dispose();
    _full.dispose();
    super.dispose();
  }

  int _int(TextEditingController c, [int fallback = 0]) =>
      int.tryParse(c.text.trim()) ?? fallback;

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;
    final game = Game(
      players: [
        for (final r in _rows)
          Player(name: r.name.text.trim(), startPoints: _int(r.start)),
      ],
      settings: GameSettings(
        dropPoints: _int(_drop, 20),
        middleDropPoints: _int(_midDrop, 40),
        fullCountPoints: _int(_full, 80),
      ),
    );
    await GameStorage.save(game);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(game: game)),
    );
  }

  Widget _numField(TextEditingController c, String label) => Expanded(
        child: TextFormField(
          controller: c,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Rummy Game'),
        actions: [
          IconButton(
            tooltip: 'Saved games',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SavedGamesScreen())),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Quick points', style: theme.textTheme.titleMedium),
            Text(
              'Each round the winner collects the points every other '
              'player loses.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(children: [
              _numField(_drop, 'Drop'),
              const SizedBox(width: 8),
              _numField(_midDrop, 'Middle drop'),
              const SizedBox(width: 8),
              _numField(_full, 'Full count'),
            ]),
            const SizedBox(height: 24),
            Text('Players', style: theme.textTheme.titleMedium),
            Text(
              'Leave start points empty (0) for a fresh game. Fill them in, '
              'plus or minus, if you are continuing a game from the middle.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _rows[i].name,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Player ${i + 1} name',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'Enter a name';
                          final dupes = _rows
                              .where((r) =>
                                  r.name.text.trim().toLowerCase() ==
                                  t.toLowerCase())
                              .length;
                          if (dupes > 1) return 'Duplicate name';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _rows[i].start,
                        decoration: const InputDecoration(
                          labelText: 'Start pts',
                          hintText: '0',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: signedKeyboard,
                        inputFormatters: [signedIntFormatter],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _rows.length <= 2
                          ? null
                          : () => setState(() => _rows.removeAt(i).dispose()),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _rows.add(_PlayerRow())),
                icon: const Icon(Icons.person_add),
                label: const Text('Add player'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Start game'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
