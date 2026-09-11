import 'package:flutter_test/flutter_test.dart';
import 'package:trip_share_app/models/booking.dart';
import 'package:trip_share_app/models/tour.dart';

Tour _tour() => Tour(
  id: 'instance-1',
  name: 'Hill Country',
  imageUrl: '',
  startDate: DateTime(2026, 9, 20),
  totalSeats: 10,
  remainingSeats: 8,
  price: 100,
  sourceIdleTourId: 'template-1',
);

void main() {
  test('tours are public by default and can be copied as private', () {
    final publicTour = _tour();
    final privateTour = publicTour.copyWith(isPrivate: true);

    expect(publicTour.isPrivate, isFalse);
    expect(privateTour.isPrivate, isTrue);
    expect(privateTour.sourceIdleTourId, publicTour.sourceIdleTourId);
  });

  test('booking map stores public/private visibility consistently', () {
    final booking = Booking(
      id: 'booking-1',
      userId: 'user-1',
      tour: _tour().copyWith(isPrivate: true),
      bookedAt: DateTime(2026, 9, 11),
      adults: 1,
      kids6to12: 0,
      kidsUnder6: 0,
      pickupLocation: 'Colombo',
      totalPrice: 100,
      totalPersons: 1,
      phoneNumber: '+94123456789',
      isPrivate: true,
    );

    expect(booking.toMap()['visibility'], 'private');
    expect(booking.toMap()['isPrivate'], isTrue);
  });

  test('legacy bookings without visibility remain public', () {
    final booking = Booking.fromMap({
      'id': 'booking-2',
      'userId': 'user-1',
      'bookedAt': DateTime(2026, 9, 11).toIso8601String(),
    }, _tour());

    expect(booking.isPrivate, isFalse);
  });
}
