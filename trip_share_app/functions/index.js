"use strict";

const {getApps, initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");
const {setGlobalOptions} = require("firebase-functions/v2");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {calculatePricing, nonNegativeNumber} = require("./pricing");

setGlobalOptions({region: "asia-south1", maxInstances: 10});

if (getApps().length === 0) initializeApp();

const db = getFirestore();

const requiredPassengerCount = (data, key, {minimum = 0} = {}) => {
  const value = data[key];
  if (!Number.isInteger(value) || value < minimum || value > 100) {
    throw new HttpsError(
      "invalid-argument",
      `${key} must be a whole number between ${minimum} and 100.`,
    );
  }
  return value;
};

const firstConfiguredNumber = (sources, keys, fallback = 0) => {
  for (const source of sources) {
    if (!source) continue;
    for (const key of keys) {
      if (source[key] != null && source[key] !== "") {
        return nonNegativeNumber(source[key], fallback);
      }
    }
  }
  return fallback;
};

exports.calculateTourPrice = onCall(async (request) => {
  const data = request.data;
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "Pricing details are required.");
  }

  const tourId = typeof data.tourId === "string" ? data.tourId.trim() : "";
  if (!tourId || tourId.length > 256 || tourId.includes("/")) {
    throw new HttpsError("invalid-argument", "A valid tourId is required.");
  }

  const adults = requiredPassengerCount(data, "adults", {minimum: 1});
  const kids6to12 = requiredPassengerCount(data, "kids6to12");
  const kidsUnder6 = requiredPassengerCount(data, "kidsUnder6");
  const totalPersons = adults + kids6to12 + kidsUnder6;
  if (totalPersons > 100) {
    throw new HttpsError(
      "invalid-argument",
      "A quote cannot contain more than 100 travelers.",
    );
  }

  const [instanceSnapshot, directTourSnapshot, pricingConfigSnapshot] =
    await Promise.all([
      db.collection("tour_instances").doc(tourId).get(),
      db.collection("tours").doc(tourId).get(),
      db.collection("app_config").doc("pricing").get(),
    ]);

  const instance = instanceSnapshot.data();
  let template = directTourSnapshot.data();
  let sourceTourId = tourId;

  if (instance) {
    const configuredSourceId = String(
      instance.sourceIdleTourId || instance.templateTourId || "",
    ).trim();
    if (configuredSourceId && !configuredSourceId.includes("/")) {
      sourceTourId = configuredSourceId;
      const templateSnapshot = await db
        .collection("tours")
        .doc(configuredSourceId)
        .get();
      template = templateSnapshot.data() || template;
    }
  }

  if (!instance && !template) {
    throw new HttpsError("not-found", "This tour is no longer available.");
  }

  const tour = {...(template || {}), ...(instance || {})};
  const config = pricingConfigSnapshot.data() || {};
  const adultPrice = firstConfiguredNumber(
    [tour],
    ["adultPrice", "adult_price", "price"],
  );
  const childPriceConfigured = ["childPrice", "child_price"].some(
    (key) => tour[key] != null && tour[key] !== "",
  );
  const childPrice = childPriceConfigured
    ? firstConfiguredNumber([tour], ["childPrice", "child_price"])
    : null;
  const childRate = firstConfiguredNumber(
    [tour, config],
    ["childRate", "child_rate"],
    0.5,
  );
  const infantPrice = firstConfiguredNumber(
    [tour, config],
    ["infantPrice", "infant_price"],
    0,
  );
  const privateTourSurcharge = firstConfiguredNumber(
    [tour, config],
    ["privateTourSurcharge", "private_tour_surcharge"],
    0,
  );
  const serviceFeePercent = firstConfiguredNumber(
    [tour, config],
    ["serviceFeePercent", "service_fee_percent"],
    0,
  );
  const instanceIsPrivate =
    instance?.isPrivate === true || instance?.visibility === "private";
  const isPrivate = instanceIsPrivate || data.isPrivate === true;

  const pricing = calculatePricing({
    adults,
    kids6to12,
    kidsUnder6,
    adultPrice,
    childPrice,
    infantPrice,
    childRate,
    privateTourSurcharge,
    serviceFeePercent,
    isPrivate,
  });

  const totalSeats = firstConfiguredNumber(
    [tour],
    ["totalSeats", "seat_count"],
  );
  if (totalSeats > 0 && totalPersons > totalSeats) {
    throw new HttpsError(
      "failed-precondition",
      `This tour supports at most ${totalSeats} travelers.`,
    );
  }

  const quoteExpiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
  logger.info("Tour price calculated", {
    tourId,
    sourceTourId,
    totalPersons,
    total: pricing.total,
    uid: request.auth?.uid || null,
  });

  return {
    pricingVersion: 1,
    tourId,
    sourceTourId,
    tourName: String(tour.name || tour.title || "Tour"),
    currency: String(tour.currency || config.currency || "LKR").toUpperCase(),
    isPrivate,
    counts: {adults, kids6to12, kidsUnder6, totalPersons},
    ...pricing,
    quoteExpiresAt,
  };
});
