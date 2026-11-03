import "package:ashna/src/format.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("phone field stays right to left", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale("fa"),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Text("آشنا")),
        ),
      ),
    );
    expect(find.text("آشنا"), findsOneWidget);
    expect(Directionality.of(tester.element(find.text("آشنا"))), TextDirection.rtl);
    expect(placeLabel(distanceKm: 0, cityName: "تهران"), "کمتر از ۱ کیلومتر");
  });
}
