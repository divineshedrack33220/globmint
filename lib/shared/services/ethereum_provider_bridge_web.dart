import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Web-only EIP-1193 wallet bridge backed by `window.ethereum`.
///
/// Selected by the conditional export in `ethereum_provider_bridge.dart` only
/// when `dart.library.js_interop` is available (i.e. a web target). All
/// methods throw unimplemented errors on non-web targets that somehow reach
/// this file, which the caller guards against by checking [available] first.
bool get _available {
  if (!kIsWeb) return false;
  try {
    return globalContext.getProperty('ethereum'.toJS) != null;
  } catch (_) {
    return false;
  }
}

/// True when `window.ethereum` exists (web target with an injected wallet).
bool bridgeAvailable() => _available;

JSObject get _ethereum {
  final eth = globalContext.getProperty('ethereum'.toJS);
  if (eth == null) {
    throw StateError('No wallet provider found in this browser.');
  }
  return eth as JSObject;
}

Future<JSAny?> _request(String method, List<JSAny?> params) async {
  final req =
      <String, JSAny?>{'method': method.toJS, 'params': params.jsify()}.jsify()
          as JSObject;
  final result = _ethereum.callMethodVarArgs('request'.toJS, [req]);
  return (result as JSPromise<JSAny?>).toDart;
}

/// Requests an unlocked account (opens the wallet's connect flow).
Future<List<String>> bridgeRequestAccounts() async {
  final result = await _request('eth_requestAccounts', []);
  final list = result as JSArray<JSString>;
  return list.toDart.map((a) => a.toDart).toList();
}

/// Currently connected/authorized accounts without prompting.
Future<List<String>> bridgeAccounts() async {
  final result = await _request('eth_accounts', []);
  final list = result as JSArray<JSString>;
  return list.toDart.map((a) => a.toDart).toList();
}

/// Signs an EIP-712 typed-data payload with `from`'s key via the wallet UI.
/// Returns the 65-byte `0x`-prefixed signature.
Future<String> bridgeSignTypedDataV4(
    String from, String typedDataJson) async {
  final result = await _request('eth_signTypedData_v4', [
    from.toJS,
    typedDataJson.toJS,
  ]);
  return (result as JSString).toDart;
}

/// The currently connected chain id as a `0x`-prefixed hex string
/// (`eth_chainId`). `0x0` when the wallet is locked or unreachable.
Future<String> bridgeChainId() async {
  final result = await _request('eth_chainId', []);
  return (result as JSString).toDart;
}

/// Requests the wallet to switch to [chainId] (`wallet_switchEthereumChain`,
/// EIP-3326). Throws when the wallet refuses or lacks the network.
Future<void> bridgeSwitchChain(int chainId) async {
  await _request('wallet_switchEthereumChain', [
    <String, JSAny?>{'chainId': '0x${chainId.toRadixString(16)}'.toJS}.jsify(),
  ]);
}