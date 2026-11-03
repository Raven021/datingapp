import "package:ashna/src/jalali.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("1 Farvardin 1370 is 21 March 1991", () {
    final date = toGregorian(1370, 1, 1);
    expect(date.year, 1991);
    expect(date.month, 3);
    expect(date.day, 21);
    final back = toJalaali(1991, 3, 21);
    expect(back.year, 1370);
    expect(back.month, 1);
    expect(back.day, 1);
  });

  test("round-trips a few gregorian dates", () {
    final dates = [
      DateTime.utc(1991, 3, 21),
      DateTime.utc(2000, 1, 1),
      DateTime.utc(2025, 3, 20),
      DateTime.utc(2026, 11, 3),
    ];
    for (final date in dates) {
      final jalali = toJalaali(date.year, date.month, date.day);
      final gregorian = toGregorian(jalali.year, jalali.month, jalali.day);
      expect(DateTime.utc(gregorian.year, gregorian.month, gregorian.day), date);
    }
  });

  test("esfand length follows the leap year", () {
    expect(isLeapJalaaliYear(1399), isTrue);
    expect(isLeapJalaaliYear(1400), isFalse);
    expect(daysInJalaliMonth(1399, 12), 30);
    expect(daysInJalaliMonth(1400, 12), 29);
    expect(isValidJalali(1400, 12, 30), isFalse);
    expect(isAdultBirth(toGregorian(1370, 1, 1), DateTime.utc(2026, 11, 3)), isTrue);
    expect(isAdultBirth(toGregorian(1390, 1, 1), DateTime.utc(2026, 11, 3)), isFalse);
  });
}
