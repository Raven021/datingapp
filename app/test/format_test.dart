import "package:ashna/src/format.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("distance label hides exact location", () {
    expect(placeLabel(distanceKm: null, cityName: "اصفهان"), "اصفهان");
    expect(placeLabel(distanceKm: 0, cityName: "تهران"), "کمتر از ۱ کیلومتر");
    expect(placeLabel(distanceKm: 4, cityName: "تهران"), "۴ کیلومتر");
  });

  test("opener counts ZWNJ inside a word", () {
    expect(wordCount("سلام"), 1);
    expect(isValidOpener("سلام"), isFalse);
    expect(wordCount("می‌روم بیرون"), 2);
    expect(isValidOpener("سلام خوبی"), isTrue);
  });
}
