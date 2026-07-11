import 'package:flutter/material.dart';

class StationImageCard extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const StationImageCard({
    Key? key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: height,
        color: Colors.transparent,
        child: Image.asset(
          'assets/images/weather.jpg',
          width: width,
          height: height,
          fit: fit,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
