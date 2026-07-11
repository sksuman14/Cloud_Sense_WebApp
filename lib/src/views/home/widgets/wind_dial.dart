import 'package:flutter/material.dart';
import 'dart:math';

class WindDial extends StatelessWidget {
  final dynamic direction;
  final dynamic speed;

  const WindDial({
    Key? key,
    required this.direction,
    required this.speed,
  }) : super(key: key);

  TextStyle _dirStyle() =>
      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) {
    double angle = double.tryParse(direction?.toString() ?? "") ?? 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(top: 6, child: Text("N", style: _dirStyle())),
                  Positioned(bottom: 6, child: Text("S", style: _dirStyle())),
                  Positioned(left: 6, child: Text("W", style: _dirStyle())),
                  Positioned(right: 6, child: Text("E", style: _dirStyle())),
                ],
              ),
            ),
            Transform.rotate(
              angle: angle * pi / 180,
              child: const Icon(Icons.navigation,
                  size: 50, color: Colors.redAccent),
            ),
          ],
        ),
      ],
    );
  }
}
