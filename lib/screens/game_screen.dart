import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../signed_input.dart';
import '../storage.dart';
import 'round_entry_screen.dart';
import 'saved_games_screen.dart';
import 'setup_screen.dart';

class GameScreen extends StatefulWidget {
  final Game game;
  const GameScreen({super.key, required this.game});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Game get g => widget.game;

  Future<void> _changed() async {
    setState(() {});
    await GameStorage.save(g);
  }

  // ---------- actions ----------

  Future<void> _addRound() async {
    final playing = g.playingIndexes;
    if (playing.length < 2) return;
    final result = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RoundEntryScreen(
        game: g,
        playerIndexes: playing,
        roundNumber: g.rounds.length + 1,
      ),
    ));
    if (result is Round) {
      g.rounds.add(result);
      await _changed();
    }
  }

  Future<void> _editRound(int r) async {
    final round = g.rounds[r];
    final result = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RoundEntryScreen(
        game: g,
        playerIndexes: round.players.toList()..sort(),
        roundNumber: r + 1,
        existing: round,
      ),
    ));
    if (result == 'delete') {
      g.rounds.removeAt(r);
      await _changed();
    } else if (result is Round) {
      g.rounds[r] = result;
      await _changed();
    }
  }

  Future<void> _addPlayer() async {
    final name = TextEditingController();
    final pts = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add player'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: pts,
              decoration: const InputDecoration(
                labelText: 'Start points',
                hintText: '0',
                helperText: 'Can be negative',
              ),
              keyboardType: signedKeyboard,
              inputFormatters: [signedIntFormatter],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    final n = name.text.trim();
    if (ok == true && n.isNotEmpty) {
      g.players.add(Player(name: n, startPoints: int.tryParse(pts.text) ?? 0));
      await _changed();
    }
  }

  /// Rename a player, correct their total, or take them in/out of play.
  Future<void> _editPlayer(int i) async {
    final p = g.players[i];
    final current = g.totalFor(i);
    final name = TextEditingController(text: p.name);
    final total = TextEditingController(text: '$current');
    var playing = p.playing;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Edit ${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: total,
                decoration: const InputDecoration(labelText: 'Total points'),
                keyboardType: signedKeyboard,
                inputFormatters: [signedIntFormatter],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Playing'),
                subtitle: const Text('Off = left out of new rounds'),
                value: playing,
                onChanged: (v) => setLocal(() => playing = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isNotEmpty) p.name = name.text.trim();
    p.playing = playing;
    final newTotal = int.tryParse(total.text);
    if (newTotal != null && newTotal != current) {
      // Fold the correction into start points so round history stays intact.
      p.startPoints += newTotal - current;
    }
    await _changed();
  }

  Future<void> _newGame() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new game?'),
        content: const Text(
            'This game stays in Saved games. You can start fresh, or carry '
            'everyone\'s totals over as their start points.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'carry'),
              child: const Text('Carry totals')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'fresh'),
              child: const Text('Fresh start')),
        ],
      ),
    );
    if (choice == null) return;
    final players = [
      for (var i = 0; i < g.players.length; i++)
        if (g.players[i].playing)
          Player(
            name: g.players[i].name,
            startPoints: choice == 'carry' ? g.totalFor(i) : 0,
          ),
    ];
    await GameStorage.clearCurrent();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          SetupScreen(initialPlayers: players, initialSettings: g.settings),
    ));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final order = List.generate(g.players.length, (i) => i)
      ..sort((a, b) {
        final pa = g.players[a].playing, pb = g.players[b].playing;
        if (pa != pb) return pa ? -1 : 1;
        return g.totalFor(b).compareTo(g.totalFor(a));
      });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Round ${g.rounds.length + 1}'),
            Text('Started ${formatDateTime(g.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add player',
            icon: const Icon(Icons.person_add),
            onPressed: _addPlayer,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'undo' && g.rounds.isNotEmpty) {
                g.rounds.removeLast();
                await _changed();
              } else if (v == 'new') {
                await _newGame();
              } else if (v == 'saved' && context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SavedGamesScreen()));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'undo',
                enabled: g.rounds.isNotEmpty,
                child: const Text('Undo last round'),
              ),
              const PopupMenuItem(value: 'new', child: Text('New game')),
              const PopupMenuItem(
                  value: 'saved', child: Text('Saved games')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          for (final i in order) _playerTile(i),
          const SizedBox(height: 16),
          if (g.rounds.isNotEmpty) ...[
            Text('Round history (tap a round to edit)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _historyTable(),
          ],
        ],
      ),
      floatingActionButton: g.playingIndexes.length >= 2
          ? FloatingActionButton.extended(
              onPressed: _addRound,
              icon: const Icon(Icons.add),
              label: const Text('Add round'),
            )
          : null,
    );
  }

  Color _scoreColor(int v, ColorScheme cs) => v > 0
      ? Colors.green.shade700
      : v < 0
          ? cs.error
          : cs.onSurface;

  Widget _playerTile(int i) {
    final p = g.players[i];
    final total = g.totalFor(i);
    final wins = g.winsFor(i);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      color: p.playing ? null : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListTile(
        onTap: () => _editPlayer(i),
        leading: CircleAvatar(
          child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase()),
        ),
        title: Text(
          p.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: p.playing ? null : cs.outline,
          ),
        ),
        subtitle: Text([
          '$wins win${wins == 1 ? '' : 's'}',
          if (!p.playing) 'not playing',
        ].join(' · ')),
        trailing: Text(
          signed(total),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: p.playing ? _scoreColor(total, cs) : cs.outline,
          ),
        ),
      ),
    );
  }

  Widget _historyTable() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasStart = g.players.any((p) => p.startPoints != 0);
    Widget cell(String t,
            {bool bold = false, Color? color, VoidCallback? onTap}) =>
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(t,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : null,
                  color: color,
                )),
          ),
        );
    Widget scoreCell(int? v, {bool bold = false, VoidCallback? onTap}) =>
        v == null
            ? cell('-', onTap: onTap)
            : cell(signed(v),
                bold: bold, color: _scoreColor(v, cs), onTap: onTap);

    final header = cs.secondaryContainer;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: theme.dividerColor),
        children: [
          TableRow(
            decoration: BoxDecoration(color: header),
            children: [
              cell('#', bold: true),
              for (final p in g.players) cell(p.name, bold: true),
            ],
          ),
          if (hasStart)
            TableRow(children: [
              cell('Start', bold: true),
              for (final p in g.players) scoreCell(p.startPoints),
            ]),
          for (var r = 0; r < g.rounds.length; r++)
            TableRow(children: [
              cell('${r + 1}', bold: true, onTap: () => _editRound(r)),
              for (var i = 0; i < g.players.length; i++)
                scoreCell(g.rounds[r].scoreFor(i),
                    bold: g.rounds[r].winner == i,
                    onTap: () => _editRound(r)),
            ]),
          TableRow(
            decoration: BoxDecoration(color: header),
            children: [
              cell('Total', bold: true),
              for (var i = 0; i < g.players.length; i++)
                scoreCell(g.totalFor(i), bold: true),
            ],
          ),
        ],
      ),
    );
  }
}
