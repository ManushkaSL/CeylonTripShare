import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_share_app/widgets/custom_bottom_nav.dart';

void main() {
  testWidgets('fits a phone viewport and sends the correct destination index', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? destination;
    var centerTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CustomBottomNav(
            currentIndex: 0,
            onTap: (index) => destination = index,
            onCenterTap: () => centerTapped = true,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Bookings'));
    expect(destination, 3);

    await tester.tap(find.byIcon(Icons.add_road_rounded));
    expect(centerTapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
