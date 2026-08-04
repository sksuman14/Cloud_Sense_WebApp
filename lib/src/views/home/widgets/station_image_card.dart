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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: height,
        color: Colors.transparent,
        child: Stack(
          children: [
            Image.asset(
              'assets/images/site1.jpg',
              width: width,
              height: height,
              fit: fit,
              alignment: Alignment.center,
            ),
            // Bottom Info Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Nehon, Punjab",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
