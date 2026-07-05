import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_radii_shadows.dart';
import '../../domain/entities/banner_entity.dart';

class BannerCarousel extends StatefulWidget {
  final List<BannerEntity> banners;

  const BannerCarousel({super.key, required this.banners});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
    }
  }

  void _advance() {
    if (!_controller.hasClients) return;
    final next = (_currentPage + 1) % widget.banners.length;
    _controller.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 7,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: AppRadii.card,
                  child: CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    errorWidget: (context, url, error) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _currentPage ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _currentPage
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
