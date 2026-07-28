import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';

const _green = Color(0xFF2E7D32);
const _greenDark = Color(0xFF1B5E20);
const _greenLight = Color(0xFF7CB342);

/// Shown briefly while authStateChangesProvider resolves its first value.
/// The router redirect logic moves the user on from here automatically —
/// this screen never navigates itself.
///
/// Structure inspired by a reference the client sent, but rebuilt with
/// original icon work and their own logo rather than the reference's
/// imagery — that reference had several real third-party brands'
/// packaging (Colgate, Surf Excel, etc.) prominently in frame, which
/// isn't something to embed into a commercial app.
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
          // Faint scattered watermark icons in the upper portion —
          // same idea as the reference's outline-icon pattern, done
          // with plain Material icons rather than custom artwork.
          const _WatermarkIcons(),

          // Green wave along the bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 130),
              painter: _WavePainter(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Trust badges — same three claims and layout as the
                // reference.
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TrustBadge(icon: Icons.shopping_bag_outlined, label: 'QUALITY\nPRODUCTS'),
                    _BadgeDivider(),
                    _TrustBadge(icon: Icons.two_wheeler_outlined, label: 'FAST\nDELIVERY'),
                    _BadgeDivider(),
                    _TrustBadge(icon: Icons.verified_user_outlined, label: 'SAFE &\nRELIABLE'),
                  ],
                ),

                const Spacer(flex: 2),

                // Logo takes the place the reference used for the
                // product basket — it's the store's own mark, so no
                // licensing concern using it prominently here.
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _green.withOpacity(0.18), blurRadius: 28, spreadRadius: 2)],
                  ),
                  child: Image.asset(
                    'assets/images/bs_logo.png',
                    width: 110,
                    height: 110,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront, size: 56, color: _green),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _greenDark),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fresh groceries, delivered fast',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 18),

                // Generic grocery-category icons rather than any real
                // product's packaging — same "basket full of goods"
                // feeling as the reference without depicting anyone
                // else's trademark.
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GroceryChip(icon: Icons.rice_bowl_outlined, color: Color(0xFFD4A017)),
                    SizedBox(width: 10),
                    _GroceryChip(icon: Icons.local_drink_outlined, color: Color(0xFFEF6C00)),
                    SizedBox(width: 10),
                    _GroceryChip(icon: Icons.egg_outlined, color: Color(0xFF8D6E63)),
                    SizedBox(width: 10),
                    _GroceryChip(icon: Icons.eco_outlined, color: _green),
                    SizedBox(width: 10),
                    _GroceryChip(icon: Icons.icecream_outlined, color: Color(0xFF1E88E5)),
                  ],
                ),

                const SizedBox(height: 22),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3, color: _green),
                ),

                const Spacer(flex: 2),

                GestureDetector(
                  onTap: _openDeveloperSite,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroceryChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _GroceryChip({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _green, width: 1.5)),
          child: Icon(icon, color: _green, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87, height: 1.3),
        ),
      ],
    );
  }
}

class _BadgeDivider extends StatelessWidget {
  const _BadgeDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.black12,
    );
  }
}

/// Faint scattered icons across the top half — purely decorative
/// texture, kept very low-opacity so it reads as background pattern
/// rather than competing with the actual content.
class _WatermarkIcons extends StatelessWidget {
  const _WatermarkIcons();

  @override
  Widget build(BuildContext context) {
    final icons = <(IconData, Alignment)>[
      (Icons.receipt_long_outlined, const Alignment(-0.75, -0.88)),
      (Icons.shopping_bag_outlined, const Alignment(0.7, -0.9)),
      (Icons.local_offer_outlined, const Alignment(-0.85, -0.55)),
      (Icons.storefront_outlined, const Alignment(0.85, -0.5)),
      (Icons.checklist_outlined, const Alignment(-0.7, -0.15)),
      (Icons.two_wheeler_outlined, const Alignment(0.78, -0.15)),
      (Icons.local_mall_outlined, const Alignment(-0.85, 0.15)),
      (Icons.shopping_basket_outlined, const Alignment(0.82, 0.15)),
    ];

    return Stack(
      children: icons
          .map((entry) => Align(
                alignment: entry.$2,
                child: Icon(entry.$1, size: 34, color: _greenLight.withOpacity(0.18)),
              ))
          .toList(),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _green;
    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.6, size.width, size.height * 0.3)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => false;
}
