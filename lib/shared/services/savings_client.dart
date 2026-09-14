import '../../core/constants/app_constants.dart';
import 'api_client.dart';

/// Deposit information returned by `GET /savings/deposit-info`. Describes the
/// vault plus the user's own on-chain deposit address (a per-user clone that
/// needs no wallet linking to receive).
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
    this.requireUserSignature = false,
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

  /// When true EIP-712 signature-gated withdrawals are enforced: withdrawals
  /// and recovery changes must be signed by the user's wallet, and the
  /// transitional platform-signer (PIN) path is disabled. Absent on older
  /// servers → false (transitional).
  final bool requireUserSignature;

  bool get hasAddress => address.isNotEmpty && address != '0x0000000000000000000000000000000000000000';

  /// Human-friendly network name (e.g. "Ethereum (Sepolia)") derived from the
  /// chain id, falling back to the raw backend network string.
  String get networkLabel {
    switch (chainId) {
      case 1:
        return 'Ethereum';
      case 11155111:
        return 'Ethereum (Sepolia)';
      case 137:
        return 'Polygon';
      case 10:
        return 'Optimism';
      case 11155420:
        return 'Optimism (Sepolia)';
      case 8453:
        return 'Base';
      case 84532:
        return 'Base (Sepolia)';
      case 42161:
        return 'Arbitrum One';
      case 421614:
        return 'Arbitrum (Sepolia)';
      case 56:
        return 'BSC';
      case 1337:
      case 31337:
        return 'Local testnet';
    }
    return network.isNotEmpty ? network : 'on-chain';
  }

  /// The stablecoin identity, e.g. "USDC · USD Coin".
  String get assetLabel => stablecoinName.isNotEmpty
      ? '$stablecoinSymbol · $stablecoinName'
      : stablecoinSymbol;

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
        requireUserSignature: j['require_user_signature'] == true,
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
    this.requireUserSignature = false,
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

  /// When true EIP-712 signature-gated withdrawals are enforced (see
  /// [DepositInfo.requireUserSignature]); false = transitional PIN path.
  final bool requireUserSignature;

  /// Operator-configured withdrawal guards in NGN minor units (kobo).
  /// Zero means that guard is disabled. Absent on older servers.
  final int withdrawMinMinor;
  final int withdrawMaxMinor;
  final int withdrawDailyCapMinor;
  final int elevationThresholdMinor;
  final int elevationDelaySeconds;

  /// Human-friendly network name (e.g. "Ethereum (Sepolia)") derived from the
  /// chain id, falling back to the raw backend network string. Mirrors
  /// DepositInfo.networkLabel.
  String get networkLabel {
    switch (chainId) {
      case 1:
        return 'Ethereum';
      case 11155111:
        return 'Ethereum (Sepolia)';
      case 137:
        return 'Polygon';
      case 10:
        return 'Optimism';
      case 11155420:
        return 'Optimism (Sepolia)';
      case 8453:
        return 'Base';
      case 84532:
        return 'Base (Sepolia)';
      case 42161:
        return 'Arbitrum One';
      case 421614:
        return 'Arbitrum (Sepolia)';
      case 56:
        return 'BSC';
      case 1337:
      case 31337:
        return 'Local testnet';
    }
    return network.isNotEmpty ? network : 'on-chain';
  }

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
      requireUserSignature: info['require_user_signature'] == true,
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
  /// destination crypto address. When [signature] is present, the withdrawal is
  /// relayed as the owner-signed `withdrawWithSig` (self-custody); without it
  /// the server uses the transitional path (or refuses under
  /// GLOBMINT_REQUIRE_USER_SIGNATURE). Returns the on-chain transaction hash,
  /// or the pending time-lock when the amount is elevated.
  Future<WithdrawResult> withdrawToAddress({
    required String amount,
    required String destination,
    required String pin,
    WithdrawSignature? signature,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'destination': destination,
      'pin': pin,
    };
    if (signature != null && signature.signature.isNotEmpty) {
      body['signature'] = signature.signature;
      body['deadline'] = signature.deadline;
      body['nonce'] = signature.nonce;
      body['amount_minor_base'] = signature.amountMinorBase;
    }
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/savings/withdraw',
      idempotent: true,
      body: body,
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    final elevationJson = data['elevation'] as Map<String, dynamic>?;
    return WithdrawResult(
      txHash: data['tx_hash'] as String? ?? '',
      elevation: elevationJson == null ? null : PendingElevation.fromJson(elevationJson),
    );
  }

  /// Quotes the exact EIP-712 payload a user would sign before a self-custody
  /// withdrawal: the domain + `WithdrawRequest` message to authorize (covering
  /// the current clone nonce and the USDC base amount), plus the owner seat so
  /// the client can tell which wallet must sign. No funds move.
  Future<WithdrawQuote> prepareWithdrawal({
    required String amount,
    required String destination,
  }) async {
    final q = Uri(queryParameters: {
      'amount': amount,
      'destination': destination,
    });
    final data = await _api.get(
      '${AppConstants.apiV1Prefix}/savings/withdraw/prepare?${q.query}',
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    return WithdrawQuote.fromJson(data);
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

  /// Relays the platform-signed `transferOwnershipBySig` handing the clone
  /// owner seat to the user's connected wallet [newOwner]. The signature comes
  /// from the CURRENT owner — the platform signer — because the clone contract
  /// only accepts the current owner's signature; claiming with the same key is
  /// refused as CONFLICT so retries under an idempotency key are safe.
  Future<CustodyClaimResult> claimCustody(String newOwner) async {
    final data = await _api.post(
      '${AppConstants.apiV1Prefix}/savings/custody/claim',
      idempotent: true,
      body: {'new_owner': newOwner},
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    return CustodyClaimResult(
      claimed: data['claimed'] == true,
      newOwner: data['new_owner'] as String? ?? newOwner,
      txHash: data['tx_hash'] as String? ?? '',
    );
  }

  /// Returns the user's clone recovery state as read from the chain:
  /// the designated recovery address, the armed delay, and any in-flight
  /// recovery window. Chain-authoritative with a cache fallback server-side.
  Future<RecoveryStatus> getRecoveryStatus() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/savings/recovery');
    if (data == null) throw ApiException(0, 'Empty response from server');
    return RecoveryStatus.fromJson(data);
  }

  /// Returns who currently controls the user's clone owner seat: the user's own
  /// wallet (claimed) or the platform placeholder signer (unclaimed — custody
  /// must be taken before signing withdrawals). The placeholder comes from the
  /// server so the client never hardcodes a signer address.
  Future<CustodyStatus> getCustodyStatus() async {
    final data = await _api.get('${AppConstants.apiV1Prefix}/savings/custody');
    if (data == null) throw ApiException(0, 'Empty response from server');
    return CustodyStatus.fromJson(data);
  }

  /// Quotes the exact EIP-712 `TransferOwnership` payload the CURRENT owner of
  /// an unclaimed clone authorizes when the platform signer hands the owner
  /// seat to the user's wallet: the domain + message (covering the current
  /// clone nonce) plus the owner seat so the client can explain who signs. No
  /// funds move and nothing is persisted.
  Future<CustodyQuote> prepareCustody(String newOwner) async {
    final q = Uri(queryParameters: {'new_owner': newOwner});
    final data = await _api.get(
      '${AppConstants.apiV1Prefix}/savings/custody/prepare?${q.query}',
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    return CustodyQuote.fromJson(data);
  }

  /// Quotes the exact EIP-712 `SetRecovery` payload a user would sign before
  /// designating [recoveryAddress] on their clone: the domain + message
  /// (covering the current clone nonce) plus the owner seat so the client can
  /// tell which wallet must sign. No funds move.
  Future<RecoveryQuote> prepareRecovery(String recoveryAddress) async {
    final q = Uri(queryParameters: {'recovery_address': recoveryAddress});
    final data = await _api.get(
      '${AppConstants.apiV1Prefix}/savings/recovery/prepare?${q.query}',
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    return RecoveryQuote.fromJson(data);
  }

  /// Relays the owner-signed `setRecoveryAddressBySig` on the user's clone to
  /// designate [recoveryAddress]. The signature must have been produced by the
  /// clone owner over the exact message [prepareRecovery] quoted. Returns the
  /// on-chain transaction hash.
  Future<RecoverySignatureResult> setRecoveryAddress({
    required String recoveryAddress,
    required RecoverySignature signature,
  }) async {
    final data = await _api.put(
      '${AppConstants.apiV1Prefix}/savings/recovery',
      body: {
        'recovery_address': recoveryAddress,
        'signature': signature.signature,
        'deadline': signature.deadline,
        'nonce': signature.nonce,
      },
    );
    if (data == null) throw ApiException(0, 'Empty response from server');
    return RecoverySignatureResult(
      recoveryAddress: data['recovery_address'] as String? ?? recoveryAddress,
      txHash: data['tx_hash'] as String? ?? '',
    );
  }
}

/// The outcome of submitting a withdrawal: an instant transaction hash, or the
/// pending time-lock when the amount sits above the elevation threshold.
class WithdrawResult {
  const WithdrawResult({required this.txHash, this.elevation});

  final String txHash;
  final PendingElevation? elevation;
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

  /// Human-friendly description of the remaining time-lock.
  String get durationLabel {
    final d = remaining;
    if (d.isNegative) return 'broadcast now';
    final h = d.inHours;
    if (h >= 48) return '${(h / 24).round()} days';
    if (h >= 1) return '$h hours';
    final m = d.inMinutes;
    if (m >= 1) return '$m minutes';
    return 'moments away';
  }

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

/// A client-shaped EIP-712 withdrawal signature returned from
/// [EthereumProvider.signWithdrawal] and submitted to the withdraw endpoint.
/// `amountMinorBase` mirrors the server's `amount_minor_base`: the exact
/// stablecoin base units (micro-USDC) the signature authorizes.
class WithdrawSignature {
  const WithdrawSignature({
    required this.signature,
    required this.deadline,
    required this.nonce,
    required this.amountMinorBase,
  });

  final String signature;
  final int deadline;
  final int nonce;
  final int amountMinorBase;
}

/// The EIP-712 domain a wallet needs for eth_signTypedData_v4, as quoted by
/// `GET /savings/withdraw/prepare`.
class Eip712Domain {
  const Eip712Domain({
    required this.name,
    required this.version,
    required this.chainId,
    required this.verifyingContract,
  });

  final String name;
  final String version;
  final int chainId;
  final String verifyingContract;

  factory Eip712Domain.fromJson(Map<String, dynamic> j) => Eip712Domain(
        name: j['name'] as String? ?? 'GlobmintVault',
        version: j['version'] as String? ?? '1',
        chainId: (j['chain_id'] as num?)?.toInt() ?? 0,
        verifyingContract: j['verifying_contract'] as String? ?? '',
      );
}

/// The `WithdrawRequest(to, amount, nonce, deadline)` message to sign.
class QuoteMessage {
  const QuoteMessage({
    required this.to,
    required this.amount,
    required this.nonce,
    required this.deadline,
  });

  final String to;

  /// Stablecoin base units as a decimal string (can exceed JS-safe ints).
  final String amount;

  /// Current on-chain clone nonce the signature must cover.
  final int nonce;

  /// Unix-seconds expiry of the signature.
  final int deadline;

  factory QuoteMessage.fromJson(Map<String, dynamic> j) => QuoteMessage(
        to: j['to'] as String? ?? '',
        amount: j['amount'] as String? ?? '0',
        nonce: (j['nonce'] as num?)?.toInt() ?? 0,
        deadline: (j['deadline'] as num?)?.toInt() ?? 0,
      );
}

/// The full quote returned by `GET /savings/withdraw/prepare`: the exact typed
/// data to authorize plus the amount/fee/owner context the review screen shows.
class WithdrawQuote {
  const WithdrawQuote({
    required this.domain,
    required this.primaryType,
    required this.message,
    required this.amountNgnMinor,
    required this.feeNgnMinor,
    required this.amountMinorBase,
    required this.cloneOwner,
  });

  final Eip712Domain domain;
  final String primaryType;
  final QuoteMessage message;
  final int amountNgnMinor;
  final int feeNgnMinor;
  final String amountMinorBase;

  /// The current clone owner seat — the wallet that must sign.
  final String cloneOwner;

  factory WithdrawQuote.fromJson(Map<String, dynamic> j) => WithdrawQuote(
        domain: Eip712Domain.fromJson(
            (j['domain'] as Map?)?.cast<String, dynamic>() ?? const {}),
        primaryType: j['primary_type'] as String? ?? 'WithdrawRequest',
        message: QuoteMessage.fromJson(
            (j['message'] as Map?)?.cast<String, dynamic>() ?? const {}),
        amountNgnMinor: (j['amount_ngn_minor'] as num?)?.toInt() ?? 0,
        feeNgnMinor: (j['fee_ngn_minor'] as num?)?.toInt() ?? 0,
        amountMinorBase: j['amount_minor_base'] as String? ?? '',
        cloneOwner: j['clone_owner'] as String? ?? '',
      );
}

/// The clone's recovery state returned by `GET /savings/recovery`. The clone
/// contract is the source of truth; the cache only backs the UI when the node
/// is unreachable.
class RecoveryStatus {
  const RecoveryStatus({
    required this.clone,
    required this.owner,
    required this.recoveryAddress,
    required this.recoveryDelaySec,
    required this.recoveryRequestedAt,
    required this.recoveryAt,
    required this.recoveryPending,
  });

  /// The per-user clone address. Empty when the account has none.
  final String clone;

  /// The current owner seat (the user's wallet, or the platform signer as a
  /// placeholder until the user claims custody).
  final String owner;

  /// The designated backup address; empty when none is set.
  final String recoveryAddress;

  /// Armed recovery delay in seconds; 0 when recovery is not armed.
  final int recoveryDelaySec;

  /// Unix seconds when a recovery was initiated; 0 when none is pending.
  final int recoveryRequestedAt;

  /// Unix seconds when a pending recovery becomes executable; 0 when none.
  final int recoveryAt;

  /// Whether a recovery is currently in flight for this clone.
  final bool recoveryPending;

  /// Human-friendly armed delay ("3 days", "24 hours", "not armed").
  String get delayLabel {
    if (recoveryDelaySec <= 0) return 'not armed';
    final h = recoveryDelaySec ~/ 3600;
    if (h >= 48) return '${(h / 24).round()} days';
    if (h >= 1) return '$h hours';
    return '${recoveryDelaySec ~/ 60} minutes';
  }

  String get ownerShort => _shorten(owner);
  String get cloneShort => _shorten(clone);
  String get recoveryShort => _shorten(recoveryAddress);

  static String _shorten(String addr) {
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }

  factory RecoveryStatus.fromJson(Map<String, dynamic> j) => RecoveryStatus(
        clone: j['clone'] as String? ?? '',
        owner: j['owner'] as String? ?? '',
        recoveryAddress: j['recovery_address'] as String? ?? '',
        recoveryDelaySec: (j['recovery_delay_sec'] as num?)?.toInt() ?? 0,
        recoveryRequestedAt: (j['recovery_requested_at'] as num?)?.toInt() ?? 0,
        recoveryAt: (j['recovery_at'] as num?)?.toInt() ?? 0,
        recoveryPending: j['recovery_pending'] == true,
      );
}

/// The clone's custody state returned by `GET /savings/custody`. The clone
/// contract is the source of truth; the cache only backs the UI when the node
/// is unreachable.
class CustodyStatus {
  const CustodyStatus({
    required this.clone,
    required this.owner,
    required this.placeholder,
    required this.claimed,
    required this.nonce,
  });

  /// The per-user clone address. Empty when the account has none.
  final String clone;

  /// The current owner seat (the user's wallet, or the platform signer as a
  /// placeholder until the user claims custody).
  final String owner;

  /// The platform signer address an unclaimed clone reverts to; empty when the
  /// server has none configured (then any real owner counts as claimed).
  final String placeholder;

  /// Whether the clone owner is NOT the platform placeholder — i.e. the user's
  /// own wallet controls it and can sign withdrawals.
  final bool claimed;

  /// The clone's current request nonce, shared by `withdrawWithSig`,
  /// `setRecoveryAddressBySig` and `transferOwnershipBySig`.
  final int nonce;

  String get ownerShort => _shorten(owner);
  String get cloneShort => _shorten(clone);
  String get placeholderShort => _shorten(placeholder);

  static String _shorten(String addr) {
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
  }

  factory CustodyStatus.fromJson(Map<String, dynamic> j) => CustodyStatus(
        clone: j['clone'] as String? ?? '',
        owner: j['owner'] as String? ?? '',
        placeholder: j['placeholder'] as String? ?? '',
        claimed: j['claimed'] == true,
        nonce: (j['nonce'] as num?)?.toInt() ?? 0,
      );
}

/// The `TransferOwnership(newOwner, nonce, deadline)` message the CURRENT
/// owner of an unclaimed clone authorizes to hand the owner seat away.
class CustodyMessage {
  const CustodyMessage({
    required this.newOwner,
    required this.nonce,
    required this.deadline,
  });

  /// The wallet address taking custody of the clone.
  final String newOwner;

  /// Current on-chain clone nonce the signature must cover.
  final int nonce;

  /// Unix-seconds expiry of the signature.
  final int deadline;

  factory CustodyMessage.fromJson(Map<String, dynamic> j) => CustodyMessage(
        newOwner: j['new_owner'] as String? ??
            j['newOwner'] as String? ??
            '',
        nonce: (j['nonce'] as num?)?.toInt() ?? 0,
        deadline: (j['deadline'] as num?)?.toInt() ?? 0,
      );
}

/// The full quote returned by `GET /savings/custody/prepare`: the exact
/// `TransferOwnership` typed data the current owner must authorize, plus the
/// owner seat. While the clone is unclaimed the owner IS the platform
/// placeholder, so the platform signer (the only address the contract accepts)
/// produces the signature; this quote exists so the client can show users
/// exactly what is being signed and to whom custody is handed.
class CustodyQuote {
  const CustodyQuote({
    required this.domain,
    required this.primaryType,
    required this.message,
    required this.cloneOwner,
  });

  final Eip712Domain domain;
  final String primaryType;
  final CustodyMessage message;

  /// The current clone owner seat — the address whose key must sign.
  final String cloneOwner;

  factory CustodyQuote.fromJson(Map<String, dynamic> j) => CustodyQuote(
        domain: Eip712Domain.fromJson(
            (j['domain'] as Map<String, dynamic>?) ?? const {}),
        primaryType: j['primary_type'] as String? ?? 'TransferOwnership',
        message: CustodyMessage.fromJson(
            (j['message'] as Map<String, dynamic>?) ?? const {}),
        cloneOwner: j['clone_owner'] as String? ?? '',
      );
}

/// The acknowledged result of `POST /savings/custody/claim`.
class CustodyClaimResult {
  const CustodyClaimResult({
    required this.claimed,
    required this.newOwner,
    required this.txHash,
  });

  /// True after the relay succeeded; also true when the clone was already
  /// claimed (the claim is idempotent and returns a friendly conflict).
  final bool claimed;

  /// The wallet that now owns the clone.
  final String newOwner;

  /// On-chain transaction hash of the `transferOwnershipBySig` relay.
  final String txHash;
}

/// The `SetRecovery(recoveryAddress, nonce, deadline)` message to sign.
class RecoveryMessage {
  const RecoveryMessage({
    required this.recoveryAddress,
    required this.nonce,
    required this.deadline,
  });

  final String recoveryAddress;

  /// Current on-chain clone nonce the signature must cover.
  final int nonce;

  /// Unix-seconds expiry of the signature.
  final int deadline;

  factory RecoveryMessage.fromJson(Map<String, dynamic> j) => RecoveryMessage(
        recoveryAddress: j['recovery_address'] as String? ?? '',
        nonce: (j['nonce'] as num?)?.toInt() ?? 0,
        deadline: (j['deadline'] as num?)?.toInt() ?? 0,
      );
}

/// The full quote returned by `GET /savings/recovery/prepare`: the exact
/// typed data to authorize plus the owner seat that must sign.
class RecoveryQuote {
  const RecoveryQuote({
    required this.domain,
    required this.primaryType,
    required this.message,
    required this.cloneOwner,
  });

  final Eip712Domain domain;
  final String primaryType;
  final RecoveryMessage message;

  /// The current clone owner seat — the wallet that must sign.
  final String cloneOwner;

  factory RecoveryQuote.fromJson(Map<String, dynamic> j) => RecoveryQuote(
        domain: Eip712Domain.fromJson(
            (j['domain'] as Map?)?.cast<String, dynamic>() ?? const {}),
        primaryType: j['primary_type'] as String? ?? 'SetRecovery',
        message: RecoveryMessage.fromJson(
            (j['message'] as Map?)?.cast<String, dynamic>() ?? const {}),
        cloneOwner: j['clone_owner'] as String? ?? '',
      );
}

/// A client-shaped EIP-712 signature over `SetRecovery(recoveryAddress, nonce,
/// deadline)`, returned from [EthereumProvider.signRecovery] and submitted to
/// `PUT /savings/recovery`.
class RecoverySignature {
  const RecoverySignature({
    required this.signature,
    required this.deadline,
    required this.nonce,
  });

  final String signature;
  final int deadline;
  final int nonce;
}

/// The server confirmation for a designated recovery address.
class RecoverySignatureResult {
  const RecoverySignatureResult({
    required this.recoveryAddress,
    required this.txHash,
  });

  final String recoveryAddress;
  final String txHash;
}
