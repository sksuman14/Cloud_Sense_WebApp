import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import '../theme/ksdma_theme.dart';
import 'ksdma_auth_modal.dart';
void _showZoomDialog(BuildContext context, String imageUrl) {
  if (imageUrl.isEmpty) return;
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade900,
                  padding: const EdgeInsets.all(40),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white, size: 48),
                      SizedBox(height: 8),
                      Text('Image preview unavailable', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

class KsdmaVolunteerView extends StatelessWidget {
  final Function(String stationId) onEnterObservation;
  final VoidCallback? onRegisterNewDevice;

  const KsdmaVolunteerView({
    super.key,
    required this.onEnterObservation,
    this.onRegisterNewDevice,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    // If user is not signed in → prompt for login/registration
    if (!state.isLoggedIn) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.assignment_ind_outlined, color: Color(0xFF2563EB), size: 32),
              ),
              const SizedBox(height: 20),
              const Text('🙋 Volunteer Sign In Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              Text(
                'To view your stations and submit daily weather observations, please sign in or register as a Volunteer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => KsdmaAuthModal.show(context, state),
                  icon: const Icon(Icons.login, color: Colors.white, size: 18),
                  label: const Text('Sign In / Register as Volunteer', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final user = state.currentUser;
    final userStats = state.getVolunteerStats(user);

    final myStations = state.stations.where((s) {
      if (s.ownerUserId == user.userId) return true;
      if (user.mobileNumber.isNotEmpty && (s.ownerUserId.contains(user.mobileNumber) || s.ownerUserId == 'usr_${user.mobileNumber}')) return true;
      if (user.fullName.isNotEmpty && s.ownerName.toLowerCase().trim() == user.fullName.toLowerCase().trim()) return true;
      if (s.ownerUserId == 'usr_active_volunteer' || s.ownerUserId == 'usr_anon') return true;
      return false;
    }).toList();

    final int displayStreak = userStats['streak']!;
    final int todayReadingsCount = userStats['todayReadings']! > 0 ? userStats['todayReadings']! : myStations.where((s) => state.getTodayObservation(s.stationId) != null).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 700;
        final bool isDesktop = constraints.maxWidth >= 950;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content Head
              if (isMobile) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KsdmaEyebrow('Volunteer Home'),
                    const SizedBox(height: 4),
                    Text(
                      'Hello, ${user.fullName} 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: KsdmaColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Grama Panchayat: ${user.gramaPanchayat.isNotEmpty ? user.gramaPanchayat : "Kunnamangalam"} · ${user.taluk.isNotEmpty ? user.taluk : "Koyilandy"} Taluk · ${user.district.isNotEmpty ? user.district : "Kozhikode"}',
                      style: const TextStyle(fontSize: 12, color: KsdmaColors.inkSoft),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloading Official KSDMA Volunteer Recognition Certificate...')),
                        );
                      },
                      icon: const Icon(Icons.workspace_premium, color: KsdmaColors.goldDark, size: 16),
                      label: const Text('Download Certificate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KsdmaColors.goldDark,
                        side: const BorderSide(color: KsdmaColors.gold, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KsdmaEyebrow('Volunteer Home'),
                          const SizedBox(height: 4),
                          Text(
                            'Hello, ${user.fullName} 👋',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: KsdmaColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Grama Panchayat: ${user.gramaPanchayat.isNotEmpty ? user.gramaPanchayat : "Kunnamangalam"} · ${user.taluk.isNotEmpty ? user.taluk : "Koyilandy"} Taluk · ${user.district.isNotEmpty ? user.district : "Kozhikode"}',
                            style: const TextStyle(fontSize: 13, color: KsdmaColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloading Official KSDMA Volunteer Recognition Certificate...')),
                        );
                      },
                      icon: const Icon(Icons.workspace_premium, color: KsdmaColors.goldDark, size: 16),
                      label: const Text('Download Certificate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KsdmaColors.goldDark,
                        side: const BorderSide(color: KsdmaColors.gold, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),



              const SizedBox(height: 24),

              // Streak & Contribution Stats Row (Responsive Grid / Stack)
              if (isDesktop) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Continuous Streak',
                        value: '$displayStreak Days',
                        subtitle: 'Daily 8:00 AM IMD Protocol',
                        icon: Icons.local_fire_department,
                        iconColor: Colors.orange,
                        borderColor: Colors.orange.shade200,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Today\'s Readings',
                        value: '$todayReadingsCount',
                        subtitle: 'Submitted Today (IMD Window)',
                        icon: Icons.analytics,
                        iconColor: Colors.blue,
                        borderColor: Colors.blue.shade200,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Weather Devices',
                        value: '${myStations.length}',
                        subtitle: 'Rain Gauge, Thermometer',
                        icon: Icons.sensors,
                        iconColor: Colors.green,
                        borderColor: Colors.green.shade200,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Column(
                  children: [
                    _buildStatCard(
                      title: 'Continuous Streak',
                      value: '$displayStreak Days',
                      subtitle: 'Daily 8:00 AM IMD Protocol',
                      icon: Icons.local_fire_department,
                      iconColor: Colors.orange,
                      borderColor: Colors.orange.shade200,
                    ),
                    const SizedBox(height: 10),
                    _buildStatCard(
                      title: 'Today\'s Readings',
                      value: '$todayReadingsCount',
                      subtitle: 'Submitted Today (IMD Window)',
                      icon: Icons.analytics,
                      iconColor: Colors.blue,
                      borderColor: Colors.blue.shade200,
                    ),
                    const SizedBox(height: 10),
                    _buildStatCard(
                      title: 'Registered Weather Devices',
                      value: '${myStations.length}',
                      subtitle: 'Rain Gauge, Thermometer',
                      icon: Icons.sensors,
                      iconColor: Colors.green,
                      borderColor: Colors.green.shade200,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // Action Section Header with Register Device Button
              if (isDesktop) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Your Registered Weather Devices & Today\'s Status',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Select a device below to enter reading or register a new device',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: onRegisterNewDevice,
                      icon: const Icon(Icons.add_circle, size: 16),
                      label: const Text('➕ Register New Instrument', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Registered Weather Devices & Today\'s Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Select a device below to enter reading or register a new device',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: onRegisterNewDevice,
                      icon: const Icon(Icons.add_circle, size: 15),
                      label: const Text('➕ Register Instrument', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Registered Device Cards List
              if (myStations.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.sensors_off, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No Weather Devices Registered Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text('Register your Standard Rain Gauge or Max-Min Thermometer to start contributing.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: onRegisterNewDevice,
                            icon: const Icon(Icons.add),
                            label: const Text('Register Instrument Now'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: myStations.length,
                  itemBuilder: (context, index) {
                    final s = myStations[index];
                    final obsToday = state.getTodayObservation(s.stationId);
                    final obsRemovedToday = state.getTodayRemovedObservation(s.stationId);
                    final isSubmittedToday = obsToday != null;
                    final isFlaggedToday = !isSubmittedToday && obsRemovedToday != null;

                    Widget buildPhoto() {
                      return GestureDetector(
                        onTap: () {
                          if (s.devicePhotoUrl != null && s.devicePhotoUrl!.isNotEmpty) {
                            _showZoomDialog(context, s.devicePhotoUrl!);
                          }
                        },
                        child: Tooltip(
                          message: '🔍 Click to Zoom Photo',
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: isMobile ? 64 : 80,
                                  height: isMobile ? 64 : 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: NetworkImage(s.devicePhotoUrl!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  margin: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                  child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    Widget buildInfo() {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                s.stationId,
                                style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: const Color(0xFF1565C0)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: s.approvalStatus == ApprovalStatus.approved
                                      ? Colors.green.shade100
                                      : s.approvalStatus == ApprovalStatus.rejected
                                          ? Colors.red.shade100
                                          : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  s.approvalStatus == ApprovalStatus.approved
                                      ? 'APPROVED & ACTIVE'
                                      : s.approvalStatus == ApprovalStatus.rejected
                                          ? '❌ REJECTED BY ADMIN'
                                          : '⌛ PENDING APPROVAL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: s.approvalStatus == ApprovalStatus.approved
                                        ? Colors.green.shade900
                                        : s.approvalStatus == ApprovalStatus.rejected
                                            ? Colors.red.shade900
                                            : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                              if (isSubmittedToday) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: obsToday.isEdited ? Colors.purple.shade100 : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '✅ TODAY: ${obsToday.rainfallMm != null ? "${obsToday.rainfallMm} mm" : obsToday.maxTemperatureC != null ? "${obsToday.maxTemperatureC}°C" : obsToday.riverWaterLevelM != null ? "${obsToday.riverWaterLevelM} m" : obsToday.humidityPercent != null ? "${obsToday.humidityPercent}%" : "Recorded"}${obsToday.isEdited ? " (EDITED)" : ""}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: obsToday.isEdited ? Colors.purple.shade900 : Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.instrumentType.displayName,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 13 : 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Location: ${s.gramaPanchayat}, ${s.district} (${s.latitude.toStringAsFixed(4)}° N, ${s.longitude.toStringAsFixed(4)}° E)',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                          if (isFlaggedToday) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade400),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '⚠️ Today\'s Reading Flagged by Admin: "${obsRemovedToday.removalReason ?? 'Outlier Reading'}". Please submit a fresh value.',
                                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (s.approvalStatus == ApprovalStatus.rejected && s.rejectionReason.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: Colors.red.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Rejection Reason: ${s.rejectionReason}',
                                      style: TextStyle(fontSize: 11, color: Colors.red.shade800, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    }

                    Widget buildActionButton() {
                      return Column(
                        crossAxisAlignment: isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: s.approvalStatus == ApprovalStatus.approved
                                ? () => onEnterObservation(s.stationId)
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          s.approvalStatus == ApprovalStatus.rejected
                                              ? '❌ This station registration was rejected. Reason: ${s.rejectionReason.isNotEmpty ? s.rejectionReason : "Contact Admin HQ"}'
                                              : '🔒 Station Pending Approval by Admin HQ. Data entry is locked until approved.',
                                        ),
                                        backgroundColor: s.approvalStatus == ApprovalStatus.rejected ? Colors.red.shade700 : Colors.amber,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  },
                            icon: Icon(
                              s.approvalStatus == ApprovalStatus.approved
                                  ? (isSubmittedToday ? Icons.edit_note : (isFlaggedToday ? Icons.refresh : Icons.add_chart))
                                  : s.approvalStatus == ApprovalStatus.rejected
                                      ? Icons.cancel
                                      : Icons.lock,
                              size: 16,
                            ),
                            label: Text(
                              s.approvalStatus == ApprovalStatus.approved
                                  ? (isSubmittedToday ? 'Edit Today\'s Reading' : (isFlaggedToday ? 'Re-enter Fresh Reading' : 'Enter Reading'))
                                  : s.approvalStatus == ApprovalStatus.rejected
                                      ? 'Registration Rejected'
                                      : 'Locked (Pending Approval)',
                              style: TextStyle(fontSize: isMobile ? 11 : 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: s.approvalStatus == ApprovalStatus.approved
                                  ? (isSubmittedToday ? const Color(0xFF0288D1) : (isFlaggedToday ? const Color(0xFFD97706) : const Color(0xFF16A34A)))
                                  : s.approvalStatus == ApprovalStatus.rejected
                                      ? Colors.red.shade700
                                      : Colors.grey.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Observation Window: 08:00 - 09:00 AM IST',
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                            textAlign: isMobile ? TextAlign.center : TextAlign.end,
                          ),
                        ],
                      );
                    }

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 14.0 : 20.0),
                        child: isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      buildPhoto(),
                                      const SizedBox(width: 12),
                                      Expanded(child: buildInfo()),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  buildActionButton(),
                                ],
                              )
                            : Row(
                                children: [
                                  buildPhoto(),
                                  const SizedBox(width: 20),
                                  Expanded(child: buildInfo()),
                                  const SizedBox(width: 12),
                                  buildActionButton(),
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: iconColor),
                ),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
