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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: 120,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800], // 조이패드 배경
          borderRadius: BorderRadius.circular(60),
          border: Border.all(color: Colors.white, width: 2), // 테두리
        ),
        child: GestureDetector(
          onPanDown: onDragDown,
          onPanUpdate: onDragUpdate,
          onPanEnd: onDragEnd,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue[300], // 조이스틱 색상
              borderRadius: BorderRadius.circular(60),
            ),
            child: Center(
              child: Transform.translate(
                offset: delta,
                child: SizedBox(
                  height: 60,
                  width: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white, // 조이스틱 내부 버튼 색상
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
