import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _green = Color(0xFF2E7D32);

/// Shown briefly while authStateChangesProvider resolves its first value.
/// The router redirect logic moves the user on from here automatically —
/// this screen never navigates itself.
///
/// Built around the client's own designed splash illustration (logo,
/// app name, tagline, trust badges, and product basket all baked into
/// one image) rather than recreating those elements in code — this is
/// their own design asset, not third-party material, so using it
/// directly is the right call here.
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
          Image.asset(
            'assets/images/splash_illustration.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.storefront, size: 72, color: _green),
            ),
          ),
          // Loading indicator + attribution over the bottom of the
          // illustration, same spot this has lived throughout the app.
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
