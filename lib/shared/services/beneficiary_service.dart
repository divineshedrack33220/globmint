import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed beneficiary (saved crypto-address contact) service.
class BeneficiaryService {
  BeneficiaryService(this._api);

  final ApiClient _api;

  Future<List<Beneficiary>> getBeneficiaries() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/beneficiaries');
    final list = ((data?['beneficiaries'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return list.map(_fromApi).toList();
  }

  Future<Beneficiary> create({
    required String name,
    required String address,
    bool isFavorite = false,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/beneficiaries',
      body: {
        'name': name,
        'address': address,
        'is_favorite': isFavorite,
      },
    );
    return _fromApi((data?['beneficiary'] as Map<String, dynamic>?) ?? {});
  }

  Future<void> toggleFavorite(String id) async {
    await _api.post('${AppConstants.apiV1Prefix}/beneficiaries/$id/favorite');
  }

  /// Updates an existing beneficiary in place via `PATCH /beneficiaries/{id}`.
  Future<Beneficiary> update({
    required String id,
    required String name,
    required String address,
    bool isFavorite = false,
  }) async {
    final data = await _api.patch(
      '${AppConstants.apiV1Prefix}/beneficiaries/$id',
      body: {
        'name': name,
        'address': address,
        'is_favorite': isFavorite,
      },
    );
    return _fromApi((data?['beneficiary'] as Map<String, dynamic>?) ?? {});
  }

  Future<void> remove(String id) async {
    await _api.delete('${AppConstants.apiV1Prefix}/beneficiaries/$id');
  }

  Beneficiary _fromApi(Map<String, dynamic> j) => Beneficiary(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        address: j['address'] as String? ?? '',
        isFavorite: j['is_favorite'] as bool? ?? false,
      );
}