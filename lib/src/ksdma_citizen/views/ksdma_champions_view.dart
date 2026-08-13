import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';

class KsdmaChampionsView extends StatefulWidget {
  const KsdmaChampionsView({super.key});

  @override
  State<KsdmaChampionsView> createState() => _KsdmaChampionsViewState();
}

class _KsdmaChampionsViewState extends State<KsdmaChampionsView> {
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    // Lazy load: fetch champions only when Champions/Leaderboard view opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<KsdmaStateService>(context, listen: false).fetchChampionsIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    final champions = state.champions.where((c) {
      if (_selectedCategory == 'SCHOOLS') return c.category == UserCategory.schoolStudent;
      if (_selectedCategory == 'FARMERS') return c.category == UserCategory.farmer;
      if (_selectedCategory == 'FISHERMEN') return c.category == UserCategory.fisherman;
      if (_selectedCategory == 'NGOS') return c.category == UserCategory.ngoVolunteer;
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Ribbon
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: isMobile ? 36 : 48),
                    SizedBox(width: isMobile ? 12 : 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weather Champions of Kerala',
                            style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Celebrating Citizen Science Volunteers Building Kerala\'s Climate Resilience',
                            style: TextStyle(color: Colors.white, fontSize: isMobile ? 11 : 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

          // Category Chips Filter
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilterChip(
                label: Text('⭐ Top Contributors', style: TextStyle(color: _selectedCategory == 'ALL' ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 12)),
                selected: _selectedCategory == 'ALL',
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF1565C0),
                onSelected: (_) => setState(() => _selectedCategory = 'ALL'),
              ),
              FilterChip(
                label: Text('🏫 Schools & Students', style: TextStyle(color: _selectedCategory == 'SCHOOLS' ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 12)),
                selected: _selectedCategory == 'SCHOOLS',
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF1565C0),
                onSelected: (_) => setState(() => _selectedCategory = 'SCHOOLS'),
              ),
              FilterChip(
                label: Text('🌾 Farmers', style: TextStyle(color: _selectedCategory == 'FARMERS' ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 12)),
                selected: _selectedCategory == 'FARMERS',
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF1565C0),
                onSelected: (_) => setState(() => _selectedCategory = 'FARMERS'),
              ),
              FilterChip(
                label: Text('⚓ Fishermen', style: TextStyle(color: _selectedCategory == 'FISHERMEN' ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 12)),
                selected: _selectedCategory == 'FISHERMEN',
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF1565C0),
                onSelected: (_) => setState(() => _selectedCategory = 'FISHERMEN'),
              ),
              FilterChip(
                label: Text('🤝 NGOs & Volunteers', style: TextStyle(color: _selectedCategory == 'NGOS' ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 12)),
                selected: _selectedCategory == 'NGOS',
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF1565C0),
                onSelected: (_) => setState(() => _selectedCategory = 'NGOS'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (champions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No Weather Champions in this category yet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => state.refreshLiveData(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh Leaderboard'),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisExtent: isMobile ? 190 : 205,
                crossAxisSpacing: isMobile ? 12 : 16,
                mainAxisSpacing: isMobile ? 12 : 16,
              ),
              itemCount: champions.length,
              itemBuilder: (context, index) {
                final user = champions[index];

                final userObs = state.observations.where((o) => !o.isRemoved && o.submittedByUserId == user.userId).toList();

                final int actualObsCount = userObs.length;
                final int uniqueDaysCount = userObs
                    .map((o) => "${o.observationDate.year}-${o.observationDate.month}-${o.observationDate.day}")
                    .toSet()
                    .length;

                final int displayStreak = user.streakDays > 0 ? user.streakDays : (uniqueDaysCount > 0 ? uniqueDaysCount : 1);
                final int displayMaxStreak = user.maxStreak > 0 ? user.maxStreak : displayStreak;
                final int displayTotalReadings = actualObsCount > 0 ? actualObsCount : (user.totalObservations > 0 ? user.totalObservations : displayStreak);

                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: isMobile ? 24 : 28,
                              backgroundColor: const Color(0xFFFF8008),
                              backgroundImage: (user.avatarUrl != null && user.avatarUrl!.startsWith('http'))
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: (user.avatarUrl == null || !user.avatarUrl!.startsWith('http'))
                                  ? Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'V', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 18, color: Colors.white))
                                  : null,
                            ),
                            SizedBox(width: isMobile ? 10 : 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 15, color: const Color(0xFF0F172A))),
                                  Text('${user.category.label}${user.district.isNotEmpty ? " • ${user.district}" : ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isMobile ? 11 : 11, color: const Color(0xFF64748B))),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${user.badgeTier} BADGE',
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(height: isMobile ? 14 : 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Icon(Icons.local_fire_department, color: Colors.orange, size: isMobile ? 16 : 18),
                                Text('$displayStreak Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14, color: const Color(0xFF0F172A))),
                                Text('Streak', style: TextStyle(fontSize: isMobile ? 8 : 9, color: const Color(0xFF64748B))),
                              ],
                            ),
                            Column(
                              children: [
                                Icon(Icons.bolt, color: Colors.amber, size: isMobile ? 16 : 18),
                                Text('$displayMaxStreak Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14, color: const Color(0xFF0F172A))),
                                Text('Max Streak', style: TextStyle(fontSize: isMobile ? 8 : 9, color: const Color(0xFF64748B))),
                              ],
                            ),
                            Column(
                              children: [
                                Icon(Icons.analytics, color: Colors.blue, size: isMobile ? 16 : 18),
                                Text('$displayTotalReadings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14, color: const Color(0xFF0F172A))),
                                Text('Total Readings', style: TextStyle(fontSize: isMobile ? 8 : 9, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
