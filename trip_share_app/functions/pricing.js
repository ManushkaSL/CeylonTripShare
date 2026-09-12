"use strict";

const roundMoney = (value) => Math.round((value + Number.EPSILON) * 100) / 100;

const nonNegativeNumber = (value, fallback = 0) => {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
};

const percentage = (value, fallback = 0) => {
  return Math.min(100, nonNegativeNumber(value, fallback));
};

function calculatePricing({
  adults,
  kids6to12,
  kidsUnder6,
  pricingMode = "per_person",
  adultPrice,
  fixedTourPrice = 0,
  passengersAfterBooking = 0,
  childPrice,
  infantPrice,
  childRate = 0.5,
  privateTourSurcharge = 0,
  serviceFeePercent = 0,
  isPrivate = false,
}) {
  const bookingPassengers = adults + kids6to12 + kidsUnder6;
  const safeAdultPrice = nonNegativeNumber(adultPrice);
  const safeChildRate = Math.min(1, nonNegativeNumber(childRate, 0.5));
  const safeChildPrice = childPrice == null
    ? safeAdultPrice * safeChildRate
    : nonNegativeNumber(childPrice);
  const safeInfantPrice = nonNegativeNumber(infantPrice);
  const safePrivateSurcharge = isPrivate
    ? nonNegativeNumber(privateTourSurcharge)
    : 0;
  const safeServiceFeePercent = percentage(serviceFeePercent);

  if (pricingMode === "per_seat") {
    const adultTotal = roundMoney(adults * safeAdultPrice);
    const childTotal = roundMoney(kids6to12 * safeAdultPrice);
    const infantTotal = roundMoney(kidsUnder6 * safeAdultPrice);
    const subtotal = roundMoney(adultTotal + childTotal + infantTotal);
    const serviceFee = roundMoney(subtotal * safeServiceFeePercent / 100);
    const total = roundMoney(subtotal + serviceFee);
    return {
      pricingMode: "per_seat",
      passengersAfterBooking: bookingPassengers,
      fullTourPrice: 0,
      fullTourSubtotal: 0,
      fullTourTotal: 0,
      pricePerPassenger: roundMoney(safeAdultPrice),
      unitPrices: {
        adult: roundMoney(safeAdultPrice),
        child: roundMoney(safeAdultPrice),
        infant: roundMoney(safeAdultPrice),
      },
      adultTotal,
      childTotal,
      infantTotal,
      privateTourSurcharge: 0,
      serviceFeePercent: safeServiceFeePercent,
      serviceFee,
      subtotal,
      total,
    };
  }

  if (pricingMode === "fixed_tour") {
    const safeFixedTourPrice = nonNegativeNumber(fixedTourPrice);
    const sharingPassengers = Math.max(
      1,
      Math.trunc(nonNegativeNumber(passengersAfterBooking, bookingPassengers)),
    );
    // The administrator's fixed full-tour price is the exact final amount to
    // split. Per-person child rates, private surcharges, and service fees do
    // not alter this pool.
    const fullTourSubtotal = roundMoney(safeFixedTourPrice);
    const fullTourTotal = fullTourSubtotal;
    const subtotalPerPassenger = fullTourSubtotal / sharingPassengers;
    const pricePerPassenger = roundMoney(fullTourTotal / sharingPassengers);
    const adultTotal = roundMoney(adults * subtotalPerPassenger);
    const childTotal = roundMoney(kids6to12 * subtotalPerPassenger);
    const infantTotal = roundMoney(kidsUnder6 * subtotalPerPassenger);
    const subtotal = roundMoney(adultTotal + childTotal + infantTotal);
    const serviceFee = 0;
    const total = subtotal;

    return {
      pricingMode: "fixed_tour",
      passengersAfterBooking: sharingPassengers,
      fullTourPrice: roundMoney(safeFixedTourPrice),
      fullTourSubtotal,
      fullTourTotal,
      pricePerPassenger,
      unitPrices: {
        adult: pricePerPassenger,
        child: pricePerPassenger,
        infant: pricePerPassenger,
      },
      adultTotal,
      childTotal,
      infantTotal,
      privateTourSurcharge: 0,
      serviceFeePercent: 0,
      serviceFee,
      subtotal,
      total,
    };
  }

  const adultTotal = roundMoney(adults * safeAdultPrice);
  const childTotal = roundMoney(kids6to12 * safeChildPrice);
  const infantTotal = roundMoney(kidsUnder6 * safeInfantPrice);
  const subtotal = roundMoney(
    adultTotal + childTotal + infantTotal + safePrivateSurcharge,
  );
  const serviceFee = roundMoney(subtotal * safeServiceFeePercent / 100);
  const total = roundMoney(subtotal + serviceFee);

  return {
    pricingMode: "per_person",
    passengersAfterBooking: bookingPassengers,
    fullTourPrice: 0,
    fullTourSubtotal: 0,
    fullTourTotal: 0,
    pricePerPassenger: 0,
    unitPrices: {
      adult: roundMoney(safeAdultPrice),
      child: roundMoney(safeChildPrice),
      infant: roundMoney(safeInfantPrice),
    },
    adultTotal,
    childTotal,
    infantTotal,
    privateTourSurcharge: roundMoney(safePrivateSurcharge),
    serviceFeePercent: safeServiceFeePercent,
    serviceFee,
    subtotal,
    total,
  };
}

module.exports = {calculatePricing, nonNegativeNumber, roundMoney};
