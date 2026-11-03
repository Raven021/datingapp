import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:ashna/src/api.dart";
import "package:ashna/src/models.dart";

enum SessionStatus { loading, signedOut, onboarding, ready }

abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) {
    if (value == null) return _storage.delete(key: key);
    return _storage.write(key: key, value: value);
  }
}

class MemoryTokenStore implements TokenStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

String resolveApiBase() {
  const defined = String.fromEnvironment("API_BASE");
  if (defined.isNotEmpty) return defined;
  if (!kIsWeb && Platform.isAndroid) return "http://10.0.2.2:3000";
  return "http://127.0.0.1:3000";
}

class Session extends ChangeNotifier {
  Session({TokenStore? store, String? baseUrl})
    : store = store ?? const SecureTokenStore(),
      baseUrl = baseUrl ?? resolveApiBase(),
      tokens = TokenHolder() {
    api = Api(baseUrl: this.baseUrl, tokens: tokens, onRefresh: refresh);
  }

  final TokenStore store;
  final String baseUrl;
  final TokenHolder tokens;
  late final Api api;

  SessionStatus status = SessionStatus.loading;
  Me? me;
  String? phone;
  String? devCode;

  Future<void> boot() async {
    try {
      tokens.access = await store.read("access");
      tokens.refresh = await store.read("refresh");
      if (tokens.access == null) {
        status = SessionStatus.signedOut;
        notifyListeners();
        return;
      }
      try {
        await reload();
      } catch (_) {
        if (tokens.refresh == null) rethrow;
        await refresh();
        await reload();
      }
    } catch (_) {
      await clearLocal();
    }
  }

  Future<void> reload() async {
    me = await api.fetchMe();
    status = me!.onboardingComplete ? SessionStatus.ready : SessionStatus.onboarding;
    notifyListeners();
  }

  Future<void> requestOtp(String rawPhone) async {
    phone = rawPhone.trim();
    devCode = await api.requestOtp(phone!);
    notifyListeners();
  }

  Future<void> verify(String code) async {
    final result = await api.verify(phone ?? "", code.trim());
    tokens.access = result.access;
    tokens.refresh = result.refresh;
    await _persist();
    await reload();
  }

  Future<void> refresh() async {
    final token = tokens.refresh;
    if (token == null) {
      throw ApiException("UNAUTHORIZED", "نشستت تمام شده. دوباره وارد شو.");
    }
    try {
      final response = await Dio(BaseOptions(baseUrl: baseUrl)).post("/v1/auth/refresh", data: {"refreshToken": token});
      final data = asMap(response.data);
      tokens.access = data["accessToken"] as String;
      tokens.refresh = data["refreshToken"] as String;
      await _persist();
    } on DioException catch (error) {
      throw Api.wrap(error);
    }
  }

  Future<void> logout() async {
    final token = tokens.refresh;
    try {
      if (token != null) {
        await api.send("POST", "/v1/auth/logout", body: {"refreshToken": token}, auth: false);
      }
    } catch (_) {}
    await clearLocal();
  }

  Future<void> clearLocal() async {
    tokens.access = null;
    tokens.refresh = null;
    me = null;
    devCode = null;
    phone = null;
    await store.write("access", null);
    await store.write("refresh", null);
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  Future<void> _persist() async {
    await store.write("access", tokens.access);
    await store.write("refresh", tokens.refresh);
  }
}

final sessionProvider = ChangeNotifierProvider<Session>((ref) {
  final session = Session();
  session.boot();
  return session;
});
