const functions = require("firebase-functions");
const admin = require("firebase-admin");
const twilio = require("twilio");
const cors = require("cors")({ origin: true });

admin.initializeApp();
const db = admin.firestore();

// ─── Twilio Config ─────────────────────────────────────────
const TWILIO_ACCOUNT_SID = functions.config().twilio.account_sid;
const TWILIO_AUTH_TOKEN = functions.config().twilio.auth_token;
const TWILIO_FROM_NUMBER = functions.config().twilio.from_number;

const twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);

// ─── 1. Send SMS Alert ─────────────────────────────────────
exports.sendSmsAlert = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { phone, message } = req.body;
      if (!phone || !message) {
        return res.status(400).json({ error: "Missing phone or message" });
      }

      await twilioClient.messages.create({
        body: message,
        from: TWILIO_FROM_NUMBER,
        to: phone,
      });

      return res.json({ success: true });
    } catch (error) {
      console.error("SMS error:", error);
      return res.status(500).json({ error: error.message });
    }
  });
});

// ─── 2. Acknowledge Alert (link in SMS) ────────────────────
exports.acknowledgeAlert = functions.https.onRequest(async (req, res) => {
  const alertId = req.query.alertId;
  if (!alertId) {
    return res.status(400).send("Missing alertId");
  }

  try {
    const alertRef = db.collection("alerts").doc(alertId);
    const alertDoc = await alertRef.get();

    if (!alertDoc.exists) {
      return res.status(404).send("Alert not found");
    }

    await alertRef.update({
      acknowledged: true,
      acknowledgedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const contactName = alertDoc.data().contactName || "Contact";

    // Beautiful acknowledgment page
    return res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>SafeAlarm - Alert Acknowledged</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #0A0A1A;
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
          }
          .card {
            background: rgba(255,255,255,0.05);
            border-radius: 24px;
            padding: 40px 32px;
            text-align: center;
            max-width: 400px;
            width: 100%;
            border: 1px solid rgba(255,255,255,0.08);
          }
          .icon {
            width: 80px;
            height: 80px;
            background: rgba(48, 209, 88, 0.15);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            font-size: 36px;
          }
          h1 { font-size: 26px; margin-bottom: 12px; }
          p { color: rgba(255,255,255,0.6); font-size: 16px; line-height: 1.5; }
          .badge {
            display: inline-block;
            background: rgba(48, 209, 88, 0.15);
            color: #30D158;
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
            margin-top: 20px;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">✅</div>
          <h1>Alert Acknowledged</h1>
          <p>Thank you, <strong>${contactName}</strong>. Please check on the person immediately and call emergency services if you cannot reach them.</p>
          <div class="badge">Response logged at ${new Date().toLocaleTimeString()}</div>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    console.error("Ack error:", error);
    return res.status(500).send("Error processing acknowledgment");
  }
});

// ─── 3. Auto-Escalate Check (Firestore trigger) ────────────
// Runs when a trip is updated to 'escalated' status
exports.onTripEscalated = functions.firestore
  .document("trips/{tripId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger when status changes to 'escalated'
    if (before.status !== "escalated" && after.status === "escalated") {
      console.log(`Trip ${context.params.tripId} escalated`);

      // Log to monitoring dashboard
      await db.collection("escalation_metrics").add({
        tripId: context.params.tripId,
        escalatedAt: admin.firestore.FieldValue.serverTimestamp(),
        etaTime: after.eta,
        snoozeCount: after.snoozeCount || 0,
        contactCount: (after.contacts || []).length,
      });
    }
  });

// ─── 4. Scheduled Cleanup (runs daily at 2 AM) ─────────────
exports.cleanupOldSessions = functions.pubsub
  .schedule("0 2 * * *")
  .onRun(async () => {
    const cutoff = new Date();
    cutoff.setHours(cutoff.getHours() - 24);

    const oldTrips = await db
      .collection("trips")
      .where("startTime", "<", cutoff)
      .where("status", "in", ["confirmed", "cancelled"])
      .get();

    const batch = db.batch();
    oldTrips.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    console.log(`Cleaned up ${oldTrips.size} old trips`);
  });

// ─── 5. Metrics Dashboard ──────────────────────────────────
exports.getDashboardMetrics = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const [trips, alerts, metrics] = await Promise.all([
        db.collection("trips").get(),
        db.collection("alerts").get(),
        db.collection("escalation_metrics").get(),
      ]);

      const tripData = trips.docs.map((d) => d.data());
      const alertData = alerts.docs.map((d) => d.data());

      const totalTrips = tripData.length;
      const confirmedTrips = tripData.filter(
        (t) => t.status === "confirmed"
      ).length;
      const escalatedTrips = tripData.filter(
        (t) => t.status === "escalated"
      ).length;
      const acknowledgedAlerts = alertData.filter((a) => a.acknowledged).length;

      return res.json({
        totalTrips,
        confirmedTrips,
        escalatedTrips,
        acknowledgedAlerts,
        totalAlerts: alertData.length,
        ackRate:
          alertData.length > 0
            ? ((acknowledgedAlerts / alertData.length) * 100).toFixed(1)
            : 0,
      });
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  });
});
// ─── 6. Callable SOS Alert (for Flutter app) ───────────────
exports.sendSOSAlert = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }

  let { toPhone, message, location } = data;

  // Format phone number
  let cleanTo = toPhone.replace(/[\s\-\(\)]/g, '');
  if (!cleanTo.startsWith('+')) {
    cleanTo = cleanTo.length === 10 ? `+91${cleanTo}` : `+${cleanTo}`;
  }

  // Append location if provided
  if (location?.latitude && location?.longitude) {
    message += `\n\n📍 Location: https://maps.google.com/?q=${location.latitude},${location.longitude}`;
  }

  try {
    const msg = await twilioClient.messages.create({
      body: message,
      from: TWILIO_FROM_NUMBER,
      to: cleanTo,
    });

    await db.collection("sos_logs").add({
      uid: context.auth.uid,
      toPhone: cleanTo,
      message,
      twilioSid: msg.sid,
      status: "sent",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, sid: msg.sid };
  } catch (error) {
    await db.collection("sos_logs").add({
      uid: context.auth.uid,
      toPhone: cleanTo,
      status: "failed",
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ─── 7. Callable Batch SOS (multiple contacts) ─────────────
exports.sendBatchSOSAlert = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }

  const { contacts, message, location } = data;

  if (!contacts || !Array.isArray(contacts) || contacts.length === 0) {
    throw new functions.https.HttpsError("invalid-argument", "contacts must be a non-empty array.");
  }

  const results = await Promise.allSettled(
    contacts.map(async (phone) => {
      let cleanTo = phone.replace(/[\s\-\(\)]/g, '');
      if (!cleanTo.startsWith('+')) {
        cleanTo = cleanTo.length === 10 ? `+91${cleanTo}` : `+${cleanTo}`;
      }

      let smsBody = message;
      if (location?.latitude && location?.longitude) {
        smsBody += `\n\n📍 Location: https://maps.google.com/?q=${location.latitude},${location.longitude}`;
      }

      const msg = await twilioClient.messages.create({
        body: smsBody,
        from: TWILIO_FROM_NUMBER,
        to: cleanTo,
      });

      return { phone: cleanTo, sid: msg.sid };
    })
  );

  const summary = results.map((r, i) => ({
    phone: contacts[i],
    success: r.status === 'fulfilled',
    error: r.status === 'rejected' ? r.reason?.message : null,
  }));

  return { summary };
});