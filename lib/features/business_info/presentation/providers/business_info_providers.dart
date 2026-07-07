import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../data/datasources/business_info_remote_datasource.dart';
// import '../../../business_info/data/datasources/business_info_remote_datasource.dart';
import 'package:freshcart/features/business_info/data/datasources/business_info_remote_datasource.dart';
import 'package:freshcart/features/business_info/domain/entities/business_info_entity.dart';

final businessInfoRemoteDataSourceProvider = Provider<BusinessInfoRemoteDataSource>((ref) {
  return BusinessInfoRemoteDataSource();
});

final businessInfoProvider = FutureProvider<BusinessInfoEntity>((ref) {
  return ref.watch(businessInfoRemoteDataSourceProvider).getBusinessInfo();
});