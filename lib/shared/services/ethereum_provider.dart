import 'dart:convert';

import 'ethereum_provider_bridge.dart' as bridge;
import 'savings_client.dart';

/// A minimal EIP-1193 wallet bridge (MetaMask / injected providers) used to
/// sign EIP-712 withdraw requests in the browser.
///
/// Signing happens in the user's wallet — the backend never sees the private
/// key and can only relay the exact signed `WithdrawRequest` back through
/// `withdrawWithSig` on the user's clone. When no provider is injected (or the
/// app runs on a non-web target), the app degrades to the server-relayed
/// transitional path.
class EthereumProvider {
  EthereumProvider._();

  static final EthereumProvider instance = EthereumProvider._();

  /// True when `window.ethereum` exists (web target with an injected wallet).
  static bool get available => bridge.bridgeAvailable();

  /// Requests an unlocked account (opens the wallet's connect flow).
  Future<List<String>> requestAccounts() => bridge.bridgeRequestAccounts();

  /// Currently connected/authorized accounts without prompting.
  Future<List<String>> accounts() => bridge.bridgeAccounts();

  /// Signs an EIP-712 typed-data payload with `from`'s key via the wallet UI.
  /// Returns the 65-byte `0x`-prefixed signature.
  Future<String> signTypedDataV4(
      String from, Map<String, dynamic> typedData) {
    return bridge.bridgeSignTypedDataV4(from, jsonEncode(typedData));
  }

  /// Builds the exact eth_signTypedData_v4 payload for a server quote. The
  /// types array is identical to the contract's EIP-712 domain + the
  /// `WithdrawRequest(address to,uint256 amount,uint256 nonce,uint256
  /// deadline)` struct, and every uint256 is a canonical hex value.
  Map<String, dynamic> typedDataV4For(WithdrawQuote quote) {
    final toType = List.unmodifiable([
      {'name': 'name', 'type': 'string'},
      {'name': 'version', 'type': 'string'},
      {'name': 'chainId', 'type': 'uint256'},
      {'name': 'verifyingContract', 'type': 'address'},
    ]);
    final reqType = List.unmodifiable([
      {'name': 'to', 'type': 'address'},
      {'name': 'amount', 'type': 'uint256'},
      {'name': 'nonce', 'type': 'uint256'},
      {'name': 'deadline', 'type': 'uint256'},
    ]);
    final message = quote.message;
    return <String, dynamic>{
      'types': <String, dynamic>{
        'EIP712Domain': toType,
        quote.primaryType: reqType,
      },
      'primaryType': quote.primaryType,
      'domain': <String, dynamic>{
        'name': quote.domain.name,
        'version': quote.domain.version,
        'chainId': '0x${quote.domain.chainId.toRadixString(16)}',
        'verifyingContract': quote.domain.verifyingContract,
      },
      'message': <String, dynamic>{
        'to': message.to,
        'amount': '0x${BigInt.parse(message.amount).toRadixString(16)}',
        'nonce': '0x${message.nonce.toRadixString(16)}',
        'deadline': '0x${message.deadline.toRadixString(16)}',
      },
    };
  }

  /// Signs the quote with `from` and returns a client-shaped [WithdrawSignature]
  /// carrying the exact deadline/nonce/amount the wallet authorized.
  Future<WithdrawSignature> signWithdrawal(WithdrawQuote quote, String from) async {
    final sig = await signTypedDataV4(from, typedDataV4For(quote));
    final m = quote.message;
    return WithdrawSignature(
      signature: sig,
      deadline: m.deadline,
      nonce: m.nonce,
      amountMinorBase: BigInt.parse(m.amount).toInt(),
    );
  }

  /// Whether [owner] is among the currently connected accounts (case-insensitive).
  Future<bool> isConnectedOwner(String owner) async {
    if (owner.isEmpty) return false;
    final connected = await accounts();
    final lowered = owner.toLowerCase();
    return connected.any((a) => a.toLowerCase() == lowered);
  }

  /// Builds the exact eth_signTypedData_v4 payload for a `SetRecovery` quote.
  /// The types array mirrors the contract's EIP-712 domain + the
  /// `SetRecovery(address recoveryAddress,uint256 nonce,uint256 deadline)`
  /// struct, with every uint256 as a canonical hex value.
  Map<String, dynamic> typedDataV4ForRecovery(RecoveryQuote quote) {
    const toType = [
      {'name': 'name', 'type': 'string'},
      {'name': 'version', 'type': 'string'},
      {'name': 'chainId', 'type': 'uint256'},
      {'name': 'verifyingContract', 'type': 'address'},
    ];
    const reqType = [
      {'name': 'recoveryAddress', 'type': 'address'},
      {'name': 'nonce', 'type': 'uint256'},
      {'name': 'deadline', 'type': 'uint256'},
    ];
    final message = quote.message;
    return <String, dynamic>{
      'types': <String, dynamic>{
        'EIP712Domain': toType,
        quote.primaryType: reqType,
      },
      'primaryType': quote.primaryType,
      'domain': <String, dynamic>{
        'name': quote.domain.name,
        'version': quote.domain.version,
        'chainId': '0x${quote.domain.chainId.toRadixString(16)}',
        'verifyingContract': quote.domain.verifyingContract,
      },
      'message': <String, dynamic>{
        'recoveryAddress': message.recoveryAddress,
        'nonce': '0x${message.nonce.toRadixString(16)}',
        'deadline': '0x${message.deadline.toRadixString(16)}',
      },
    };
  }

  /// Signs a recovery quote with `from` and returns a client-shaped
  /// [RecoverySignature] carrying the exact deadline/nonce the wallet
  /// authorized for designating the recovery address.
  Future<RecoverySignature> signRecovery(RecoveryQuote quote, String from) async {
    final sig = await signTypedDataV4(from, typedDataV4ForRecovery(quote));
    final m = quote.message;
    return RecoverySignature(
      signature: sig,
      deadline: m.deadline,
      nonce: m.nonce,
    );
  }
}