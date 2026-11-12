import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../storage.dart';
import 'game_screen.dart';

/// Every game played, newest first. Tap one to carry on playing it.
class SavedGamesScreen extends StatefulWidget {
  const SavedGamesScreen({super.key});

  @override
  State<SavedGamesScreen> createState() => _SavedGamesScreenState();
}

class _SavedGamesScreenState extends State<SavedGamesScreen> {
  List<Game>? _games;
  String? _currentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final games = await GameStorage.loadAll();
    final current = await GameStorage.currentId();
    if (mounted) {
      setState(() {
        _games = games;
        _currentId = current;
      });
    }
  }

  Future<void> _open(Game g) async {
    await GameStorage.setCurrent(g);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => GameScreen(game: g)),
      (_) => false,
    );
  }

  Future<void> _delete(Game g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this game?'),
        content: Text('Started ${formatDateTime(g.createdAt)}. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await GameStorage.delete(g.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved games')),
      body: games == null
          ? const Center(child: CircularProgressIndicator())
          : games.isEmpty
              ? const Center(child: Text('No games yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: games.length,
                  itemBuilder: (_, i) => _tile(games[i]),
                ),
    );
  }

  Widget _tile(Game g) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isCurrent = g.id == _currentId;
    final n = g.rounds.length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(g),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(formatDateTime(g.createdAt),
                            style: theme.textTheme.titleMedium),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Playing now',
                              style: theme.textTheme.labelSmall),
                        ),
                      ],
                    ]),
                    Text('$n round${n == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        for (final p in g.ranking)
                          Text.rich(TextSpan(children: [
                            TextSpan(text: '${g.players[p].name} '),
                            TextSpan(
                              text: signed(g.totalFor(p)),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: g.totalFor(p) > 0
                                    ? Colors.green.shade700
                                    : g.totalFor(p) < 0
                                        ? cs.error
                                        : null,
                              ),
                            ),
                          ])),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isCurrent)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(g),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
