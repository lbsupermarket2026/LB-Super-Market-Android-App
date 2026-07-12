import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';

/// Shown briefly while authStateChangesProvider resolves its first value.
/// The router redirect logic moves the user on from here automatically —
/// this screen never navigates itself.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  late final AnimationController _walkController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.elasticOut),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
    _introController.forward();

    // Loops the whole walk (person + cart) left to right, continuously,
    // for as long as this screen is showing.
    _walkController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _introController.dispose();
    _walkController.dispose();
    super.dispose();
  }

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
                child: AnimatedBuilder(
                  animation: _introController,
                  builder: (context, child) => Opacity(
                    opacity: _fade.value,
                    child: Transform.scale(scale: _scale.value, child: child),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/bs_logo.png', width: 140, height: 140),
                      const SizedBox(height: 16),
                      Text(
                        AppConstants.appName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 70,
                        width: 220,
                        child: AnimatedBuilder(
                          animation: _walkController,
                          builder: (context, _) => CustomPaint(
                            painter: _WalkingCartPainter(progress: _walkController.value),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(color: Color(0xFF2E7D32)),
                    ],
                  ),
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
                    color: Color(0xFF2E7D32),
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

/// A simple stylized silhouette — a walking figure pushing a shopping
/// cart — animated left to right on a loop, with legs alternating to
/// suggest a walking stride and the whole group bobbing slightly.
class _WalkingCartPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0, looping

  _WalkingCartPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Horizontal travel: slides from off-screen-left to off-screen-right,
    // then snaps back — repeat() on the controller makes that loop cleanly.
    final travel = (size.width + 60) * progress - 30;
    // Small vertical bob synced to a faster cycle than the walk itself,
    // so the stride actually looks like footsteps rather than a glide.
    final bob = (progress * 8 * 3.14159).abs() % (2 * 3.14159);
    final bobOffset = (bob < 3.14159 ? bob / 3.14159 : 2 - bob / 3.14159) * 3;

    canvas.save();
    canvas.translate(travel, size.height - 26 - bobOffset);

    // ---- Cart (drawn first, to the right of the person) ----
    const cartX = 34.0;
    final basket = Rect.fromLTWH(cartX, -30, 30, 20);
    canvas.drawRect(basket, strokePaint);
    // handle
    canvas.drawLine(Offset(cartX, -20), Offset(cartX - 14, -34), strokePaint);
    // wheels
    canvas.drawCircle(Offset(cartX + 4, -6), 3.5, paint);
    canvas.drawCircle(Offset(cartX + 24, -6), 3.5, paint);

    // ---- Person (walking pose, hands forward on the cart handle) ----
    // head
    canvas.drawCircle(const Offset(0, -46), 6, paint);
    // body
    canvas.drawLine(const Offset(0, -40), const Offset(4, -18), strokePaint);
    // arm reaching to the cart handle
    canvas.drawLine(const Offset(2, -34), Offset(cartX - 14, -34), strokePaint);
    // legs — offset by the walk cycle for a stepping look
    final legSwing = (progress * 6 * 3.14159) % (2 * 3.14159);
    final frontLeg = 6.0 + 4.0 * (legSwing < 3.14159 ? 1 : -1);
    final backLeg = 6.0 - 4.0 * (legSwing < 3.14159 ? 1 : -1);
    canvas.drawLine(const Offset(4, -18), Offset(4 + frontLeg, 0), strokePaint);
    canvas.drawLine(const Offset(4, -18), Offset(4 + backLeg, 0), strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WalkingCartPainter oldDelegate) => oldDelegate.progress != progress;
}
