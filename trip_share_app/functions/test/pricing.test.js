"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {calculatePricing} = require("../pricing");

test("uses the current adult, half-price child, and free infant rules", () => {
  const quote = calculatePricing({
    adults: 2,
    kids6to12: 1,
    kidsUnder6: 1,
    adultPrice: 1000,
  });

  assert.equal(quote.adultTotal, 2000);
  assert.equal(quote.childTotal, 500);
  assert.equal(quote.infantTotal, 0);
  assert.equal(quote.total, 2500);
});

test("adds configured private-tour surcharge and service fee", () => {
  const quote = calculatePricing({
    adults: 1,
    kids6to12: 0,
    kidsUnder6: 0,
    adultPrice: 1000,
    isPrivate: true,
    privateTourSurcharge: 500,
    serviceFeePercent: 10,
  });

  assert.equal(quote.subtotal, 1500);
  assert.equal(quote.serviceFee, 150);
  assert.equal(quote.total, 1650);
});

test("rounds all monetary output to two decimal places", () => {
  const quote = calculatePricing({
    adults: 1,
    kids6to12: 1,
    kidsUnder6: 0,
    adultPrice: 10.01,
    serviceFeePercent: 2.5,
  });

  assert.equal(quote.childTotal, 5.01);
  assert.equal(quote.total, 15.4);
});

test("splits a fixed private-tour price equally between all passengers", () => {
  const firstPassenger = calculatePricing({
    adults: 1,
    kids6to12: 0,
    kidsUnder6: 0,
    pricingMode: "fixed_tour",
    fixedTourPrice: 30000,
    passengersAfterBooking: 1,
    isPrivate: true,
  });
  const thirdPassenger = calculatePricing({
    adults: 1,
    kids6to12: 0,
    kidsUnder6: 0,
    pricingMode: "fixed_tour",
    fixedTourPrice: 30000,
    passengersAfterBooking: 3,
    isPrivate: true,
  });
  const twoPassengers = calculatePricing({
    adults: 1,
    kids6to12: 0,
    kidsUnder6: 0,
    pricingMode: "fixed_tour",
    fixedTourPrice: 30000,
    passengersAfterBooking: 2,
    isPrivate: true,
    privateTourSurcharge: 2500,
    serviceFeePercent: 5,
  });

  assert.equal(firstPassenger.fullTourTotal, 30000);
  assert.equal(firstPassenger.pricePerPassenger, 30000);
  assert.equal(firstPassenger.total, 30000);
  assert.equal(twoPassengers.pricePerPassenger, 15000);
  assert.equal(twoPassengers.total, 15000);
  assert.equal(thirdPassenger.pricePerPassenger, 10000);
  assert.equal(thirdPassenger.total, 10000);
});

test("charges a booking for its passenger share of a fixed tour", () => {
  const quote = calculatePricing({
    adults: 2,
    kids6to12: 0,
    kidsUnder6: 0,
    pricingMode: "fixed_tour",
    fixedTourPrice: 30000,
    passengersAfterBooking: 3,
    isPrivate: true,
  });

  assert.equal(quote.pricePerPassenger, 10000);
  assert.equal(quote.total, 20000);
});

test("community ride pricing charges every occupied seat equally", () => {
  const quote = calculatePricing({
    adults: 1,
    kids6to12: 1,
    kidsUnder6: 1,
    pricingMode: "per_seat",
    adultPrice: 1500,
  });

  assert.equal(quote.adultTotal, 1500);
  assert.equal(quote.childTotal, 1500);
  assert.equal(quote.infantTotal, 1500);
  assert.equal(quote.total, 4500);
});
