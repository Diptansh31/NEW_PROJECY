// bottomNav.js
// Instagram-like bottom tab navigation (Home, Search, Chat, Profile)

(function () {
  'use strict';

  const nav = document.getElementById('bottom-nav');
  if (!nav) return;

  function path() {
    const p = (location.pathname || '').split('/').pop();
    return p || 'index.html';
  }

  function setActive() {
    const p = path();
    nav.querySelectorAll('[data-tab]').forEach(a => {
      const match = a.getAttribute('data-tab');
      const alias = (p === 'friends.html') ? 'profile.html' : p;
      const active = match === alias;
      a.classList.toggle('active', active);
      a.setAttribute('aria-current', active ? 'page' : 'false');
    });
  }

  function setVisible(isLoggedIn) {
    nav.classList.toggle('hidden', !isLoggedIn);
    // Avoid content being hidden behind the fixed bottom bar
    document.body.classList.toggle('has-bottom-nav', isLoggedIn);
  }

  // Determine initial visibility quickly (pre-paint uses localStorage)
  try {
    const uid = localStorage.getItem('currentUserUid');
    setVisible(!!uid);
  } catch (e) {
    setVisible(false);
  }

  setActive();

  // If FirebaseClient exists, keep visibility in sync with auth state
  if (window.FirebaseClient) {
    try {
      const { auth } = window.FirebaseClient.initFirebase();
      auth.onAuthStateChanged((user) => {
        setVisible(!!user);
      });
    } catch (e) {
      // ignore
    }
  }
})();
