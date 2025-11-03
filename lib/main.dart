import 'dart:math';
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GameWidget(game: RpsFlameGame()));
}

// --- Game domain ---
enum Move { rock, paper, scissors }

String moveEmoji(Move m) => switch (m) {
  Move.rock => '🪨',
  Move.paper => '📄',
  Move.scissors => '✂️',
};

enum _Screen { menu, playing, gameOver }

class RpsFlameGame extends FlameGame with TapCallbacks {
  // Screens
  _Screen _screen = _Screen.menu;
  // Logical resolution for consistent layout across devices
  static final Vector2 worldSize = Vector2(360, 640);

  final _rng = Random();

  // HUD components
  late TextComponent statusText; // verdict / prompts
  late TextComponent versusText; // emojis line

  // Loaded sprites for each move
  late Map<Move, Sprite> _sprites;
  late TextComponent scoreText; // lifetime totals
  late TextComponent promptText; // bottom hint
  late TextComponent resetText; // tap to reset lifetime totals
  late TextComponent matchText; // current match score X - Y
  late TextComponent bestOfText; // "Best of: N" (tap to cycle 3/5/7)
  late TextComponent newMatchText; // tap to start a new match

  // Sprite HUD icons
  late SpriteComponent playerIcon;
  late SpriteComponent cpuIcon;

  // Menu & GameOver UI
  late TextComponent startText;
  late TextComponent playAgainText;
  late TextComponent backToMenuText;

  Move? _player;
  Move? _cpu;

  // Lifetime totals (persisted)
  int _wins = 0;
  int _losses = 0;
  int _draws = 0;

  // Match state (not persisted)
  int _bestOf = 3; // 3,5,7
  int _playerWinsInMatch = 0;
  int _cpuWinsInMatch = 0;

  bool get _isMatchOver {
    final need = (_bestOf ~/ 2) + 1;
    return _playerWinsInMatch >= need || _cpuWinsInMatch >= need;
  }

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedResolutionViewport(resolution: worldSize);

    statusText = TextComponent(
      text: 'Make your move!',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      anchor: Anchor.topCenter,
      position: Vector2(worldSize.x / 2, 24),
    );

