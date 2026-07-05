import 'package:equatable/equatable.dart';

class BannerEntity extends Equatable {
  final String imageUrl;
  final String? title;
  final String? deepLink;

  const BannerEntity({required this.imageUrl, this.title, this.deepLink});

  @override
  List<Object?> get props => [imageUrl, title, deepLink];
}
