// firebaseClient.js
// Shared Firebase init + small helpers.
// Uses Firebase compat SDKs loaded by pages.

(function () {
  'use strict';

  const firebaseConfig = {
    apiKey: "AIzaSyDRyhp99So6xUzagcA5DX3nBoXvYNhSYjE",
    authDomain: "new-project-3e40e.firebaseapp.com",
    projectId: "new-project-3e40e",
    storageBucket: "new-project-3e40e.firebasestorage.app",
    messagingSenderId: "974515466511",
    appId: "1:974515466511:web:dff3042456dcca6b488e7a",
    measurementId: "G-MJ90LDCSWS"
  };

  function initFirebase() {
    if (!window.firebase) throw new Error('Firebase SDK not loaded');
    try {
      firebase.initializeApp(firebaseConfig);
    } catch (e) {
      // ignore "already exists" errors
    }
    return {
      auth: firebase.auth(),
      db: firebase.firestore()
    };
  }

  function normalizeUsername(username) {
    return String(username || '')
      .trim()
      .toLowerCase()
      .replace(/\s+/g, '')
      .replace(/[^a-z0-9._]/g, '');
  }

  window.FirebaseClient = {
    initFirebase,
    normalizeUsername
  };
})();
