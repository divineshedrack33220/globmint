import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed beneficiary (saved payee) service.
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
    required String bank,
    required String accountNumber,
    bool isFavorite = false,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/beneficiaries',
      body: {
        'name': name,
        'bank': bank,
        'account_number': accountNumber,
        'is_favorite': isFavorite,
      },
    );
    return _fromApi((data?['beneficiary'] as Map<String, dynamic>?) ?? {});
  }

  Future<void> toggleFavorite(String id) async {
    await _api.post('${AppConstants.apiV1Prefix}/beneficiaries/$id/favorite');
  }

  Future<void> remove(String id) async {
    await _api.delete('${AppConstants.apiV1Prefix}/beneficiaries/$id');
  }

  /// Resolves a bank account number to a beneficiary (name + bank), if known.
  Future<Beneficiary?> resolveAccount(String accountNumber) async {
    final data = await _api.get(
      '${AppConstants.apiV1Prefix}/beneficiaries/account/$accountNumber',
    );
    if (data == null) return null;
    final b = data['beneficiary'] as Map<String, dynamic>?;
    if (b == null) return null;
    return _fromApi(b);
  }

  Beneficiary _fromApi(Map<String, dynamic> j) => Beneficiary(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        bank: j['bank'] as String? ?? '',
        accountNumber: j['account_number'] as String? ?? '',
        isFavorite: j['is_favorite'] as bool? ?? false,
      );
}
