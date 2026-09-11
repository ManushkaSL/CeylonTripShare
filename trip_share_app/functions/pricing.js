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
  adultPrice,
  childPrice,
  infantPrice,
  childRate = 0.5,
  privateTourSurcharge = 0,
  serviceFeePercent = 0,
  isPrivate = false,
}) {
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

  const adultTotal = roundMoney(adults * safeAdultPrice);
  const childTotal = roundMoney(kids6to12 * safeChildPrice);
  const infantTotal = roundMoney(kidsUnder6 * safeInfantPrice);
  const subtotal = roundMoney(
    adultTotal + childTotal + infantTotal + safePrivateSurcharge,
  );
  const serviceFee = roundMoney(subtotal * safeServiceFeePercent / 100);
  const total = roundMoney(subtotal + serviceFee);

  return {
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
