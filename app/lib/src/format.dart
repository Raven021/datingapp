const genderOrder = ["woman", "man", "nonbinary"];

const genderLabels = {
  "woman": "زن",
  "man": "مرد",
  "nonbinary": "غیردودویی",
};

String faDigits(Object value) {
  const digits = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"];
  return value.toString().split("").map((char) {
    final index = "0123456789".indexOf(char);
    return index >= 0 ? digits[index] : char;
  }).join();
}

String placeLabel({required int? distanceKm, required String cityName}) {
  if (distanceKm == null) return cityName;
  if (distanceKm < 1) return "کمتر از ۱ کیلومتر";
  return "${faDigits(distanceKm)} کیلومتر";
}

int wordCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r"\s+")).where((part) => part.isNotEmpty).length;
}

bool isValidOpener(String text) => wordCount(text) >= 2 && text.trim().length <= 1000;
