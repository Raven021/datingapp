int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.parse(value.toString());
}

Map<String, dynamic> asMap(dynamic value) => (value as Map).cast<String, dynamic>();

class PhotoRef {
  const PhotoRef({required this.id});

  final String id;

  factory PhotoRef.fromJson(Map<String, dynamic> json) => PhotoRef(id: json["id"] as String);
}

class Profile {
  const Profile({
    required this.displayName,
    required this.birthDate,
    required this.age,
    required this.gender,
    required this.bio,
    required this.job,
    required this.education,
    required this.cityId,
    required this.cityName,
    required this.hasLocation,
    required this.showGenders,
    required this.ageMin,
    required this.ageMax,
    required this.maxDistanceKm,
    required this.photos,
  });

  final String displayName;
  final String birthDate;
  final int age;
  final String gender;
  final String bio;
  final String? job;
  final String? education;
  final String cityId;
  final String cityName;
  final bool hasLocation;
  final List<String> showGenders;
  final int ageMin;
  final int ageMax;
  final int maxDistanceKm;
  final List<PhotoRef> photos;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      displayName: json["displayName"] as String,
      birthDate: json["birthDate"] as String,
      age: asInt(json["age"]),
      gender: json["gender"] as String,
      bio: (json["bio"] as String?) ?? "",
      job: json["job"] as String?,
      education: json["education"] as String?,
      cityId: json["cityId"] as String,
      cityName: json["cityName"] as String,
      hasLocation: json["hasLocation"] == true,
      showGenders: (json["showGenders"] as List).cast<String>(),
      ageMin: asInt(json["ageMin"]),
      ageMax: asInt(json["ageMax"]),
      maxDistanceKm: asInt(json["maxDistanceKm"]),
      photos: (json["photos"] as List).map((item) => PhotoRef.fromJson(asMap(item))).toList(),
    );
  }
}

class Me {
  const Me({required this.id, required this.onboardingComplete, required this.profile});

  final String id;
  final bool onboardingComplete;
  final Profile? profile;

  factory Me.fromJson(Map<String, dynamic> json) {
    final profile = json["profile"];
    return Me(
      id: json["id"] as String,
      onboardingComplete: json["onboardingComplete"] == true,
      profile: profile == null ? null : Profile.fromJson(asMap(profile)),
    );
  }
}

class CityOption {
  const CityOption({required this.id, required this.nameFa});

  final String id;
  final String nameFa;

  factory CityOption.fromJson(Map<String, dynamic> json) {
    return CityOption(id: json["id"] as String, nameFa: json["nameFa"] as String);
  }
}

class DeckCard {
  const DeckCard({
    required this.id,
    required this.displayName,
    required this.age,
    required this.gender,
    required this.bio,
    required this.job,
    required this.education,
    required this.cityName,
    required this.distanceKm,
    required this.photos,
  });

  final String id;
  final String displayName;
  final int age;
  final String gender;
  final String bio;
  final String? job;
  final String? education;
  final String cityName;
  final int? distanceKm;
  final List<PhotoRef> photos;

  factory DeckCard.fromJson(Map<String, dynamic> json) {
    return DeckCard(
      id: json["id"] as String,
      displayName: json["displayName"] as String,
      age: asInt(json["age"]),
      gender: json["gender"] as String,
      bio: (json["bio"] as String?) ?? "",
      job: json["job"] as String?,
      education: json["education"] as String?,
      cityName: json["cityName"] as String,
      distanceKm: json["distanceKm"] == null ? null : asInt(json["distanceKm"]),
      photos: (json["photos"] as List).map((item) => PhotoRef.fromJson(asMap(item))).toList(),
    );
  }
}

class MatchHit {
  const MatchHit({required this.id, required this.status});

  final String id;
  final String status;

  factory MatchHit.fromJson(Map<String, dynamic> json) {
    return MatchHit(id: json["id"] as String, status: json["status"] as String);
  }
}

class OtherPreview {
  const OtherPreview({
    required this.id,
    required this.displayName,
    required this.age,
    required this.cityName,
    required this.photoId,
  });

  final String id;
  final String displayName;
  final int age;
  final String cityName;
  final String? photoId;

  factory OtherPreview.fromJson(Map<String, dynamic> json) {
    return OtherPreview(
      id: json["id"] as String,
      displayName: json["displayName"] as String,
      age: asInt(json["age"]),
      cityName: json["cityName"] as String,
      photoId: json["photoId"] as String?,
    );
  }
}

class LastMessage {
  const LastMessage({required this.body, required this.mine});

  final String body;
  final bool mine;

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(body: json["body"] as String, mine: json["mine"] == true);
  }
}

class MatchPreview {
  const MatchPreview({
    required this.id,
    required this.status,
    required this.waitingForReply,
    required this.needsReply,
    required this.other,
    required this.lastMessage,
  });

  final String id;
  final String status;
  final bool waitingForReply;
  final bool needsReply;
  final OtherPreview? other;
  final LastMessage? lastMessage;

  factory MatchPreview.fromJson(Map<String, dynamic> json) {
    return MatchPreview(
      id: json["id"] as String,
      status: json["status"] as String,
      waitingForReply: json["waitingForReply"] == true,
      needsReply: json["needsReply"] == true,
      other: json["other"] == null ? null : OtherPreview.fromJson(asMap(json["other"])),
      lastMessage: json["lastMessage"] == null ? null : LastMessage.fromJson(asMap(json["lastMessage"])),
    );
  }
}

class ChatMessage {
  const ChatMessage({required this.id, required this.body, required this.mine, required this.createdAt});

  final String id;
  final String body;
  final bool mine;
  final String createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json["id"] as String,
      body: json["body"] as String,
      mine: json["mine"] == true,
      createdAt: json["createdAt"] as String,
    );
  }
}

class ThreadData {
  const ThreadData({required this.id, required this.status, required this.otherId, required this.messages});

  final String id;
  final String status;
  final String otherId;
  final List<ChatMessage> messages;

  factory ThreadData.fromJson(Map<String, dynamic> json) {
    return ThreadData(
      id: json["id"] as String,
      status: json["status"] as String,
      otherId: json["otherId"] as String,
      messages: (json["messages"] as List).map((item) => ChatMessage.fromJson(asMap(item))).toList(),
    );
  }
}
