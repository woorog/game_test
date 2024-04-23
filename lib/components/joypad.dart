import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// 방향 정의를 위한 열거형
enum Direction { up, down, left, right, none }

class Joypad extends StatefulWidget {
  final ValueChanged<Direction>? onDirectionChanged;
  const Joypad({Key? key, this.onDirectionChanged}) : super(key: key);

  @override
  JoypadState createState() => JoypadState();
}

class JoypadState extends State<Joypad> {
  Direction direction = Direction.none;
  Offset delta = Offset.zero;
  bool isPressed = false; // 조이스틱이 눌린 상태관리

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: 120,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(60),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Transform.translate(
            offset: delta,
            child: CircleAvatar(
              backgroundColor: Colors.blue[300],
              radius: 30,
            ),
          ),
        ),
      ),
    );
  }

  //4-23 수정중 gpt 제한으로 여기까지 아래 핸들러부분을 플레이어,게임 쪽에 구현해줘야 함
  //수정사항 예정은 조이스틱 움직였을때 미러에 반영 하는거 필요함
  void _handlePanStart(DragStartDetails details) {
    isPressed = true;
    _updateMovement(details.localPosition);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (isPressed) {
      _updateMovement(details.localPosition);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    isPressed = false;
    updateDelta(Offset.zero); // 조이스틱을 중앙으로 리셋
  }

  void _updateMovement(Offset localPosition) {
    final newDelta = localPosition - const Offset(60, 60); // 조이스틱 중심을 기준으로 계산
    updateDelta(
      Offset.fromDirection(
        newDelta.direction,
        min(30, newDelta.distance),
      ),
    );
  }

  void updateDelta(Offset newDelta) {
    setState(() {
      delta = newDelta;
    });
    final newDirection = getDirectionFromOffset(newDelta);
    if (newDirection != direction) {
      direction = newDirection;
      if (widget.onDirectionChanged != null) {
        widget.onDirectionChanged!(direction);
      }
    }
  }

  Direction getDirectionFromOffset(Offset offset) {
    if (offset.dx.abs() > offset.dy.abs()) {
      return offset.dx > 0 ? Direction.right : Direction.left;
    } else if (offset.dy != 0) {
      return offset.dy > 0 ? Direction.down : Direction.up;
    }
    return Direction.none;
  }

  void onDragDown(DragDownDetails d) {
    calculateDelta(d.localPosition);
  }

  void onDragUpdate(DragUpdateDetails d) {
    calculateDelta(d.localPosition);
  }

  void onDragEnd(DragEndDetails d) {
    updateDelta(Offset.zero);  // Reset on drag end
  }

  void calculateDelta(Offset offset) {
    final newDelta = offset - const Offset(60, 60); // 조이스틱 중앙 조정
    updateDelta(
      Offset.fromDirection(
        newDelta.direction,
        min(30, newDelta.distance),
      ),
    );
  }
}
