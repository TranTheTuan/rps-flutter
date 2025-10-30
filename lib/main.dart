import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const RpsApp());

class RpsApp extends StatelessWidget {
  const RpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const RpsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum Move { rock, paper, scissors }

String moveEmoji(Move m) => switch (m) {
  Move.rock => '🪨',
  Move.paper => '📄',
  Move.scissors => '✂️',
};

class Round {
  final Move player;
  final Move cpu;
  final String result;
  const Round(this.player, this.cpu, this.result);
}

class RpsScreen extends StatefulWidget {
  const RpsScreen({super.key});

  @override
  State<RpsScreen> createState() => _RpsScreenState();
}

class _RpsScreenState extends State<RpsScreen> {
  final _rng = Random();

  Move? _player;
  Move? _cpu;
  String _result = 'Make your move!';

  int _wins = 0, _lose = 0, _draw = 0;

  void _play(Move player) {
    final cpu = Move.values[_rng.nextInt(Move.values.length)];
    final verdict = _judge(player, cpu);

    setState(() {
      _player = player;
      _cpu = cpu;
      _result = verdict;

      switch (verdict) {
        case 'You win!':
          _wins++;
        case 'You lose!':
          _lose++;
        case 'Draw':
          _draw++;
      }
    });
  }

  void _reset() {
    setState(() {
      _player = null;
      _cpu = null;
      _result = 'Make your move!';
      _wins = _lose = _draw = 0;
    });
  }

  String _judge(Move p, Move c) {
    if (p == c) return 'Draw';
    final win =
        (p == Move.rock && c == Move.scissors) ||
        (p == Move.paper && c == Move.rock) ||
        (p == Move.scissors && c == Move.paper);
    return win ? 'You win!' : 'You lose!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rock • Paper • Scissors')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Result / status area
              Column(
                children: [
                  SizedBox(height: 24),
                  Text(
                    _result,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You: ${_player != null ? moveEmoji(_player!) : '?'}'
                    ' vs  '
                    'CPU: ${_cpu != null ? moveEmoji(_cpu!) : '?'}',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Wins $_wins    Draws: $_draw    Looses: $_lose',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),

              // Buttons row
              Column(
                children: [
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RpsButton(
                        label: 'Rock',
                        emoji: '🪨',
                        onTap: () => _play(Move.rock),
                      ),
                      _RpsButton(
                        label: 'Paper',
                        emoji: '📄',
                        onTap: () => _play(Move.paper),
                      ),
                      _RpsButton(
                        label: 'Scissors',
                        emoji: '✂️',
                        onTap: () => _play(Move.scissors),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Reset', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RpsButton extends StatelessWidget {
  final String label;
  final String emoji;
  final VoidCallback onTap;

  const _RpsButton({
    required this.label,
    required this.emoji,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
