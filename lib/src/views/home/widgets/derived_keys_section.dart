import 'package:flutter/material.dart';
import 'package:cloud_sense_webapp/src/models/derived_weather_keys.dart';
import 'package:cloud_sense_webapp/src/services/derived_keys_service.dart';
import 'package:cloud_sense_webapp/src/views/home/widgets/derived_pluck_card.dart';

class DerivedKeysSection extends StatefulWidget {
  final Map<String, dynamic>? selectedDevice;
  final bool isDarkMode;

  const DerivedKeysSection({
    Key? key,
    required this.selectedDevice,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<DerivedKeysSection> createState() => _DerivedKeysSectionState();
}

class _DerivedKeysSectionState extends State<DerivedKeysSection> {
  DerivedKeyCategory _selectedCategory = DerivedKeyCategory.all;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final keys = DerivedKeysService.buildDerivedKeys(widget.selectedDevice);
    final allItems = DerivedKeysService.getPluckCardItems(keys);

    // Apply category & search filter
    final filteredItems = allItems.where((item) {
      final matchesCategory = _selectedCategory == DerivedKeyCategory.all ||
          item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.shortLabel.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.statusBadge.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmall = screenWidth < 600;

        int crossAxisCount;
        double childAspectRatio;

        if (screenWidth < 480) {
          crossAxisCount = 2;
          childAspectRatio = 1.05;
        } else if (screenWidth < 720) {
          crossAxisCount = 2;
          childAspectRatio = 1.25;
        } else if (screenWidth < 1100) {
          crossAxisCount = 3;
          childAspectRatio = 1.35;
        } else if (screenWidth < 1440) {
          crossAxisCount = 4;
          childAspectRatio = 1.45;
        } else {
          crossAxisCount = 4;
          childAspectRatio = 1.55;
        }

        return Container(
          margin: const EdgeInsets.only(top: 24, bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF0284C7).withOpacity(0.25)
                  : const Color(0xFF0284C7).withOpacity(0.15),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0B1724).withOpacity(0.95),
                      const Color(0xFF08121D).withOpacity(0.98),
                    ]
                  : [
                      const Color(0xFFF8FAFC),
                      const Color(0xFFEDF2F7),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.4)
                    : const Color(0xFF0284C7).withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 16 : 28,
            vertical: isSmall ? 20 : 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Section ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pill badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 6),
                              Text(
                                "DERIVED KEYS • PLUCK CARDS",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Derived Weather Placards",
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: isSmall ? 22 : 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Advanced biometeorological & agronomic metrics calculated from calibrated sensor feeds. Tap any card to pluck and inspect formulas & advisories.",
                          style: TextStyle(
                            fontSize: isSmall ? 12 : 13.5,
                            height: 1.45,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Filter Chips & Search Bar ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...DerivedKeyCategory.values.where((cat) {
                    if (cat == DerivedKeyCategory.all) return true;
                    return allItems.any((i) => i.category == cat);
                  }).map((cat) {
                    final isSelected = _selectedCategory == cat;
                    final count = cat == DerivedKeyCategory.all
                        ? allItems.length
                        : allItems.where((i) => i.category == cat).length;

                    return ChoiceChip(
                      selected: isSelected,
                      avatar: Icon(
                        cat.icon,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      label: Text(
                        "${cat.label} ($count)",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      selectedColor: const Color(0xFF0284C7),
                      backgroundColor: isDark
                          ? const Color(0xFF132333)
                          : const Color(0xFFE2E8F0),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF0284C7)
                              : (isDark ? Colors.white12 : Colors.black12),
                        ),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ],
              ),

              const SizedBox(height: 14),

              // Search Input Row
              if (!isSmall)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF132333) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search derived keys (e.g. VPD, Delta T, Dew Point)...",
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = "");
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) {
                            setState(() => _searchQuery = val.trim());
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF132333) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.layers_rounded,
                              size: 15,
                              color: isDark ? const Color(0xFF0284C7) : const Color(0xFF0284C7)),
                          const SizedBox(width: 6),
                          Text(
                            "Showing ${filteredItems.length} of ${allItems.length}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 18),

              // ── Pluck Cards Grid ──
              if (filteredItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF132333).withOpacity(0.4) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 40,
                          color: isDark ? Colors.white30 : Colors.black26),
                      const SizedBox(height: 10),
                      Text(
                        "No derived keys matched your search criteria.",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _selectedCategory = DerivedKeyCategory.all;
                            _searchQuery = "";
                          });
                        },
                        child: const Text("Reset Filters"),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredItems.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return DerivedPluckCard(
                      item: item,
                      isDarkMode: isDark,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