    versusText = TextComponent(
      text: 'You: ?    vs    CPU: ?',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 18, color: Colors.white70),
      ),
      anchor: Anchor.topCenter,
      position: Vector2(worldSize.x / 2, 60),
    );

    scoreText = TextComponent(
      text: 'Wins: 0   Draws: 0   Losses: 0',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 16, color: Colors.white70),
      ),
      anchor: Anchor.topCenter,
      position: Vector2(worldSize.x / 2, 92),
    );

    // Match HUD row (best-of selector + match score + new match action)
    bestOfText = TextComponent(
      text: 'Best of: 3',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      ),
      anchor: Anchor.topLeft,
      position: Vector2(12, 120),
    );

    matchText = TextComponent(
      text: 'Match: 0 - 0',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      ),
      anchor: Anchor.topCenter,
      position: Vector2(worldSize.x / 2, 120),
    );

    newMatchText = TextComponent(
      text: 'New Match',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white70,
          decoration: TextDecoration.underline,
        ),
      ),
      anchor: Anchor.topRight,
      position: Vector2(worldSize.x - 12, 120),
    );

    promptText = TextComponent(
      text: '[  Rock   |   Paper   |   Scissors  ]',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 16, color: Colors.white60),
      ),
      anchor: Anchor.bottomCenter,
      position: Vector2(worldSize.x / 2, worldSize.y - 24),
    );

    resetText = TextComponent(
      text: 'Reset',
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 14, color: Colors.white60),
      ),
      anchor: Anchor.topRight,
      position: Vector2(worldSize.x - 12, 24),
    );

    // Menu / Gameover buttons
    startText = TextComponent(
      text: 'START',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      anchor: Anchor.topCenter,
      position: Vector2(worldSize.x / 2, 200),
    );

    playAgainText = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      anchor: Anchor.topCenter,
      position: Vector2(worldSize.x / 2, 220),
    );

    backToMenuText = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
        ),
      ),
      anchor: Anchor.topCenter,
      position: Vector2(worldSize.x / 2, 256),
    );

    addAll([
      statusText,
      versusText,
      scoreText,
      bestOfText,
      matchText,
      newMatchText,
      promptText,
      resetText,
      startText,
      playAgainText,
      backToMenuText,
    ]);

    _sprites = await _loadMoveSprites();

    playerIcon = SpriteComponent(
      sprite: _sprites[Move.rock],
      size: Vector2(42, 42),
      anchor: Anchor.topCenter,
      position: Vector2(worldSize.x / 2 - 60, 56),
      priority: 5,
    );
    cpuIcon = SpriteComponent(
      sprite: _sprites[Move.rock],
      size: Vector2(42, 42),
      anchor: Anchor.topCenter,
      position: Vector2(worldSize.x / 2 + 60, 56),
      priority: 5,
    );

    addAll([playerIcon, cpuIcon]);

    await _loadScores();
    _refreshScoreHud();
    _setMenuUI();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPaint(Paint()..color = const Color(0xFF0F172A));
    super.render(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.localPosition;

    // --- Top actions ---
    if (resetText.containsPoint(p)) {
      _resetScores();
      return;
    }
    if (bestOfText.containsPoint(p)) {
      _cycleBestOf();
      return;
    }
    if (newMatchText.containsPoint(p)) {
      _startNewMatch();
      return;
    }

    if (_screen == _Screen.menu) {
      if (startText.containsPoint(p)) {
        _setPlayingUI();
        _screen = _Screen.playing;
      }
      return;
    }

    if (_screen == _Screen.gameOver) {
      if (playAgainText.containsPoint(p)) {
        _startNewMatch();
        _setPlayingUI();
        _screen = _Screen.playing;
        return;
      }
      if (backToMenuText.containsPoint(p)) {
        _setMenuUI();
        _screen = _Screen.menu;
        return;
      }
      return; // ignore other taps in game over
    }

    // Ignore taps in upper half for throws
    if (p.y < worldSize.y * 0.5) return;
    if (_isMatchOver) {
      statusText.text = 'Match over — tap New Match';
      return;
    }

    // Map x thirds → Rock / Paper / Scissors
    final third = worldSize.x / 3;
    final choice = p.x < third
        ? Move.rock
        : (p.x < third * 2 ? Move.paper : Move.scissors);

    // Play a round
    _player = choice;
    _cpu = _cpuPick();

    final verdict = _judge(_player!, _cpu!);
    switch (verdict) {
      case 'You win!':
        _wins++;
        _playerWinsInMatch++;
      case 'You lose!':
        _losses++;
        _cpuWinsInMatch++;
      default:
        _draws++;
    }

    statusText.text = verdict;
    // Update icons
    playerIcon.sprite = _sprites[_player!];
    cpuIcon.sprite = _sprites[_cpu!];

    // Tighten info text
    versusText.text = 'You    vs    CPU';
    _refreshScoreHud();
    _refreshMatchHud();
    _saveScores();

    // Check match end
    if (_isMatchOver) {
      statusText.text = _playerWinsInMatch > _cpuWinsInMatch
          ? 'You won the match!'
          : 'CPU won the match!';
      _setGameOverUI();
      _screen = _Screen.gameOver;
    }
  }

  // --- Domain helpers ---
  Move _cpuPick() => Move.values[_rng.nextInt(Move.values.length)];

  String _judge(Move p, Move c) {
    if (p == c) return 'Draw';
    final win =
        (p == Move.rock && c == Move.scissors) ||
        (p == Move.paper && c == Move.rock) ||
        (p == Move.scissors && c == Move.paper);
    return win ? 'You win!' : 'You lose!';
  }

  void _refreshScoreHud() {
    scoreText.text = 'Wins: $_wins   Draws: $_draws   Losses: $_losses';
  }

  void _refreshMatchHud() {
    matchText.text = 'Match: $_playerWinsInMatch - $_cpuWinsInMatch';
    bestOfText.text = 'Best of: $_bestOf';
    if (!_isMatchOver) {
      promptText.text = '[  Rock   |   Paper   |   Scissors  ]';
    }
  }

  void _cycleBestOf() {
    // cycles 3 → 5 → 7 → 3, and resets current match
    _bestOf = _bestOf == 3 ? 5 : (_bestOf == 5 ? 7 : 3);
    _startNewMatch();
  }

  void _startNewMatch() {
    _player = null;
    _cpu = null;
    _playerWinsInMatch = 0;
    _cpuWinsInMatch = 0;
    statusText.text = 'New match: best of $_bestOf';
    versusText.text = 'You: ?    vs    CPU: ?';
    _refreshMatchHud();
  }

  // Asset loading
  Future<Map<Move, Sprite>> _loadMoveSprites() async {
    final rock = await loadSprite('rps/rock.png');
    final paper = await loadSprite('rps/paper.png');
    final scissors = await loadSprite('rps/scissors.png');
    return {Move.rock: rock, Move.paper: paper, Move.scissors: scissors};
  }

  // --- Screen UI helpers ---
  void _setMenuUI() {
    statusText.text = 'Rock • Paper • Scissors';
    versusText.text = 'Tap START';
    promptText.text = '[ Tap START ]';
    startText.text = 'START';
    playAgainText.text = '';
    backToMenuText.text = '';
  }

  void _setPlayingUI() {
    statusText.text = 'Make your move!';
    versusText.text = 'You vs CPU';
    promptText.text = '[ Rock | Paper | Scissors ]';
    startText.text = '';
    playAgainText.text = '';
    backToMenuText.text = '';
  }

  void _setGameOverUI() {
    playAgainText.text = 'PLAY AGAIN';
    backToMenuText.text = 'BACK TO MENU';
    promptText.text = '[ Tap an option above ]';
    startText.text = '';
  }

  // --- Persistence using shared_preferences ---
  static const _kWins = 'wins';
  static const _kLosses = 'losses';
  static const _kDraws = 'draws';

  Future<void> _loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    _wins = prefs.getInt(_kWins) ?? 0;
    _losses = prefs.getInt(_kLosses) ?? 0;
    _draws = prefs.getInt(_kDraws) ?? 0;
  }

  Future<void> _saveScores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWins, _wins);
    await prefs.setInt(_kLosses, _losses);
    await prefs.setInt(_kDraws, _draws);
  }

  Future<void> _resetScores() async {
    _wins = _losses = _draws = 0;
    _refreshScoreHud();
    statusText.text = 'Scores reset';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kWins);
    await prefs.remove(_kLosses);
    await prefs.remove(_kDraws);
  }
}
