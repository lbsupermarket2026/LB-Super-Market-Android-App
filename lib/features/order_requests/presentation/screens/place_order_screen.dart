import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/order_request_entity.dart';
import 'type_list_screen.dart';
import 'review_order_request_screen.dart';

// Same store contact number used for WhatsApp Order — kept here too so
// the call button on this screen doesn't depend on the Orders screen.
const _callNumber = '7989694819';

class PlaceOrderScreen extends StatefulWidget {
  const PlaceOrderScreen({super.key});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  List<String>? _typedLines;
  File? _photoFile;

  bool get _canReview => (_typedLines?.isNotEmpty ?? false) || _photoFile != null;

  Future<void> _openTypeList() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => TypeListScreen(initialLines: _typedLines)),
    );
    if (result != null) {
      setState(() {
        _typedLines = result;
        _photoFile = null; // only one method active at a time
      });
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _photoFile = File(picked.path);
        _typedLines = null; // only one method active at a time
      });
    }
  }

  void _reviewAndPlace() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewOrderRequestScreen(
          type: _typedLines != null ? OrderRequestType.typedList : OrderRequestType.photo,
          itemLines: _typedLines ?? const [],
          photoFile: _photoFile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        title: const Text('Place Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Call us',
            onPressed: () async {
              final uri = Uri.parse('tel:$_callNumber');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _OptionCard(
            icon: Icons.edit_note,
            iconColor: const Color(0xFFEF6C00),
            iconBg: const Color(0xFFEF6C00).withOpacity(0.1),
            title: 'Type my list',
            subtitle: 'Add items one by one with name & quantity',
            onTap: _openTypeList,
          ),
          const SizedBox(height: AppSpacing.md),
          _OptionCard(
            icon: Icons.photo_camera_outlined,
            iconColor: const Color(0xFF00897B),
            iconBg: const Color(0xFF00897B).withOpacity(0.1),
            title: 'Upload a photo',
            subtitle: 'Take a photo of your handwritten list',
            onTap: _pickPhoto,
          ),
          const SizedBox(height: AppSpacing.md),
          _OptionCard(
            icon: Icons.shopping_basket_outlined,
            iconColor: const Color(0xFF2E7D32),
            iconBg: const Color(0xFF2E7D32).withOpacity(0.1),
            title: 'Browse & Select Products',
            subtitle: 'Search our catalogue, add items to cart & checkout',
            badge: 'RECOMMENDED',
            onTap: () => context.push('/search'),
          ),
          if (_typedLines != null || _photoFile != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _typedLines != null
                          ? '${_typedLines!.length} item${_typedLines!.length == 1 ? '' : 's'} added'
                          : "Image selected — we'll read your list!",
                    ),
                  ),
                  TextButton(
                    onPressed: _typedLines != null ? _openTypeList : _pickPhoto,
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _canReview
          ? SafeArea(
              minimum: const EdgeInsets.all(AppSpacing.md),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: brandGreen, foregroundColor: Colors.white),
                onPressed: _reviewAndPlace,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Review & Place Order'),
              ),
            )
          : null,
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
