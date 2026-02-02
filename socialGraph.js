// socialGraph.js
// Friend requests + friends helpers for Firestore.

(function () {
  'use strict';

  function requestId(fromUid, toUid) {
    return `${fromUid}__${toUid}`;
  }

  async function getFriendCount(db, uid) {
    // Friendships are represented by accepted friendRequests.
    // A user is a friend with anyone in requests where status == 'accepted'
    // and (fromUid == uid OR toUid == uid).
    const a = await db.collection('friendRequests')
      .where('fromUid', '==', uid)
      .where('status', '==', 'accepted')
      .get();

    const b = await db.collection('friendRequests')
      .where('toUid', '==', uid)
      .where('status', '==', 'accepted')
      .get();

    return a.size + b.size;
  }

  async function getRequestStatus(db, fromUid, toUid) {
    const rid = requestId(fromUid, toUid);
    const snap = await db.collection('friendRequests').doc(rid).get();
    return snap.exists ? snap.data() : null;
  }

  async function getRelationship(db, meUid, otherUid) {
    // Returns { state, doc } where state is one of:
    // - 'friends' (accepted in either direction)
    // - 'pending_outgoing' (me -> other pending)
    // - 'pending_incoming' (other -> me pending)
    // - 'none'

    const out = await getRequestStatus(db, meUid, otherUid);
    if (out?.status === 'accepted') return { state: 'friends', doc: out };
    if (out?.status === 'pending') return { state: 'pending_outgoing', doc: out };

    const inc = await getRequestStatus(db, otherUid, meUid);
    if (inc?.status === 'accepted') return { state: 'friends', doc: inc };
    if (inc?.status === 'pending') return { state: 'pending_incoming', doc: inc };

    return { state: 'none', doc: null };
  }

  async function getFriendUidSet(db, uid) {
    const a = await db.collection('friendRequests')
      .where('fromUid', '==', uid)
      .where('status', '==', 'accepted')
      .get();

    const b = await db.collection('friendRequests')
      .where('toUid', '==', uid)
      .where('status', '==', 'accepted')
      .get();

    const set = new Set();
    a.forEach(doc => {
      const d = doc.data();
      if (d?.toUid) set.add(d.toUid);
    });
    b.forEach(doc => {
      const d = doc.data();
      if (d?.fromUid) set.add(d.fromUid);
    });
    return set;
  }

  async function listFriendUids(db, uid) {
    const set = await getFriendUidSet(db, uid);
    return Array.from(set);
  }

  async function listFriends(db, uid) {
    const uids = await listFriendUids(db, uid);
    // Firestore doesn't support "in" with >10 values in older SDKs, so fetch individually.
    const out = [];
    for (const otherUid of uids) {
      try {
        const snap = await db.collection('users').doc(otherUid).get();
        if (snap.exists) out.push({ uid: otherUid, profile: snap.data() });
      } catch (e) {
        // ignore
      }
    }
    return out;
  }

  async function sendFriendRequest(db, fromUid, toUid) {
    if (!fromUid || !toUid) throw new Error('Missing uid');
    if (fromUid === toUid) throw new Error('Cannot friend yourself');

    const rid = requestId(fromUid, toUid);
    const ref = db.collection('friendRequests').doc(rid);

    // Prevent sending if already friends (i.e., already accepted in either direction)
    const ab = await db.collection('friendRequests').doc(requestId(fromUid, toUid)).get();
    if (ab.exists && ab.data()?.status === 'accepted') return { alreadyFriends: true };

    const ba = await db.collection('friendRequests').doc(requestId(toUid, fromUid)).get();
    if (ba.exists && ba.data()?.status === 'accepted') return { alreadyFriends: true };

    await ref.set({
      fromUid,
      toUid,
      status: 'pending',
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      updatedAt: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return { requested: true };
  }

  async function cancelFriendRequest(db, fromUid, toUid) {
    const rid = requestId(fromUid, toUid);
    await db.collection('friendRequests').doc(rid).delete();
  }

  async function acceptFriendRequest(db, fromUid, toUid) {
    // Accept request that was sent from fromUid -> toUid (current user is toUid).
    // IMPORTANT: With secure rules, the receiver cannot write into the sender's /friends/{senderUid}.
    // So we treat the accepted friendRequests doc as the friendship record.
    const rid = requestId(fromUid, toUid);
    const reqRef = db.collection('friendRequests').doc(rid);

    await db.runTransaction(async (tx) => {
      const reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw new Error('Request no longer exists');

      const req = reqSnap.data();
      if (req.status !== 'pending') throw new Error('Request is not pending');

      tx.update(reqRef, { status: 'accepted', updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
    });
  }

  async function declineFriendRequest(db, fromUid, toUid) {
    const rid = requestId(fromUid, toUid);
    const reqRef = db.collection('friendRequests').doc(rid);
    await reqRef.set({ status: 'declined', updatedAt: firebase.firestore.FieldValue.serverTimestamp() }, { merge: true });
  }

  async function listIncomingRequests(db, uid) {
    const snap = await db.collection('friendRequests')
      .where('toUid', '==', uid)
      .where('status', '==', 'pending')
      .limit(50)
      .get();

    const items = [];
    snap.forEach(doc => items.push({ id: doc.id, ...doc.data() }));
    return items;
  }

  window.SocialGraph = {
    requestId,
    getFriendCount,
    getFriendUidSet,
    listFriendUids,
    listFriends,
    getRequestStatus,
    getRelationship,
    sendFriendRequest,
    cancelFriendRequest,
    acceptFriendRequest,
    declineFriendRequest,
    listIncomingRequests
  };
})();
