import 'package:flutter_test/flutter_test.dart';
import 'package:trip_share_app/models/booking.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/app_stats_service.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';

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

  test('an active occurrence with all seats available has no bookings', () {
    final orphanedInstance = _tour().copyWith(
      remainingSeats: 10,
      bookedSeats: 0,
      bookedUserIds: const [],
      firstBookedUserId: '',
    );

    expect(orphanedInstance.hasBookings, isFalse);
  });

  test('completed and cancelled tours no longer expose a chat', () {
    JoinedTour joinedTour(String status) => JoinedTour(
      tour: _tour(),
      joinedAt: DateTime(2026, 9, 11),
      persons: 1,
      bookingStatus: status,
    );

    expect(joinedTour('active').isChatAvailable, isTrue);
    expect(joinedTour('completed').isChatAvailable, isFalse);
    expect(joinedTour('cancelled').isChatAvailable, isFalse);
  });

  test('completed-tour marketing count starts at 127', () {
    expect(AppStatsService.completedTourCountFrom(null), 127);
    expect(
      AppStatsService.completedTourCountFrom({'completedTourCount': 128}),
      128,
    );
  });

  test('fixed tour exposes full and current passenger prices', () {
    final tour = _tour().copyWith(
      pricingMode: Tour.fixedTourPricing,
      fixedTourPrice: 30000,
      bookedSeats: 3,
      isPrivate: true,
    );

    expect(tour.isFixedTourPricing, isTrue);
    expect(tour.fullTourPrice, 30000);
    expect(tour.currentPassengerPrice, 10000);
  });
}
