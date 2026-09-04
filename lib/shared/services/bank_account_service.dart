import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Backend-backed bank account (saved payout account) service.
class BankAccountService {
  BankAccountService(this._api);

  final ApiClient _api;

  Future<List<BankAccount>> getAccounts() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/bank-accounts');
    final list = ((data?['bank_accounts'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return list.map(_fromApi).toList();
  }

  Future<BankAccount> create({
    required String bankName,
    required String bankCode,
    required String accountNumber,
    required String accountName,
    bool isDefault = false,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/bank-accounts',
      body: {
        'bank_name': bankName,
        'bank_code': bankCode,
        'account_number': accountNumber,
        'account_name': accountName,
        'is_default': isDefault,
      },
    );
    return _fromApi((data?['bank_account'] as Map<String, dynamic>?) ?? {});
  }

  Future<void> setDefault(String id) async {
    await _api.post('${AppConstants.apiV1Prefix}/bank-accounts/$id/default');
  }

  Future<void> remove(String id) async {
    await _api.delete('${AppConstants.apiV1Prefix}/bank-accounts/$id');
  }

  BankAccount _fromApi(Map<String, dynamic> j) => BankAccount(
        id: j['id'] as String? ?? '',
        bankName: j['bank_name'] as String? ?? '',
        bankCode: j['bank_code'] as String? ?? '',
        accountNumber: j['account_number'] as String? ?? '',
        accountName: j['account_name'] as String? ?? '',
        isDefault: j['is_default'] as bool? ?? false,
      );
}
