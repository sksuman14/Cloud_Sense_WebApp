import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/views/home/home_theme.dart';
import 'package:cloud_sense_webapp/src/widgets/complaints/admin_complaints_section.dart';

/// Dedicated full-screen page for the Complaint Raise & Support Ticket Platform.
/// Opened via the Support icon in the Admin Dashboard AppBar.
class AdminComplaintsPage extends StatefulWidget {
  final String? adminEmail;
  final bool isDarkMode;

  const AdminComplaintsPage({
    super.key,
    this.adminEmail,
    required this.isDarkMode,
  });

  @override
  State<AdminComplaintsPage> createState() => _AdminComplaintsPageState();
}

class _AdminComplaintsPageState extends State<AdminComplaintsPage> {
  Key _sectionKey = UniqueKey();

  void _reloadSection() {
    setState(() {
      _sectionKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    try {
      final themeProvider = Provider.of<ThemeProvider>(context);
      isDark = themeProvider.isDarkMode;
    } catch (_) {}

    String? email = widget.adminEmail;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      email ??= userProvider.userEmail;
    } catch (_) {}

    final bgColor = isDark ? const Color(0xFF0A121A) : const Color(0xFFF1F5F9);
    final appBarColor = isDark ? const Color(0xFF132230) : const Color(0xFF0284C7);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: appBarColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          tooltip: 'Back to Admin Dashboard',
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isMobile ? 'Support & Complaints' : 'Customer Complaints & Support Platform',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                fontSize: isMobile ? 16 : 19,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Tickets',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _reloadSection,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 10 : 18),
          child: AdminComplaintsSection(
            key: _sectionKey,
            isDarkMode: isDark,
            currentAdminEmail: email,
            onInspectDevice: (devId) {
              // Navigate back to admin and inspect device if needed
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}
