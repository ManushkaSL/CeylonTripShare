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
