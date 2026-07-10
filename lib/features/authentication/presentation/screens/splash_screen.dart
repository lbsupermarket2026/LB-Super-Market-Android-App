import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

/// Shown briefly while authStateChangesProvider resolves its first value.
/// The router redirect logic moves the user on from here automatically —
/// this screen never navigates itself.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
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
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Color(0xFF2E7D32)),
            ],
          ),
        ),
      ),
    );
  }
}
