import '../../core/constants/app_constants.dart';
import 'api_client.dart';

/// Deposit information returned by `GET /savings/deposit-info`. Describes the
/// non-custodial vault contract plus the user's linked on-chain address.
class DepositInfo {
  static const String zeroAddress = '0x0000000000000000000000000000000000000000';

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
    this.privacyEnabled = false,
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

  /// When true the vault uses commitment-based balances: deposits are matched
  /// via keccak256(address, salt) and the raw address never appears in on-chain
  /// deposit events.
  final bool privacyEnabled;

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
        privacyEnabled: j['privacy_enabled'] == true,
      );
}

/// Live on-chain vault status returned by `GET /savings/vault-status`: the
/// deposit info plus the vault's current on-chain stablecoin balance.
class VaultStatus {
  const VaultStatus({
    required this.address,
    required this.vaultContract,
    required this.stablecoinSymbol,
    required this.stablecoinName,
    required this.stablecoinDecimals,
    required this.stablecoinContract,
    required this.network,
    required this.chainId,
    required this.mode,
    required this.vaultUsdcBalance,
    this.privacyEnabled = false,
    this.withdrawMinMinor = 0,
    this.withdrawMaxMinor = 0,
    this.withdrawDailyCapMinor = 0,
    this.elevationThresholdMinor = 0,
    this.elevationDelaySeconds = 0,
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
  final String vaultUsdcBalance;

  /// When true the vault uses commitment-based (salt-hashed) balances.
  final bool privacyEnabled;

  /// Operator-configured withdrawal guards in NGN minor units (kobo).
  /// Zero means that guard is disabled. Absent on older servers.
  final int withdrawMinMinor;
  final int withdrawMaxMinor;
  final int withdrawDailyCapMinor;
  final int elevationThresholdMinor;
  final int elevationDelaySeconds;

  bool get hasAddress => address.isNotEmpty && address != '0x0000000000000000000000000000000000000000';

  factory VaultStatus.fromJson(Map<String, dynamic> j) {
    final info =
        (j['deposit_info'] as Map<String, dynamic>?) ?? j; // tolerate flat shape
    final limits = (j['withdraw_limits'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return VaultStatus(
      address: info['address'] as String? ?? '',
      vaultContract: info['vault_contract'] as String? ?? '',
      stablecoinSymbol: info['stablecoin_symbol'] as String? ?? 'USDC',
      stablecoinName: info['stablecoin_name'] as String? ?? '',
      stablecoinDecimals: (info['stablecoin_decimals'] as num?)?.toInt() ?? 6,
      stablecoinContract: info['stablecoin_contract'] as String? ?? '',
      network: info['network'] as String? ?? '',
      chainId: (info['chain_id'] as num?)?.toInt() ?? 0,
      mode: info['mode'] as String? ?? '',
      privacyEnabled: info['privacy_enabled'] == true,
      vaultUsdcBalance: j['vault_usdc_balance'] as String? ?? '0',
      withdrawMinMinor: (limits['min_minor'] as num?)?.toInt() ?? 0,
      withdrawMaxMinor: (limits['max_minor'] as num?)?.toInt() ?? 0,
      withdrawDailyCapMinor: (limits['daily_cap_minor'] as num?)?.toInt() ?? 0,
      elevationThresholdMinor:
          (limits['elevation_threshold_minor'] as num?)?.toInt() ?? 0,
      elevationDelaySeconds:
          (limits['elevation_delay_seconds'] as num?)?.toInt() ?? 0,
    );
  }
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

  Future<VaultStatus> getVaultStatus() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/savings/vault-status');
    if (data == null) throw ApiException(0, 'Empty response from server');
    return VaultStatus.fromJson(data);
  }

  Future<DepositInfo> setDepositAddress(String address) async {
    final data = await _api.put(
      '${AppConstants.apiV1Prefix}/savings/deposit-address',
      body: {'address': address},
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    return DepositInfo.fromJson(data);
  }

  /// Converts NGN to USDC and sends it on-chain from the user's vault to the
  /// destination crypto address. Returns the on-chain transaction hash.
  Future<String> withdrawToAddress({
    required String amount,
    required String destination,
    required String pin,
  }) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/savings/withdraw',
      idempotent: true,
      body: {'amount': amount, 'destination': destination, 'pin': pin},
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    return data['tx_hash'] as String? ?? '';
  }

  /// Lists the user's pending time-locked (elevated) withdrawals.
  Future<List<PendingElevation>> listPendingElevations() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/savings/withdraw');
    final list = (data?['elevations'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PendingElevation.fromJson)
        .toList();
  }

  /// Cancels a pending elevation before its release time. Returns true when
  /// the server confirms the cancellation.
  Future<bool> cancelElevation(String id) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/savings/withdraw/$id/cancel',
    );
    return data?['cancelled'] == true;
  }
}

/// A time-locked (elevated) withdrawal waiting for its release time. Amounts
/// arrive in NGN minor units (kobo) and are exposed in major units.
class PendingElevation {
  const PendingElevation({
    required this.id,
    required this.destination,
    required this.amountNgn,
    required this.feeNgn,
    required this.status,
    required this.releaseAfter,
  });

  final String id;
  final String destination;
  final double amountNgn;
  final double feeNgn;
  final String status;
  final DateTime releaseAfter;

  /// Time left until broadcast. Negative when already due.
  Duration get remaining => releaseAfter.difference(DateTime.now());

  factory PendingElevation.fromJson(Map<String, dynamic> j) {
    DateTime release;
    try {
      release = DateTime.parse(j['release_after'] as String? ?? '');
    } catch (_) {
      release = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return PendingElevation(
      id: j['id'] as String? ?? '',
      destination: j['destination'] as String? ?? '',
      amountNgn: ((j['amount_ngn_minor'] as num?) ?? 0) / 100,
      feeNgn: ((j['fee_ngn_minor'] as num?) ?? 0) / 100,
      status: j['status'] as String? ?? 'pending',
      releaseAfter: release,
    );
  }
}
