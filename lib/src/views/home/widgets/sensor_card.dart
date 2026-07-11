import 'package:flutter/material.dart';

class SensorCard extends StatefulWidget {
  final String imageAsset;
  final String title;
  final String description;
  final VoidCallback onReadMore;
  final double screenWidth;

  const SensorCard({
    Key? key,
    required this.imageAsset,
    required this.title,
    required this.description,
    required this.onReadMore,
    required this.screenWidth,
  }) : super(key: key);

  @override
  State<SensorCard> createState() => _SensorCardState();
}

class _SensorCardState extends State<SensorCard> {
  bool isCardHovered = false;

  @override
  Widget build(BuildContext context) {
    double titleFontSize =
        widget.screenWidth < 600 ? 12 : (widget.screenWidth < 1300 ? 12 : 14);
    double buttonFontSize =
        widget.screenWidth < 600 ? 8.0 : (widget.screenWidth < 1300 ? 10.0 : 12.0);
    EdgeInsets cardPadding =
        EdgeInsets.all(widget.screenWidth < 600 ? 12.0 : 0.0);
    double titleDescriptionSpacing =
        widget.screenWidth < 600 ? 16 : (widget.screenWidth < 1300 ? 7.0 : 5.0);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isCardHovered = true),
      onExit: (_) => setState(() => isCardHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(isCardHovered ? 1.03 : 1.0),
        transformAlignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDarkMode
                ? [
                    const Color(0xFF0D1F2D).withOpacity(0.8),
                    const Color(0xFF0D1F2D),
                  ]
                : [
                    const Color(0xFFF1F5F9),
                    const Color(0xFFFFFFFF),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: isCardHovered
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.2),
              blurRadius: isCardHovered ? 10 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: Colors.transparent,
          child: Padding(
            padding: cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Image.asset(
                    widget.imageAsset,
                    width: widget.screenWidth < 600 ? 150 : 200,
                    height: widget.screenWidth < 600 ? 150 : 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                          color: const Color.fromARGB(255, 20, 8, 8),
                          height: 80);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: titleDescriptionSpacing),
                ElevatedButton(
                  onPressed: widget.onReadMore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? const Color(0xFF1FCB8A) : const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    "READ MORE >",
                    style: TextStyle(
                      fontSize: buttonFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
