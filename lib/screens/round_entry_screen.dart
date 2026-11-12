import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';

/// Enter (or edit) one round: pick the single winner, enter what each
/// other player loses. Pops with a [Round], or 'delete' to remove an
/// existing round.
class RoundEntryScreen extends StatefulWidget {
  final Game game;
  final List<int> playerIndexes;
  final Round? existing;
  final int roundNumber;

  const RoundEntryScreen({
    super.key,
    required this.game,
    required this.playerIndexes,
    required this.roundNumber,
    this.existing,
  });

  @override
  State<RoundEntryScreen> createState() => _RoundEntryScreenState();
}

class _RoundEntryScreenState extends State<RoundEntryScreen> {
  late int? _winner = widget.existing?.winner;
  late final Map<int, TextEditingController> _ctrls = {
    for (final i in widget.playerIndexes)
      i: TextEditingController(
          text: widget.existing?.losses[i]?.toString() ?? ''),
  };

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _pot => _ctrls.entries
      .where((e) => e.key != _winner)
      .fold(0, (sum, e) => sum + (int.tryParse(e.value.text) ?? 0));

  void _save() {
    String? error;
    final missing = _ctrls.entries
        .where((e) => e.key != _winner && e.value.text.trim().isEmpty)
        .map((e) => widget.game.players[e.key].name);
    if (_winner == null) {
      error = 'Pick the winner of this round';
    } else if (missing.isNotEmpty) {
      error = 'Enter points for: ${missing.join(', ')}';
    }
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop(Round(
      winner: _winner!,
      losses: {
        for (final e in _ctrls.entries)
          if (e.key != _winner) e.key: int.parse(e.value.text.trim()),
      },
    ));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this round?'),
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
    if (ok == true && mounted) Navigator.of(context).pop('delete');
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final s = g.settings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'Round ${widget.roundNumber}'
            : 'Edit round ${widget.roundNumber}'),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Delete round',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Tap the trophy for the winner, then enter what everyone else '
            'loses. The winner gets the total.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final i in widget.playerIndexes)
            Card(
              color: i == _winner ? cs.primaryContainer : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Winner',
                          isSelected: i == _winner,
                          selectedIcon: const Icon(Icons.emoji_events),
                          icon: const Icon(Icons.emoji_events_outlined),
                          onPressed: () => setState(() => _winner = i),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(g.players[i].name,
                              style: theme.textTheme.titleMedium),
                        ),
                        if (i == _winner)
                          Text('+$_pot',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold))
                        else
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: _ctrls[i],
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge,
                              decoration: const InputDecoration(
                                hintText: 'pts',
                                prefixText: '−',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                      ],
                    ),
                    if (i != _winner) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _quick('Drop', s.dropPoints, i),
                          _quick('Mid drop', s.middleDropPoints, i),
                          _quick('Full', s.fullCountPoints, i),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Save round'),
      ),
    );
  }

  Widget _quick(String label, int value, int i) => ChoiceChip(
        label: Text('$label ($value)'),
        showCheckmark: false,
        selected: _ctrls[i]!.text == '$value',
        onSelected: (_) => setState(() => _ctrls[i]!.text = '$value'),
      );
}
