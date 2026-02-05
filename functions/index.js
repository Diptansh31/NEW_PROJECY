const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// ===========================
// Voice Call Push Notification
// ===========================
// Triggered when a new call document is created.
// Sends a push notification to the callee to show incoming call UI.
exports.onCallCreated = functions.firestore
  .document('calls/{callId}')
  .onCreate(async (snapshot, context) => {
    const callData = snapshot.data();
    const callId = context.params.callId;

    if (!callData || callData.status !== 'ringing') {
      return null;
    }

    const calleeUid = callData.calleeUid;
    const callerUid = callData.callerUid;

    // Get callee's FCM token
    const calleeDoc = await admin.firestore().collection('users').doc(calleeUid).get();
    const fcmToken = calleeDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${calleeUid}`);
      return null;
    }

    // Get caller's name
    const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
    const callerName = callerDoc.data()?.username || 'Someone';

    // Send high-priority push notification
    const message = {
      token: fcmToken,
      data: {
        type: 'incoming_call',
        callId: callId,
        callerUid: callerUid,
        callerName: callerName,
      },
      android: {
        priority: 'high',
        ttl: 30000, // 30 seconds
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'voip',
        },
        payload: {
          aps: {
            contentAvailable: true,
            sound: 'default',
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`Push notification sent for call ${callId} to user ${calleeUid}`);
    } catch (error) {
      console.error('Error sending push notification:', error);
    }

    return null;
  });

// Triggered when a call is updated (ended, rejected, etc.)
// Sends a push to dismiss the incoming call UI.
exports.onCallUpdated = functions.firestore
  .document('calls/{callId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const callId = context.params.callId;

    // Only notify if status changed from ringing to something else
    if (beforeData.status === 'ringing' && afterData.status !== 'ringing') {
      const calleeUid = afterData.calleeUid;

      // Get callee's FCM token
      const calleeDoc = await admin.firestore().collection('users').doc(calleeUid).get();
      const fcmToken = calleeDoc.data()?.fcmToken;

      if (!fcmToken) {
        return null;
      }

      // Send notification to dismiss call
      const message = {
        token: fcmToken,
        data: {
          type: 'call_ended',
          callId: callId,
          status: afterData.status,
        },
        android: {
          priority: 'high',
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
        },
      };

      try {
        await admin.messaging().send(message);
        console.log(`Call ended notification sent for call ${callId}`);
      } catch (error) {
        console.error('Error sending call ended notification:', error);
      }
    }

    return null;
  });

// ===========================
// Thread Deletion
// ===========================
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
