const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Callable: deleteThreadRecursive({ threadId })
// Deletes /threads/{threadId} and its /messages subcollection.
exports.deleteThreadRecursive = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const threadId = data && data.threadId;
  if (!threadId || typeof threadId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'threadId is required');
  }

  const db = admin.firestore();
  const threadRef = db.collection('threads').doc(threadId);
  const threadSnap = await threadRef.get();
  if (!threadSnap.exists) {
    return { ok: true, deleted: false };
  }

  const t = threadSnap.data();
  const uid = context.auth.uid;
  const isMember = t.userAUid === uid || t.userBUid === uid;
  if (!isMember) {
    throw new functions.https.HttpsError('permission-denied', 'Not a thread member');
  }

  // Best-effort: delete messages in batches.
  const messagesRef = threadRef.collection('messages');
  while (true) {
    const snap = await messagesRef.limit(500).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
  }

  await threadRef.delete();
  return { ok: true, deleted: true };
});
