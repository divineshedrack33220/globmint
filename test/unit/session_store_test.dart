import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:globe_mint/shared/services/session_store.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('SecureSessionStore', () {
    test('a platform store that fails still serves the session in memory',
        () async {
      // Simulate a browser/device where WebCrypto or IndexedDB misbehaves:
      // every platform call throws. The in-memory mirror must keep the app
      // signed in for the whole session regardless.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        throw PlatformException(code: 'PlatformException(platform)');
      });

      final store = SecureSessionStore();
      await store.writeToken('tok');

      expect(await store.readToken(), 'tok');
      await store.clearToken();
      expect(await store.readToken(), isNull);
    });

    test('cold reads fall back to the persisted value', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'read') {
          return 'persisted-tok';
        }
        return null;
      });

      final store = SecureSessionStore();

      expect(await store.readToken(), 'persisted-tok');
    });

    test('clearToken with a different expected token is a no-op', () async {
      final store = SecureSessionStore();
      await store.writeToken('current');

      await store.clearToken(expected: 'stale');

      expect(await store.readToken(), 'current');
    });

    test('clearToken clears when expected matches', () async {
      final store = SecureSessionStore();
      await store.writeToken('current');

      await store.clearToken(expected: 'current');

      expect(await store.readToken(), isNull);
    });

    test('email is mirrored the same way and survives a broken store',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        throw PlatformException(code: 'PlatformException(platform)');
      });

      final store = SecureSessionStore();
      await store.writeEmail('ada@dev.com');

      expect(await store.readEmail(), 'ada@dev.com');
    });
  });

  group('MemorySessionStore', () {
    test('compared clear keeps a replaced token', () async {
      final store = MemorySessionStore(token: 'current');
      await store.clearToken(expected: 'stale');
      expect(await store.readToken(), 'current');
    });

    test('unconditional clear always empties', () async {
      final store = MemorySessionStore(token: 'current');
      await store.clearToken();
      expect(await store.readToken(), isNull);
    });
  });
}