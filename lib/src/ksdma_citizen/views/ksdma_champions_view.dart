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
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    final champions = state.champions.where((c) {
      if (_selectedCategory == 'SCHOOLS') return c.category == UserCategory.schoolStudent;
      if (_selectedCategory == 'FARMERS') return c.category == UserCategory.farmer;
      if (_selectedCategory == 'FISHERMEN') return c.category == UserCategory.fisherman;
      if (_selectedCategory == 'NGOS') return c.category == UserCategory.ngoVolunteer;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Ribbon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.emoji_events, color: Colors.white, size: 48),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weather Champions of Kerala',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Celebrating Citizen Science Volunteers Building Kerala\'s Climate Resilience',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Category Chips Filter
          Wrap(
            spacing: 12,
            children: [
              FilterChip(
                label: const Text('⭐ Top Contributors'),
                selected: _selectedCategory == 'ALL',
                onSelected: (_) => setState(() => _selectedCategory = 'ALL'),
              ),
              FilterChip(
                label: const Text('🏫 Schools & Students'),
                selected: _selectedCategory == 'SCHOOLS',
                onSelected: (_) => setState(() => _selectedCategory = 'SCHOOLS'),
              ),
              FilterChip(
                label: const Text('🌾 Farmers'),
                selected: _selectedCategory == 'FARMERS',
                onSelected: (_) => setState(() => _selectedCategory = 'FARMERS'),
              ),
              FilterChip(
                label: const Text('⚓ Fishermen'),
                selected: _selectedCategory == 'FISHERMEN',
                onSelected: (_) => setState(() => _selectedCategory = 'FISHERMEN'),
              ),
              FilterChip(
                label: const Text('🤝 NGOs & Volunteers'),
                selected: _selectedCategory == 'NGOS',
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
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisExtent: 220,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: champions.length,
              itemBuilder: (context, index) {
                final user = champions[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFFFF8008),
                              backgroundImage: (user.avatarUrl != null && user.avatarUrl!.startsWith('http'))
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: (user.avatarUrl == null || !user.avatarUrl!.startsWith('http'))
                                  ? Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'V', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white))
                                  : null,
                            ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('${user.category.label} • ${user.district}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${user.badgeTier} BADGE',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.orange),
                              Text('${user.streakDays} Days', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Text('Continuous Streak', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(Icons.analytics, color: Colors.blue),
                              Text('${user.totalObservations}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Text('Total Readings', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
  }
}
