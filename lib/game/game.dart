import 'dart:async';

import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/image_composition.dart' as flame_image;
import 'package:flame_realtime_shooting/game/bullet.dart';
import 'package:flame_realtime_shooting/game/player.dart';
import 'package:flutter/material.dart';

class MyGame extends FlameGame with PanDetector, HasCollisionDetection {
  MyGame({
    required this.onGameOver,
    required this.onGameStateUpdate,
  });

  static const _initialHealthPoints = 100;
  /// Callback to notify the parent when the game ends.
  final void Function(bool didWin) onGameOver;
  /// Callback for when the game state updates.
  final void Function(
      Vector2 position,
      int health,
      ) onGameStateUpdate;

  /// `Player` instance of the player
  late Player _player;

  /// `Player` instance of the opponent
  late Player _opponent;

  bool isGameOver = true;

  int _playerHealthPoint = _initialHealthPoints;

  late final flame_image.Image _playerBulletImage;
  late final flame_image.Image _opponentBulletImage;

  // 월드의 크기를 크게 정의합니다.
  static final Vector2 _worldSize = Vector2(4000, 2000); // 더 큰 크기로 조정

  @override
  Color backgroundColor() {
    return Colors.transparent;
  }

  @override
  Future<void>? onLoad() async {
    final playerImage = await images.load('player.png');
    _player = Player(isMe: true, initialPosition: Vector2(_worldSize.x * 0.25, _worldSize.y / 2));
    final spriteSize = Vector2.all(Player.radius * 2);
    _player.add(SpriteComponent(sprite: Sprite(playerImage), size: spriteSize));
    add(_player);

    final opponentImage = await images.load('opponent.png');
    _opponent = Player(isMe: false, initialPosition: Vector2(_worldSize.x * 0.75, _worldSize.y / 2));
    _opponent.add(SpriteComponent.fromImage(opponentImage, size: spriteSize));
    add(_opponent);

    _playerBulletImage = await images.load('player-bullet.png');
    _opponentBulletImage = await images.load('opponent-bullet.png');

    await super.onLoad();
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    _player.move(info.delta.global * (_worldSize.x / 2000)); // 이동 속도를 맵 크기에 비례하도록 조정
    final mirroredPosition = _player.getMirroredPercentPosition();
    onGameStateUpdate(mirroredPosition, _playerHealthPoint);
    super.onPanUpdate(info);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) {
      return;
    }
    for (final child in children) {
      if (child is Bullet && child.hasBeenHit && !child.isMine) {
        _playerHealthPoint = _playerHealthPoint - child.damage;
        final mirroredPosition = _player.getMirroredPercentPosition();
        onGameStateUpdate(mirroredPosition, _playerHealthPoint);
        _player.updateHealth(_playerHealthPoint / _initialHealthPoints);
      }
    }
    if (_playerHealthPoint <= 0) {
      endGame(false);
    }
  }

  void startNewGame() {
    isGameOver = false;
    _playerHealthPoint = _initialHealthPoints;
    _player.position = Vector2(_worldSize.x * 0.25, _worldSize.y / 2); // 초기 위치 조정
    _opponent.position = Vector2(_worldSize.x * 0.75, _worldSize.y / 2);

    for (final child in children) {
      if (child is Bullet) {
        child.removeFromParent();
      }
    }

    _shootBullets();
  }

  Future<void> _shootBullets() async {
    await Future.delayed(const Duration(milliseconds: 500));
    addBullets(_player, _playerBulletImage, true);
    addBullets(_opponent, _opponentBulletImage, false);
    _shootBullets();
  }

  void addBullets(Player player, flame_image.Image bulletImage, bool isMine) {
    final bulletInitialPosition = Vector2.copy(player.position) + Vector2(0, isMine ? -Player.radius : Player.radius);
    final bulletVelocities = [
      Vector2(0, isMine ? -200 : 200), // 속도 조정
      Vector2(120, isMine ? -160 : 160), // 속도 조정
      Vector2(-120, isMine ? -160 : 160), // 속도 조정
    ];
    for (final velocity in bulletVelocities) {
      add(Bullet(
        isMine: isMine,
        velocity: velocity,
        image: bulletImage,
        initialPosition: bulletInitialPosition,
      ));
    }
  }

  void updateOpponent({required Vector2 position, required int health}) {
    _opponent.position = Vector2(_worldSize.x * position.x, _worldSize.y * position.y);
    _opponent.updateHealth(health / _initialHealthPoints);
  }

  void endGame(bool playerWon) {
    isGameOver = true;
    onGameOver(playerWon);
  }
}
