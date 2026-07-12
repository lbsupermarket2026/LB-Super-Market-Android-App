import 'dart:async';
import 'package:flutter/material.dart';

/// A horizontal scrollable row that auto-advances on a timer, pauses
/// while the person is manually dragging it, and also exposes small
/// left/right arrow buttons for manual paging — used for the category
/// strip and product rows on Home.
class AutoScrollRow extends StatefulWidget {
  final List<Widget> children;
  final double itemWidth; // approx width of one item + its spacing
  final EdgeInsets padding;
  final Duration autoScrollInterval;
  final bool showArrows;

  const AutoScrollRow({
    super.key,
    required this.children,
    required this.itemWidth,
    this.padding = EdgeInsets.zero,
    this.autoScrollInterval = const Duration(seconds: 3),
    this.showArrows = true,
  });

  @override
  State<AutoScrollRow> createState() => _AutoScrollRowState();
}

class _AutoScrollRowState extends State<AutoScrollRow> {
  final _controller = ScrollController();
  Timer? _timer;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    if (widget.children.length > 1) _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.autoScrollInterval, (_) {
      if (_userInteracting || !_controller.hasClients) return;
      final max = _controller.position.maxScrollExtent;
      final next = _controller.offset + widget.itemWidth;
      if (next >= max) {
        _controller.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      } else {
        _controller.animateTo(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    });
  }

  void _pauseThenResume() {
    _userInteracting = true;
    _timer?.cancel();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _userInteracting = false;
        _startAutoScroll();
      }
    });
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    _pauseThenResume();
    final target = (_controller.offset + delta).clamp(0.0, _controller.position.maxScrollExtent);
    _controller.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification && notification.dragDetails != null) {
              _pauseThenResume();
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            child: Row(children: widget.children),
          ),
        ),
        if (widget.showArrows && widget.children.length > 2) ...[
          Positioned(
            left: 0,
            child: _ArrowButton(icon: Icons.chevron_left, onTap: () => _scrollBy(-widget.itemWidth)),
          ),
          Positioned(
            right: 0,
            child: _ArrowButton(icon: Icons.chevron_right, onTap: () => _scrollBy(widget.itemWidth)),
          ),
        ],
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
      ),
    );
  }
}
