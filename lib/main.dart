import 'package:flame/game.dart';
import 'package:flame_realtime_shooting/game/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemChrome을 사용하기 위해 필요
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'components/joypad.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // UI 바인딩을 초기화합니다.

  // Supabase 초기화
  await Supabase.initialize(
    url: 'https://djeovzmiajfslovjeafy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqZW92em1pYWpmc2xvdmplYWZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTM3NzMxOTcsImV4cCI6MjAyOTM0OTE5N30.qUak0tbzXZIep0rfSbIp3Tznxowg0uiiMgeSGiD3znY',
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 40),
  );

  // 화면 방향을 가로 모드로 고정합니다.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'UFO Shooting Game',
      debugShowCheckedModeBanner: false,
      home: GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({Key? key}) : super(key: key);

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final MyGame _game;
  RealtimeChannel? _gameChannel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.jpg', fit: BoxFit.cover),
          GameWidget(game: _game),  // 게임 위젯
          Positioned(
            left: 20,   // 화면 왼쪽에서 20픽셀
            bottom: 20, // 화면 하단에서 20픽셀
            child: Joypad(onDirectionChanged: (direction) {
              // 조이패드 입력에 따라 게임 내 방향을 변경
              _game.handleJoypadDirection(direction);
            }),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _game = MyGame(
      onGameStateUpdate: (position, health) async {
        ChannelResponse response;
        do {
          response = await _gameChannel!.sendBroadcastMessage(
            event: 'game_state',
            payload: {'x': position.x, 'y': position.y, 'health': health},
          );
          await Future.delayed(Duration.zero);
          setState(() {});
        } while (response == ChannelResponse.rateLimited && health <= 0);
      },
      onGameOver: (playerWon) async {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(playerWon ? 'You Won!' : 'You lost...'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await supabase.removeChannel(_gameChannel!);
                  _openLobbyDialog();
                },
                child: const Text('Back to Lobby'),
              ),
            ],
          ),
        );
      },
    );

    await Future.delayed(Duration.zero);
    if (mounted) {
      _openLobbyDialog();
    }
  }

  void _openLobbyDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _LobbyDialog(
              onGameStarted: (gameId) async {
                await Future.delayed(Duration.zero);
                setState(() {});
                _game.startNewGame();
                _gameChannel = supabase.channel(gameId,
                    opts: const RealtimeChannelConfig(ack: true));
                _gameChannel!
                    .onBroadcast(
                      event: 'game_state',
                      callback: (payload, [_]) {
                        final position = Vector2(
                            payload['x'] as double, payload['y'] as double);
                        final opponentHealth = payload['health'] as int;
                        _game.updateOpponent(
                            position: position, health: opponentHealth);
                        if (opponentHealth <= 0 && !_game.isGameOver) {
                          _game.isGameOver = true;
                          _game.onGameOver(true);
                        }
                      },
                    )
                    .subscribe();
              },
            ));
  }
}

class _LobbyDialog extends StatefulWidget {
  const _LobbyDialog({
    required this.onGameStarted,
  });

  final void Function(String gameId) onGameStarted;

  @override
  State<_LobbyDialog> createState() => _LobbyDialogState();
}

class _LobbyDialogState extends State<_LobbyDialog> {
  List<String> _userids = [];
  bool _loading = false;
  final myUserId = const Uuid().v4();
  late final RealtimeChannel _lobbyChannel;

  @override
  void initState() {
    super.initState();
    _lobbyChannel = supabase.channel(
      'lobby',
      opts: const RealtimeChannelConfig(self: true),
    );

    _lobbyChannel
        .onPresenceSync((payload, [ref]) {
          final presenceStates = _lobbyChannel.presenceState();
          setState(() {
            _userids = presenceStates
                .map((presenceState) =>
                    presenceState.presences.first.payload['user_id'] as String)
                .toList();
          });
        })
        .onBroadcast(
            event: 'game_start',
            callback: (payload, [_]) {
              final participantIds = List<String>.from(payload['participants']);
              if (participantIds.contains(myUserId)) {
                final gameId = payload['game_id'] as String;
                widget.onGameStarted(gameId);
                Navigator.of(context).pop();
              }
            })
        .subscribe((status, _) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _lobbyChannel.track({'user_id': myUserId});
          }
        });
  }

  @override
  void dispose() {
    supabase.removeChannel(_lobbyChannel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lobby'),
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Text('${_userids.length} users waiting'),
      actions: [
        TextButton(
          onPressed: _userids.length < 2
              ? null
              : () async {
                  setState(() {
                    _loading = true;
                  });

                  final opponentId =
                      _userids.firstWhere((userId) => userId != myUserId);
                  final gameId = const Uuid().v4();
                  await _lobbyChannel.sendBroadcastMessage(
                    event: 'game_start',
                    payload: {
                      'participants': [opponentId, myUserId],
                      'game_id': gameId,
                    },
                  );
                },
          child: const Text('Start Game'),
        ),
      ],
    );
  }
}
//
// class GameScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final myGame = MyGame(
//       onGameOver: (bool didWin) {
//         showDialog(
//           context: context,
//           builder: (BuildContext context) => AlertDialog(
//             title: Text(didWin ? "Congratulations! You won!" : "Game Over. You lost."),
//             actions: <Widget>[
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                 },
//                 child: Text('Close'),
//               ),
//             ],
//           ),
//         );
//       },
//       onGameStateUpdate: (Vector2 position, int health) {
//         print("Player position: $position, Health: $health");
//       },
//     );
//
//     return Scaffold(
//       body: Stack(
//         children: [
//           GameWidget(
//               game: myGame,
//               overlayBuilderMap: {
//                 'joypad': (context, game) => Joypad(onDirectionChanged: (direction) {
//                   // 여기에서 조이패드 입력을 처리하도록 게임 로직에 연동
//                   myGame.handleJoypadDirection(direction);
//                 }),
//               },
//               initialActiveOverlays: const ['joypad']  // Joypad 오버레이 활성화
//           ),
//           Positioned(
//             bottom: 20,  // 화면 하단에서 20픽셀
//             right: 20,   // 화면 우측에서 20픽셀
//             child: Joypad(onDirectionChanged: (direction) {
//               // Joypad 입력에 따라 방향을 처리
//               myGame.handleJoypadDirection(direction);
//             }),
//           )
//         ],
//       ),
//     );
//   }
// }