/// Non-web stub for the EIP-1193 wallet bridge.
///
/// Used by the conditional export in `ethereum_provider_bridge.dart` on the
/// Dart VM (widget tests, native targets) where `dart:js_interop` is not
/// available. The app never calls these: it checks `bridgeAvailable()` first
/// and degrades to the server-relayed path.
bool bridgeAvailable() => false;

Future<List<String>> bridgeRequestAccounts() =>
    throw UnsupportedError('EthereumProvider requires a web target.');

Future<List<String>> bridgeAccounts() =>
    throw UnsupportedError('EthereumProvider requires a web target.');

Future<String> bridgeSignTypedDataV4(String from, String typedDataJson) =>
    throw UnsupportedError('EthereumProvider requires a web target.');