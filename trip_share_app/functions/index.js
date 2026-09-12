"use strict";

const {getApps, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");
const {setGlobalOptions} = require("firebase-functions/v2");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
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
  const bookingId = typeof data.bookingId === "string"
    ? data.bookingId.trim()
    : "";
  if (bookingId && (bookingId.length > 256 || bookingId.includes("/"))) {
    throw new HttpsError("invalid-argument", "A valid bookingId is required.");
  }
  const totalPersons = adults + kids6to12 + kidsUnder6;
  if (totalPersons > 100) {
    throw new HttpsError(
      "invalid-argument",
      "A quote cannot contain more than 100 travelers.",
    );
  }

  const [
    instanceSnapshot,
    directTourSnapshot,
    pricingConfigSnapshot,
    existingBookingSnapshot,
  ] =
    await Promise.all([
      db.collection("tour_instances").doc(tourId).get(),
      db.collection("tours").doc(tourId).get(),
      db.collection("app_config").doc("pricing").get(),
      bookingId
        ? db.collection("bookings").doc(bookingId).get()
        : Promise.resolve(null),
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
  const configuredPricingMode = String(
    tour.pricingMode || tour.pricing_mode || "per_person",
  ).toLowerCase();
  const pricingMode = configuredPricingMode === "fixed_tour"
    ? "fixed_tour"
    : configuredPricingMode === "per_seat" ||
        tour.sourceType === "community_ride"
      ? "per_seat"
      : "per_person";
  const fixedTourPrice = firstConfiguredNumber(
    [tour],
    ["fixedTourPrice", "fixed_tour_price"],
  );

  if (pricingMode === "fixed_tour" && !isPrivate) {
    throw new HttpsError(
      "failed-precondition",
      "Fixed full-tour pricing is available only for private tours.",
    );
  }
  if (pricingMode === "fixed_tour" && fixedTourPrice <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "The administrator has not configured the full tour price.",
    );
  }

  const alreadyBookedSeats = instance
    ? firstConfiguredNumber([instance], ["bookedSeats"], 0)
    : 0;
  let existingPassengerCount = 0;
  if (bookingId) {
    if (!request.auth?.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before changing an existing booking.",
      );
    }
    const existingBooking = existingBookingSnapshot?.data();
    if (!existingBooking) {
      throw new HttpsError("not-found", "This booking no longer exists.");
    }
    if (existingBooking.userId !== request.auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "You can calculate changes only for your own booking.",
      );
    }
    const bookingInstanceId = String(
      existingBooking.instanceId || existingBooking.tourId || "",
    );
    if (bookingInstanceId !== tourId) {
      throw new HttpsError(
        "invalid-argument",
        "The booking does not belong to this tour.",
      );
    }
    existingPassengerCount = firstConfiguredNumber(
      [existingBooking],
      ["totalPersons", "numberOfPeople"],
    );
  }
  if (existingPassengerCount > alreadyBookedSeats) {
    throw new HttpsError(
      "invalid-argument",
      "The existing passenger count is greater than the booked seats.",
    );
  }
  const passengersAfterBooking =
    alreadyBookedSeats - existingPassengerCount + totalPersons;

  const pricing = calculatePricing({
    adults,
    kids6to12,
    kidsUnder6,
    pricingMode,
    adultPrice,
    fixedTourPrice,
    passengersAfterBooking,
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
    pricingVersion: 2,
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

exports.rebalanceFixedTourPrices = onDocumentWritten(
  "tour_instances/{instanceId}",
  async (event) => {
    const instance = event.data?.after.data();
    if (!instance) return;

    const pricingMode = String(
      instance.pricingMode || instance.pricing_mode || "per_person",
    ).toLowerCase();
    const isPrivate =
      instance.isPrivate === true || instance.visibility === "private";
    if (pricingMode !== "fixed_tour" || !isPrivate) return;

    const instanceId = event.params.instanceId;
    const sourceTourId = String(
      instance.sourceIdleTourId || instance.templateTourId || "",
    ).trim();
    const [templateSnapshot, configSnapshot, bookingsSnapshot] =
      await Promise.all([
        sourceTourId && !sourceTourId.includes("/")
          ? db.collection("tours").doc(sourceTourId).get()
          : Promise.resolve(null),
        db.collection("app_config").doc("pricing").get(),
        db.collection("bookings").where("instanceId", "==", instanceId).get(),
      ]);

    const template = templateSnapshot?.data() || {};
    const config = configSnapshot.data() || {};
    const tour = {...template, ...instance};
    const fixedTourPrice = firstConfiguredNumber(
      [tour],
      ["fixedTourPrice", "fixed_tour_price"],
    );
    if (fixedTourPrice <= 0) return;

    const activeBookings = bookingsSnapshot.docs.filter((bookingDoc) => {
      const status = String(bookingDoc.data().status || "active").toLowerCase();
      return status !== "cancelled";
    });
    const bookedSeats = activeBookings.reduce(
      (sum, bookingDoc) => sum + firstConfiguredNumber(
        [bookingDoc.data()],
        ["totalPersons", "numberOfPeople"],
      ),
      0,
    );
    if (bookedSeats <= 0) return;

    const privateTourSurcharge = firstConfiguredNumber(
      [tour, config],
      ["privateTourSurcharge", "private_tour_surcharge"],
    );
    const serviceFeePercent = firstConfiguredNumber(
      [tour, config],
      ["serviceFeePercent", "service_fee_percent"],
    );
    const currency = String(tour.currency || config.currency || "LKR")
      .toUpperCase();
    const batch = db.batch();

    for (const bookingDoc of activeBookings) {
      const booking = bookingDoc.data();
      const adults = firstConfiguredNumber([booking], ["adults"]);
      const kids6to12 = firstConfiguredNumber([booking], ["kids6to12"]);
      const kidsUnder6 = firstConfiguredNumber([booking], ["kidsUnder6"]);
      const recordedTotal = adults + kids6to12 + kidsUnder6;
      const totalPersons = firstConfiguredNumber(
        [booking],
        ["totalPersons", "numberOfPeople"],
      );
      const normalizedAdults = recordedTotal > 0 ? adults : totalPersons;
      const pricing = calculatePricing({
        adults: normalizedAdults,
        kids6to12,
        kidsUnder6,
        pricingMode: "fixed_tour",
        fixedTourPrice,
        passengersAfterBooking: bookedSeats,
        privateTourSurcharge,
        serviceFeePercent,
        isPrivate: true,
      });
      batch.update(bookingDoc.ref, {
        totalPrice: pricing.total,
        currency,
        pricingVersion: 2,
        pricingBreakdown: {
          pricingVersion: 2,
          currency,
          ...pricing,
          rebalancedAt: FieldValue.serverTimestamp(),
        },
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    logger.info("Fixed tour booking prices rebalanced", {
      instanceId,
      bookings: activeBookings.length,
      bookedSeats,
    });
  },
);

exports.attachCommunityRideContact = onDocumentCreated(
  "bookings/{bookingId}",
  async (event) => {
    const booking = event.data?.data();
    if (!booking) return;
    const instanceId = String(booking.instanceId || booking.tourId || "");
    if (!instanceId) return;

    const instanceSnapshot = await db
      .collection("tour_instances")
      .doc(instanceId)
      .get();
    const instance = instanceSnapshot.data();
    if (!instance || instance.sourceType !== "community_ride") return;

    const submissionId = String(
      instance.communityRideSubmissionId || instanceId,
    );
    const submissionSnapshot = await db
      .collection("community_ride_submissions")
      .doc(submissionId)
      .get();
    const submission = submissionSnapshot.data();
    if (!submission) return;

    await event.data.ref.update({
      rideHostContact: {
        hostName: String(submission.hostName || instance.hostName || ""),
        hostPhone: String(submission.hostPhone || ""),
        whatsappNumber: String(submission.whatsappNumber || ""),
        driverName: String(submission.driverName || ""),
        driverPhone: String(submission.driverPhone || ""),
        vehicleType: String(submission.vehicleType || ""),
      },
      updatedAt: FieldValue.serverTimestamp(),
    });
    logger.info("Community ride contact attached to booking", {
      bookingId: event.params.bookingId,
      instanceId,
    });
  },
);
