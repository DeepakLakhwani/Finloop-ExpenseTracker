const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// ✅ Retrieve Web3Forms Access Key securely from Environment variables or Firebase config
const WEB3FORMS_KEY = process.env.WEB3FORMS_KEY || (functions.config().app ? functions.config().app.web3forms_key : "");

/**
 * Cloud Function: sendFeedbackEmail
 * Enforces secure identity verification server-side and submits feedback to Web3Forms.
 */
exports.sendFeedbackEmail = functions.https.onCall(async (data, context) => {
  // 1. Enforce authenticated session cryptographically on the server
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required to submit feedback."
    );
  }

  // 2. Retrieve secure identity details directly from the validated authentication context
  const userId = context.auth.uid;
  const authEmail = context.auth.token.email || "No Email User";

  // 3. Extract non-identity telemetry from the client data payload
  const { type, message, imageUrl, deviceInfo, timestamp, appVersion, email } = data;

  const userEmail = email || authEmail;

  if (!message || !type) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Feedback message and type are required."
    );
  }

  // 4. Verify that we have a configured Access Key
  if (!WEB3FORMS_KEY) {
    console.error("WEB3FORMS_KEY is missing from server configuration!");
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Server is missing the feedback email provider configuration."
    );
  }

  try {
    // 5. Submit securely to Web3Forms
    const response = await axios.post("https://api.web3forms.com/submit", {
      access_key: WEB3FORMS_KEY,
      subject: `[FinLoop ${type.toUpperCase()}] Feedback from ${userEmail}`,
      from_name: "FinLoop Diagnostics",
      replyto: userEmail === "No Email User" ? "support.finloop@gmail.com" : userEmail,
      message: `
A user has submitted feedback through the FinLoop App.

==================================================
DIAGNOSTICS & SYSTEM DETAILS
==================================================
Feedback Type   : ${type}
User UID        : ${userId}
User Email      : ${userEmail}
Submission Time : ${timestamp}
Device OS Info  : ${deviceInfo}
App Version     : ${appVersion}
Attachment URL  : ${imageUrl || "No screenshot attached"}

==================================================
FEEDBACK MESSAGE
==================================================
${message}

==================================================
This email was securely routed through the FinLoop Cloud Server Proxy.
      `.trim()
    });

    console.log(`Web3Forms submit response status: ${response.status}`);
    return { success: response.status === 200 };
  } catch (error) {
    console.error("Failed to submit feedback to Web3Forms API:", error.message);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to route email: ${error.message}`
    );
  }
});
