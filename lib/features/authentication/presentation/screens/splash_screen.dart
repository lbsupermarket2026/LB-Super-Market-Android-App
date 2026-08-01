import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _green = Color(0xFF2E7D32);

/// Shown briefly while authStateChangesProvider AND
/// splashMinimumDurationProvider both resolve — RouteGuard owns the
/// actual timing/redirect decision, this screen just renders.
///
/// FIXED: zoomed/cropped look was BoxFit.fitWidth inside a
/// StackFit.expand, which fills screen width and lets height
/// overflow/crop on any device whose aspect ratio doesn't exactly
/// match the source image. Switched to BoxFit.contain so the full
/// illustration is always visible, letterboxed if needed, never cropped.
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Image.asset(
              'assets/images/splash_illustration.png',
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.storefront, size: 72, color: _green),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 110,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black45],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _openDeveloperSite,
                      child: const Text(
                        'Developed by Matric Services',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}