import 'package:flutter_test/flutter_test.dart';
import 'package:trip_share_app/services/pricing_service.dart';

void main() {
  test('pricing quote decodes the callable API response', () {
    final quote = PricingQuote.fromMap({
      'pricingVersion': 1,
      'currency': 'LKR',
      'isPrivate': false,
      'counts': {
        'adults': 2,
        'kids6to12': 1,
        'kidsUnder6': 1,
        'totalPersons': 4,
      },
      'unitPrices': {'adult': 1000, 'child': 500, 'infant': 0},
      'adultTotal': 2000,
      'childTotal': 500,
      'infantTotal': 0,
      'privateTourSurcharge': 0,
      'serviceFeePercent': 0,
      'serviceFee': 0,
      'subtotal': 2500,
      'total': 2500,
      'quoteExpiresAt': '2026-09-11T10:00:00.000Z',
    });

    expect(quote.currency, 'LKR');
    expect(quote.totalPersons, 4);
    expect(quote.childUnitPrice, 500);
    expect(quote.total, 2500);
    expect(quote.expiresAt.isUtc, isTrue);
  });

  test('booking pricing audit map includes server totals', () {
    final quote = PricingQuote.fromMap({
      'currency': 'LKR',
      'counts': {
        'adults': 1,
        'kids6to12': 0,
        'kidsUnder6': 0,
        'totalPersons': 1,
      },
      'unitPrices': {'adult': 1200, 'child': 600, 'infant': 0},
      'adultTotal': 1200,
      'childTotal': 0,
      'infantTotal': 0,
      'privateTourSurcharge': 0,
      'serviceFeePercent': 0,
      'serviceFee': 0,
      'subtotal': 1200,
      'total': 1200,
      'quoteExpiresAt': '2026-09-11T10:00:00.000Z',
    });

    expect(quote.toBookingPricingMap()['total'], 1200);
    expect(quote.toBookingPricingMap()['currency'], 'LKR');
  });

  test('fixed-tour quote exposes full and per-passenger prices', () {
    final quote = PricingQuote.fromMap({
      'pricingVersion': 2,
      'pricingMode': 'fixed_tour',
      'currency': 'LKR',
      'isPrivate': true,
      'counts': {
        'adults': 1,
        'kids6to12': 0,
        'kidsUnder6': 0,
        'totalPersons': 1,
      },
      'passengersAfterBooking': 3,
      'fullTourPrice': 30000,
      'fullTourTotal': 30000,
      'pricePerPassenger': 10000,
      'unitPrices': {'adult': 10000, 'child': 10000, 'infant': 10000},
      'adultTotal': 10000,
      'childTotal': 0,
      'infantTotal': 0,
      'privateTourSurcharge': 0,
      'serviceFeePercent': 0,
      'serviceFee': 0,
      'subtotal': 10000,
      'total': 10000,
    });

    expect(quote.pricingMode, 'fixed_tour');
    expect(quote.fullTourPrice, 30000);
    expect(quote.passengersAfterBooking, 3);
    expect(quote.pricePerPassenger, 10000);
    expect(quote.toBookingPricingMap()['fullTourTotal'], 30000);
  });

  test('community ride quote preserves equal per-seat pricing', () {
    final quote = PricingQuote.fromMap({
      'pricingVersion': 2,
      'pricingMode': 'per_seat',
      'currency': 'LKR',
      'isPrivate': false,
      'counts': {
        'adults': 1,
        'kids6to12': 1,
        'kidsUnder6': 1,
        'totalPersons': 3,
      },
      'passengersAfterBooking': 3,
      'pricePerPassenger': 1500,
      'unitPrices': {'adult': 1500, 'child': 1500, 'infant': 1500},
      'adultTotal': 1500,
      'childTotal': 1500,
      'infantTotal': 1500,
      'privateTourSurcharge': 0,
      'serviceFeePercent': 0,
      'serviceFee': 0,
      'subtotal': 4500,
      'total': 4500,
    });

    expect(quote.pricingMode, 'per_seat');
    expect(quote.childUnitPrice, 1500);
    expect(quote.infantUnitPrice, 1500);
    expect(quote.total, 4500);
  });
}
