import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terms of Service',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Last updated: May 18, 2026',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 24),
              Text(
                '1. Acceptance of Terms',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'By accessing or using our services, you agree to be bound by these Terms of Service. If you do not agree to all of these terms, do not use our services.',
              ),
              SizedBox(height: 16),
              Text(
                '2. Account Registration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'You must create an account to use some of our services. You are responsible for maintaining the confidentiality of your account password and for all activities that occur under your account.',
              ),
              SizedBox(height: 16),
              Text(
                '3. Termination',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We reserve the right to terminate or suspend your account and access to our services at our sole discretion, without notice, for conduct that we believe violates these Terms.',
              ),
              SizedBox(height: 16),
              Text(
                '4. Limitation of Liability',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'In no event shall we be liable for any indirect, incidental, special, or consequential damages arising out of or in connection with your use of the services.',
              ),
              SizedBox(height: 16),
              Text(
                '5. Governing Law',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which we operate, without regard to its conflict of law provisions.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
