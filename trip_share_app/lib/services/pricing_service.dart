import 'package:cloud_functions/cloud_functions.dart';

class PricingQuote {
  final int pricingVersion;
  final String currency;
  final bool isPrivate;
  final int adults;
  final int kids6to12;
  final int kidsUnder6;
  final int totalPersons;
  final double adultUnitPrice;
  final double childUnitPrice;
  final double infantUnitPrice;
  final double adultTotal;
  final double childTotal;
  final double infantTotal;
  final double privateTourSurcharge;
  final double serviceFeePercent;
  final double serviceFee;
  final double subtotal;
  final double total;
  final DateTime expiresAt;

  const PricingQuote({
    required this.pricingVersion,
    required this.currency,
    required this.isPrivate,
    required this.adults,
    required this.kids6to12,
    required this.kidsUnder6,
    required this.totalPersons,
    required this.adultUnitPrice,
    required this.childUnitPrice,
    required this.infantUnitPrice,
    required this.adultTotal,
    required this.childTotal,
    required this.infantTotal,
    required this.privateTourSurcharge,
    required this.serviceFeePercent,
    required this.serviceFee,
    required this.subtotal,
    required this.total,
    required this.expiresAt,
  });

  factory PricingQuote.fromMap(Map<String, dynamic> data) {
    final counts = _map(data['counts']);
    final unitPrices = _map(data['unitPrices']);
    return PricingQuote(
      pricingVersion: _integer(data['pricingVersion'], fallback: 1),
      currency: (data['currency'] ?? 'LKR').toString(),
      isPrivate: data['isPrivate'] == true,
      adults: _integer(counts['adults']),
      kids6to12: _integer(counts['kids6to12']),
      kidsUnder6: _integer(counts['kidsUnder6']),
      totalPersons: _integer(counts['totalPersons']),
      adultUnitPrice: _number(unitPrices['adult']),
      childUnitPrice: _number(unitPrices['child']),
      infantUnitPrice: _number(unitPrices['infant']),
      adultTotal: _number(data['adultTotal']),
      childTotal: _number(data['childTotal']),
      infantTotal: _number(data['infantTotal']),
      privateTourSurcharge: _number(data['privateTourSurcharge']),
      serviceFeePercent: _number(data['serviceFeePercent']),
      serviceFee: _number(data['serviceFee']),
      subtotal: _number(data['subtotal']),
      total: _number(data['total']),
      expiresAt:
          DateTime.tryParse(data['quoteExpiresAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toBookingPricingMap() => {
    'pricingVersion': pricingVersion,
    'currency': currency,
    'adultUnitPrice': adultUnitPrice,
    'childUnitPrice': childUnitPrice,
    'infantUnitPrice': infantUnitPrice,
    'adultTotal': adultTotal,
    'childTotal': childTotal,
    'infantTotal': infantTotal,
    'privateTourSurcharge': privateTourSurcharge,
    'serviceFeePercent': serviceFeePercent,
    'serviceFee': serviceFee,
    'subtotal': subtotal,
    'total': total,
    'quoteExpiresAt': expiresAt.toUtc().toIso8601String(),
  };

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _integer(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class PricingService {
  final FirebaseFunctions _functions;

  PricingService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<PricingQuote> calculateTourPrice({
    required String tourId,
    required int adults,
    required int kids6to12,
    required int kidsUnder6,
    required bool isPrivate,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('calculateTourPrice')
          .call(<String, dynamic>{
            'tourId': tourId,
            'adults': adults,
            'kids6to12': kids6to12,
            'kidsUnder6': kidsUnder6,
            'isPrivate': isPrivate,
          });
      final rawData = result.data;
      if (rawData is! Map) {
        throw const PricingException('The pricing service returned no quote.');
      }
      return PricingQuote.fromMap(
        rawData.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on FirebaseFunctionsException catch (error) {
      throw PricingException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'The pricing service is unavailable.',
      );
    }
  }
}

class PricingException implements Exception {
  final String message;

  const PricingException(this.message);

  @override
  String toString() => message;
}
