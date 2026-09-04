import '../../core/constants/app_constants.dart';
import 'api_client.dart';

/// Deposit information returned by `GET /savings/deposit-info`. Describes the
/// non-custodial vault contract plus the user's linked on-chain address.
class DepositInfo {
  const DepositInfo({
    required this.address,
    required this.vaultContract,
    required this.stablecoinSymbol,
    required this.stablecoinName,
    required this.stablecoinDecimals,
    required this.stablecoinContract,
    required this.network,
    required this.chainId,
    required this.mode,
  });

  final String address;
  final String vaultContract;
  final String stablecoinSymbol;
  final String stablecoinName;
  final int stablecoinDecimals;
  final String stablecoinContract;
  final String network;
  final int chainId;
  final String mode;

  bool get hasAddress => address.isNotEmpty && address != '0x0000000000000000000000000000000000000000';

  factory DepositInfo.fromJson(Map<String, dynamic> j) => DepositInfo(
        address: j['address'] as String? ?? '',
        vaultContract: j['vault_contract'] as String? ?? '',
        stablecoinSymbol: j['stablecoin_symbol'] as String? ?? 'USDC',
        stablecoinName: j['stablecoin_name'] as String? ?? '',
        stablecoinDecimals: (j['stablecoin_decimals'] as num?)?.toInt() ?? 6,
        stablecoinContract: j['stablecoin_contract'] as String? ?? '',
        network: j['network'] as String? ?? '',
        chainId: (j['chain_id'] as num?)?.toInt() ?? 0,
        mode: j['mode'] as String? ?? '',
      );
}

/// Real backend-backed client for the savings/deposit-address endpoints.
class SavingsClient {
  SavingsClient(this._api);

  final ApiClient _api;

  Future<DepositInfo> getDepositInfo() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/savings/deposit-info');
    if (data == null) throw ApiException(0, 'Empty response from server');
    return DepositInfo.fromJson(data);
  }

  Future<DepositInfo> setDepositAddress(String address) async {
    final data = await _api.put(
      '${AppConstants.apiV1Prefix}/savings/deposit-address',
      body: {'address': address},
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    return DepositInfo.fromJson(data);
  }
}
