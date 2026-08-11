import 'package:flutter/material.dart';

/// Fullscreen pinch-to-zoom photo viewer, opened on top of everything
/// (black background, close button, pannable/zoomable via
/// InteractiveViewer). Used wherever a photo needs a proper close-up
/// look — e.g. admin reviewing a customer's handwritten list photo.
class ZoomablePhotoView extends StatelessWidget {
  final String imageUrl;
  const ZoomablePhotoView({super.key, required this.imageUrl});

  /// Opens this as a fullscreen route on top of the current screen.
  static void open(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ZoomablePhotoView(imageUrl: imageUrl),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
          ),
        ),
      ),
    );
  }
}
