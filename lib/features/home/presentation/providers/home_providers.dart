import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/home_remote_datasource.dart';
import '../../domain/entities/banner_entity.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((ref) {
  return HomeRemoteDataSource();
});

/// Kept as a direct datasource call (no repository/usecase indirection)
/// since this is a single, simple document read with no business logic
/// to test in isolation — unlike products/categories, which have real
/// query variations and pagination worth abstracting behind a contract.
final homeBannersProvider = FutureProvider<List<BannerEntity>>((ref) async {
  return ref.watch(homeRemoteDataSourceProvider).getHomeBanners();
});
