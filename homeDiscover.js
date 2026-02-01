// homeDiscover.js
// Uses the existing "Meet Your Other Half" (Members) section to show suggestions.

(function () {
  'use strict';

  if (!window.FirebaseClient) return;

  const membersSection = document.getElementById('members');
  const titleEl = document.getElementById('members-title');
  const grid = document.getElementById('members-grid');
  const errorBox = document.getElementById('members-error');

  const searchInput = document.getElementById('members-search');
  const branchSelect = document.getElementById('filter-branch');
  const yearSelect = document.getElementById('filter-year');
  const interestSelect = document.getElementById('filter-interests');
  const searchBtn = document.getElementById('members-btn-search');
  const refreshBtn = document.getElementById('members-btn-refresh');

  if (!membersSection || !grid || !errorBox || !searchInput || !branchSelect || !yearSelect || !interestSelect || !searchBtn || !refreshBtn) {
    return;
  }

  const { auth, db } = window.FirebaseClient.initFirebase();

  const state = {
    me: null,
    candidates: [], // [{uid, profile, score, shared}]
    lastLoadedAt: 0
  };

  function setError(msg) {
    if (!msg) {
      errorBox.style.display = 'none';
      errorBox.textContent = '';
      return;
    }
    errorBox.style.display = 'block';
    errorBox.textContent = msg;
  }

  function escapeHtml(str) {
    return String(str || '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }

  function scoreCandidate(me, other) {
    const myInterests = new Set((me.interests || []).map(s => String(s).toLowerCase()));
    const otherInterests = new Set((other.interests || []).map(s => String(s).toLowerCase()));
    const shared = [];
    myInterests.forEach(i => { if (otherInterests.has(i)) shared.push(i); });

    let score = 0;
    score += shared.length * 5;
    if (me.collegeName && other.collegeName && me.collegeName === other.collegeName) score += 10;
    if (me.branchCode && other.branchCode && me.branchCode === other.branchCode) score += 5;
    if (me.graduationYear && other.graduationYear && Math.abs(me.graduationYear - other.graduationYear) <= 1) score += 2;

    return { score, shared };
  }

  function renderCards(items) {
    // Replace the demo cards
    grid.replaceChildren();

    if (!items.length) {
      const empty = document.createElement('div');
      empty.style.opacity = '0.9';
      empty.textContent = 'No suggestions found. Try Refresh or change filters.';
      grid.appendChild(empty);
      return;
    }

    items.forEach(({ uid, profile }) => {
      const card = document.createElement('div');
      card.className = 'profile-card';

      const imgWrap = document.createElement('div');
      imgWrap.className = 'profile-image';

      const img = document.createElement('img');
      img.src = profile.avatarDataUrl || 'https://via.placeholder.com/300?text=Avatar';
      img.alt = 'Profile';

      const view = document.createElement('a');
      view.href = `profile.html?uid=${encodeURIComponent(uid)}`;
      view.className = 'heart-btn';
      view.title = 'View profile';
      view.textContent = '👁';
      view.style.textDecoration = 'none';

      imgWrap.appendChild(img);
      imgWrap.appendChild(view);

      const name = document.createElement('h3');
      name.className = 'profile-name';
      name.textContent = profile.fullName || `@${profile.username || 'user'}`;

      const sub = document.createElement('p');
      sub.className = 'profile-location';
      sub.textContent = `${profile.branchCode || profile.branch || 'Branch'} • ${profile.collegeName || ''}`;

      card.appendChild(imgWrap);
      card.appendChild(name);
      card.appendChild(sub);

      grid.appendChild(card);
    });
  }

  function setSelectOptions(selectEl, values, placeholder) {
    const current = selectEl.value;
    selectEl.replaceChildren();

    const first = document.createElement('option');
    first.value = '';
    first.textContent = placeholder;
    selectEl.appendChild(first);

    values.forEach(v => {
      const opt = document.createElement('option');
      opt.value = v;
      opt.textContent = v;
      selectEl.appendChild(opt);
    });

    // Restore if still present
    const has = Array.from(selectEl.options).some(o => o.value === current);
    selectEl.value = has ? current : '';
  }

  function applyFiltersAndRender() {
    setError('');

    let items = [...state.candidates];

    const branch = branchSelect.value;
    const year = yearSelect.value;
    const interest = interestSelect.value;

    if (branch) items = items.filter(x => (x.profile.branchCode || x.profile.branch) === branch);
    if (year) items = items.filter(x => String(x.profile.graduationYear || '') === String(year));

    if (interest) {
      const i = String(interest).toLowerCase();
      items = items.filter(x => (x.profile.interests || []).some(s => String(s).toLowerCase() === i));
    }

    // Always keep best matches first
    items.sort((a, b) => b.score - a.score);

    renderCards(items.slice(0, 18));
  }

  async function loadMeAndCandidates(user) {
    setError('');

    const meSnap = await db.collection('users').doc(user.uid).get();
    if (!meSnap.exists) throw new Error('Your profile is missing. Please complete registration.');
    const me = meSnap.data();
    state.me = me;

    // Male↔Female suggestions
    const targetGender = me.gender === 'Male' ? 'Female' : 'Male';

    const q = db.collection('users')
      .where('gender', '==', targetGender)
      .where('collegeName', '==', me.collegeName)
      .limit(120);

    const snap = await q.get();

    const candidates = [];
    snap.forEach(doc => {
      if (doc.id === user.uid) return;
      const profile = doc.data();
      const { score, shared } = scoreCandidate(me, profile);
      candidates.push({ uid: doc.id, profile, score, shared });
    });

    state.candidates = candidates;
    state.lastLoadedAt = Date.now();

    // Build filter options from results
    const branches = Array.from(new Set(candidates.map(c => c.profile.branchCode || c.profile.branch).filter(Boolean))).sort();
    const years = Array.from(new Set(candidates.map(c => c.profile.graduationYear).filter(Boolean))).sort((a, b) => a - b).map(String);
    const interests = Array.from(new Set(candidates.flatMap(c => (c.profile.interests || []).map(i => String(i))))).filter(Boolean).sort();

    setSelectOptions(branchSelect, branches, 'Branch (All)');
    setSelectOptions(yearSelect, years, 'Year (All)');
    setSelectOptions(interestSelect, interests, 'Interest (All)');

    applyFiltersAndRender();
  }

  async function searchByUsername(user, rawUsername) {
    setError('');

    const username = window.FirebaseClient.normalizeUsername(rawUsername);
    if (!username) {
      setError('Enter a username to search.');
      return;
    }

    const idx = await db.collection('usernames').doc(username).get();
    if (!idx.exists) {
      setError('No user found with that username.');
      return;
    }

    const uid = idx.data().uid;
    const snap = await db.collection('users').doc(uid).get();
    if (!snap.exists) {
      setError('User exists but profile is missing.');
      return;
    }

    const profile = snap.data();

    // show the searched profile as a single card
    renderCards([{ uid, profile, score: 0, shared: [] }]);
  }

  // UI wiring
  searchBtn.addEventListener('click', () => {
    const u = auth.currentUser;
    if (!u) return;
    const q = (searchInput.value || '').trim();
    if (!q) {
      applyFiltersAndRender();
      return;
    }
    searchByUsername(u, q).catch(e => setError(e?.message || String(e)));
  });

  refreshBtn.addEventListener('click', () => {
    const u = auth.currentUser;
    if (!u) return;
    loadMeAndCandidates(u).catch(e => setError(e?.message || String(e)));
  });

  branchSelect.addEventListener('change', applyFiltersAndRender);
  yearSelect.addEventListener('change', applyFiltersAndRender);
  interestSelect.addEventListener('change', applyFiltersAndRender);

  // Auth state
  auth.onAuthStateChanged((user) => {
    if (!user) {
      // Keep the landing page demo cards when logged out.
      if (titleEl) titleEl.textContent = 'Meet Your Other Half';
      return;
    }

    if (titleEl) titleEl.textContent = 'Suggested Matches';
    loadMeAndCandidates(user).catch(e => setError(e?.message || String(e)));
  });
})();
