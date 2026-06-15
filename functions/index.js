const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * MAKE USER ADMIN (SECURE)
 * Only existing admins can promote others
 */
exports.makeAdmin = functions.https.onCall(async (data, context) => {

  const requesterUid = context.auth ? context.auth.uid : null;
  const targetUid = data.uid;

  // 1. Must be logged in
  if (!requesterUid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Login required"
    );
  }

  // 2. Check requester admin status
  const requesterUser = await admin.auth().getUser(requesterUid);
  const claims = requesterUser.customClaims || {};

  if (claims.admin !== true) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can assign admin role"
    );
  }

  // 3. Set admin claim for target user
  await admin.auth().setCustomUserClaims(targetUid, {
    admin: true
  });

  return {
    success: true,
    message: "User successfully promoted to admin"
  };
});