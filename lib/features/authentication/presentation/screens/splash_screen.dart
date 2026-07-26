import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';

const _green = Color(0xFF2E7D32);

/// Shown briefly while authStateChangesProvider resolves its first value.
/// The router redirect logic moves the user on from here automatically —
/// this screen never navigates itself.
///
/// Deliberately kept simple — logo, name, plain loading indicator. No
/// custom animation, since a launch-day build favors something that
/// can't misbehave over something fancier.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<void> _openDeveloperSite() async {
    final uri = Uri.parse('https://www.matricservices.in/');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _green.withOpacity(0.15), blurRadius: 24, spreadRadius: 2),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/bs_logo.png',
                        width: 100,
                        height: 100,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront, size: 50, color: _green),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      AppConstants.appName,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _green),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fresh groceries, delivered fast',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 40),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3, color: _green),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                onTap: _openDeveloperSite,
                child: const Text(
                  'Developed by Matric Services',
                  style: TextStyle(
                    fontSize: 12,
                    color: _green,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
