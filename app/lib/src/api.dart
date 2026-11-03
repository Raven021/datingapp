import "package:dio/dio.dart";
import "package:ashna/src/models.dart";

class ApiException implements Exception {
  ApiException(this.code, this.message);

  final String code;
  final String message;
}

class TokenHolder {
  String? access;
  String? refresh;
}

class Api {
  Api({required this.baseUrl, required this.tokens, required this.onRefresh}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
        headers: {"Accept": "application/json"},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.extra["auth"] != false && tokens.access != null) {
            options.headers["Authorization"] = "Bearer ${tokens.access}";
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final skipped = error.requestOptions.extra["auth"] == false;
          final retried = error.requestOptions.extra["retried"] == true;
          if (status == 401 && !skipped && !retried && tokens.refresh != null) {
            try {
              await onRefresh();
              final request = error.requestOptions;
              request.extra["retried"] = true;
              request.headers["Authorization"] = "Bearer ${tokens.access}";
              final response = await dio.fetch(request);
              handler.resolve(response);
              return;
            } catch (_) {}
          }
          handler.next(error);
        },
      ),
    );
  }

  final String baseUrl;
  final TokenHolder tokens;
  final Future<void> Function() onRefresh;
  late final Dio dio;

  String mediaUrl(String photoId) => "$baseUrl/v1/media/$photoId";

  Future<dynamic> send(String method, String path, {Object? body, bool auth = true}) async {
    try {
      final response = await dio.request(path, data: body, options: Options(method: method, extra: {"auth": auth}));
      return response.data;
    } on DioException catch (error) {
      throw wrap(error);
    }
  }

  static ApiException wrap(DioException error) {
    final data = error.response?.data;
    if (data is Map && data["message"] is String) {
      return ApiException("${data["code"] ?? "ERROR"}", data["message"] as String);
    }
    return ApiException("ERROR", "ارتباط با سرور برقرار نشد.");
  }

  Future<String?> requestOtp(String phone) async {
    final data = asMap(await send("POST", "/v1/auth/otp", body: {"phone": phone}, auth: false));
    return data["devCode"] as String?;
  }

  Future<({String access, String refresh, bool onboardingComplete})> verify(String phone, String code) async {
    final data = asMap(await send("POST", "/v1/auth/verify", body: {"phone": phone, "code": code}, auth: false));
    return (
      access: data["accessToken"] as String,
      refresh: data["refreshToken"] as String,
      onboardingComplete: data["onboardingComplete"] == true,
    );
  }

  Future<Me> fetchMe() async => Me.fromJson(asMap(await send("GET", "/v1/me")));

  Future<List<CityOption>> cities() async {
    final data = await send("GET", "/v1/cities") as List;
    return data.map((item) => CityOption.fromJson(asMap(item))).toList();
  }

  Future<Me> saveProfile(Map<String, dynamic> body) async {
    return Me.fromJson(asMap(await send("PUT", "/v1/me", body: body)));
  }

  Future<PhotoRef> uploadPhoto(String path) async {
    final form = FormData.fromMap({"file": await MultipartFile.fromFile(path, filename: "photo.jpg")});
    return PhotoRef.fromJson(asMap(await send("POST", "/v1/me/photos", body: form)));
  }

  Future<void> deletePhoto(String id) async {
    await send("DELETE", "/v1/me/photos/$id");
  }

  Future<void> reorderPhotos(List<String> ids) async {
    await send("PUT", "/v1/me/photos/order", body: {"ids": ids});
  }

  Future<void> setLocation(double latitude, double longitude) async {
    await send("POST", "/v1/me/location", body: {"latitude": latitude, "longitude": longitude});
  }

  Future<void> clearLocation() async {
    await send("DELETE", "/v1/me/location");
  }

  Future<List<DeckCard>> deck() async {
    final data = asMap(await send("GET", "/v1/deck"));
    return (data["cards"] as List).map((item) => DeckCard.fromJson(asMap(item))).toList();
  }

  Future<MatchHit?> swipe(String userId, String direction) async {
    final data = asMap(await send("POST", "/v1/swipes", body: {"userId": userId, "direction": direction}));
    final match = data["match"];
    if (match == null) return null;
    return MatchHit.fromJson(asMap(match));
  }

  Future<List<MatchPreview>> matches() async {
    final data = asMap(await send("GET", "/v1/matches"));
    return (data["matches"] as List).map((item) => MatchPreview.fromJson(asMap(item))).toList();
  }

  Future<ThreadData> messages(String matchId) async {
    return ThreadData.fromJson(asMap(await send("GET", "/v1/matches/$matchId/messages")));
  }

  Future<ChatMessage> sendMessage(String matchId, String body) async {
    return ChatMessage.fromJson(asMap(await send("POST", "/v1/matches/$matchId/messages", body: {"body": body})));
  }

  Future<void> unmatch(String matchId) async {
    await send("POST", "/v1/matches/$matchId/unmatch");
  }

  Future<void> blockUser(String userId) async {
    await send("POST", "/v1/blocks", body: {"userId": userId});
  }

  Future<void> blockPhone(String phone) async {
    await send("POST", "/v1/blocks", body: {"phone": phone});
  }

  Future<void> report(String userId, String reason) async {
    await send("POST", "/v1/reports", body: {"userId": userId, "reason": reason});
  }

  Future<void> deleteAccount() async {
    await send("DELETE", "/v1/me");
  }
}
