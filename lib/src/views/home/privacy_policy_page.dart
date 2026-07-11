import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Last updated: May 18, 2026',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 24),
              Text(
                '1. Information We Collect',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We collect information you provide directly to us when you create an account, such as your username, email address, and password. We also collect data from Google if you choose to sign in using your Google account.',
              ),
              SizedBox(height: 16),
              Text(
                '2. How We Use Your Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We use the information we collect to provide, maintain, and improve our services, to process your login requests, and to communicate with you about your account.',
              ),
              SizedBox(height: 16),
              Text(
                '3. Information Sharing and Disclosure',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We do not share your personal information with third parties except as described in this policy, such as with your consent or to comply with legal obligations.',
              ),
              SizedBox(height: 16),
              Text(
                '4. Data Security',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We take reasonable measures to help protect information about you from loss, theft, misuse, and unauthorized access.',
              ),
              SizedBox(height: 16),
              Text(
                '5. Contact Us',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'If you have any questions about this Privacy Policy, please contact us at support@cloudsensevis.com.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
