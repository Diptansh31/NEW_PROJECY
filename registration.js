/*
  registration.js
  Vanilla-JS multi-step registration wizard for registrationPage.html.

  Notes:
  - This keeps the same client-side OTP approach as the original React version.
    For real security, OTP generation/verification must be server-side.
*/

(() => {
  'use strict';

  // ----------------------------
  // Config (copied from original)
  // ----------------------------
  // Firebase is initialized via firebaseClient.js

  const EMAILJS_PUBLIC_KEY = "vMHaw0fLsCU1hg1NL";
  const EMAILJS_SERVICE_ID = "service_5o78aj6";
  const EMAILJS_TEMPLATE_ID = "template_6lrb5te";

  // ----------------------------
  // State
  // ----------------------------
  const state = {
    step: 1,
    otpSent: false,
    generatedOtp: '',
    timer: 0,
    loading: false,
    formData: {
      collegeEmail: '',
      isVerified: false,
      graduationYear: null,
      collegeName: '',
      branch: '',
      branchCode: '',
      fullName: '',
      gender: '',
      profilePictures: [], // base64 previews
      interests: [],
      bio: '',
      username: '',
      password: ''
    }
  };

  // ----------------------------
  // Constants
  // ----------------------------
  const VALID_BRANCHES = {
    bt: 'Bio Technology',
    cm: 'Chemical Engineering',
    ce: 'Civil Engineering',
    cs: 'Computer Science and Engineering',
    cse: 'Computer Science and Engineering',
    ec: 'Electronics and Communication Engineering',
    ece: 'Electronics and Communication Engineering',
    ee: 'Electrical Engineering',
    ice: 'Instrumentation and Control Engineering',
    ip: 'Industrial and Production Engineering',
    it: 'Information Technology',
    me: 'Mechanical Engineering',
    tt: 'Textile Technology'
  };

  const PREDEFINED_INTERESTS = [
    'Music', 'Travel', 'Fitness', 'Photography', 'Cooking',
    'Reading', 'Movies', 'Gaming', 'Art', 'Dancing',
    'Sports', 'Yoga', 'Hiking', 'Coffee', 'Fashion',
    'Tech', 'Writing', 'Volunteering', 'Foodie', 'Nature'
  ];

  // For matching MVP we keep gender selection, but suggestions will be Male↔Female.
  const GENDER_OPTIONS = ['Male', 'Female'];

  // ----------------------------
  // Helpers
  // ----------------------------
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  function setText(sel, text) {
    const el = $(sel);
    if (el) el.textContent = text;
  }

  function show(el) {
    el?.classList.remove('hidden');
  }

  function hide(el) {
    el?.classList.add('hidden');
  }

  function setError(id, message) {
    const box = $(`[data-error-for="${id}"]`);
    const text = box?.querySelector('[data-error-text]');
    if (!box || !text) return;
    if (message) {
      text.textContent = message;
      show(box);
    } else {
      text.textContent = '';
      hide(box);
    }
  }

  function formatTimer(seconds) {
    const m = Math.floor(seconds / 60);
    const s = String(seconds % 60).padStart(2, '0');
    return `${m}:${s}`;
  }

  function setLoading(isLoading, label) {
    state.loading = isLoading;

    const sendOtpBtn = $('#btn-send-otp');
    const verifyOtpBtn = $('#btn-verify-otp');
    const resendOtpBtn = $('#btn-resend-otp');
    const continueBtn = $('#btn-continue');

    const disable = !!isLoading;

    [sendOtpBtn, verifyOtpBtn, resendOtpBtn, continueBtn].forEach(btn => {
      if (!btn) return;
      btn.disabled = disable || btn.dataset.forceDisabled === 'true';
    });

    if (continueBtn) {
      continueBtn.querySelector('[data-btn-label]')?.replaceChildren(document.createTextNode(label || (disable ? 'Saving...' : 'Continue')));
    }
  }

  // ----------------------------
  // Email parsing
  // ----------------------------
  function parseCollegeEmail(email) {
    // Supported formats:
    // 1) name.branch.year@college.ac.in   (your requested format)
    // 2) name.initial.branch.year@college.ac.in (older format kept for compatibility)

    const trimmed = (email || '').trim().toLowerCase();

    // new format
    const rxNew = /^([a-zA-Z]+)\.([a-zA-Z]+)\.(\d{2})@([a-zA-Z]+)\.(ac\.in|edu)$/;
    // old format
    const rxOld = /^([a-zA-Z]+)\.([a-zA-Z])\.([a-zA-Z]+)\.(\d{2})@([a-zA-Z]+)\.(ac\.in|edu)$/;

    let match = trimmed.match(rxNew);
    let firstName;
    let lastInitial = '';
    let branchCode;
    let yearShort;
    let college;

    if (match) {
      [, firstName, branchCode, yearShort, college] = match;
    } else {
      match = trimmed.match(rxOld);
      if (!match) return { valid: false };
      [, firstName, lastInitial, branchCode, yearShort, college] = match;
    }

    const year = 2000 + parseInt(yearShort, 10);
    const branchCodeLower = (branchCode || '').toLowerCase();

    if (!VALID_BRANCHES[branchCodeLower]) {
      return {
        valid: false,
        outOfCampus: true,
        branchCode: (branchCode || '').toUpperCase()
      };
    }

    return {
      valid: true,
      outOfCampus: false,
      firstName,
      lastInitial,
      branchCode: (branchCode || '').toUpperCase(),
      branch: VALID_BRANCHES[branchCodeLower],
      year,
      college: (college || '').toUpperCase()
    };
  }

  // ----------------------------
  // OTP
  // ----------------------------
  function generateOTP() {
    return String(Math.floor(100000 + Math.random() * 900000));
  }

  function describeEmailJsError(err) {
    if (!err) return 'Unknown error';
    // EmailJS often returns { status, text }
    const status = err.status ? `status ${err.status}` : '';
    const text = err.text || err.message || String(err);
    return [status, text].filter(Boolean).join(' - ');
  }

  function describeFirebaseAuthError(err) {
    const code = err?.code || '';
    const msg = err?.message || String(err);
    return code ? `${code}: ${msg}` : msg;
  }

  function getOtpValue() {
    return $$('.otp-input').map(i => i.value.trim()).join('');
  }

  function clearOtpInputs() {
    $$('.otp-input').forEach(i => (i.value = ''));
    $$('.otp-input')[0]?.focus();
  }

  function setOtpUI(sent) {
    state.otpSent = sent;
    const otpArea = $('#otp-area');
    const sendBtn = $('#btn-send-otp');
    const emailInput = $('#college-email');

    if (emailInput) emailInput.disabled = sent;

    if (sent) {
      hide(sendBtn);
      show(otpArea);
    } else {
      show(sendBtn);
      hide(otpArea);
    }
  }

  function updateTimerUI() {
    const timerEl = $('#otp-timer');
    const resendBtn = $('#btn-resend-otp');

    if (!timerEl || !resendBtn) return;

    if (state.timer > 0) {
      timerEl.textContent = formatTimer(state.timer);
      resendBtn.disabled = true;
      resendBtn.dataset.forceDisabled = 'true';
    } else {
      timerEl.textContent = 'OTP Expired';
      resendBtn.disabled = false;
      resendBtn.dataset.forceDisabled = 'false';
    }
  }

  function startTimer(seconds) {
    state.timer = seconds;
    updateTimerUI();
  }

  // ----------------------------
  // Step control
  // ----------------------------
  function totalSteps() {
    return 7;
  }

  function canProceed() {
    switch (state.step) {
      case 1:
        return state.formData.isVerified;
      case 2: {
        const fullNameOk = state.formData.fullName.trim().length >= 2;
        const usernameOk = (state.formData.username || '').trim().length >= 3;
        const passwordOk = (state.formData.password || '').length >= 6;
        return fullNameOk && usernameOk && passwordOk;
      }
      case 3:
        return !!state.formData.gender;
      case 4:
        return state.formData.profilePictures.length >= 2;
      case 5:
        return state.formData.interests.length >= 5;
      case 6:
        return state.formData.bio.trim().length >= 50;
      default:
        return true;
    }
  }

  function updateNavButtons() {
    const backBtn = $('#btn-back');
    const continueBtn = $('#btn-continue');

    if (backBtn) backBtn.disabled = state.loading || state.step <= 1 || state.step >= 7;

    if (continueBtn) {
      continueBtn.disabled = state.loading || !canProceed() || state.step >= 7;
      continueBtn.querySelector('[data-btn-label]')?.replaceChildren(document.createTextNode(state.step === 6 ? 'Complete Registration' : 'Continue'));
    }

    const hint = $('#step-hint');
    if (hint) {
      const remaining = Math.max(0, 5 - state.formData.interests.length);
      if (state.step === 5 && state.formData.interests.length > 0 && state.formData.interests.length < 5) {
        hint.textContent = `Select ${remaining} more ${remaining === 1 ? 'interest' : 'interests'} to continue`;
        hint.classList.remove('hidden');
      } else {
        hint.textContent = '';
        hint.classList.add('hidden');
      }
    }
  }

  function renderProgress() {
    setText('#progress-step', `Step ${state.step} of ${totalSteps()}`);
    setText('#progress-percent', `${Math.round((state.step / totalSteps()) * 100)}%`);

    const bar = $('#progress-bar');
    if (bar) bar.style.width = `${(state.step / totalSteps()) * 100}%`;
  }

  function showStep(step) {
    state.step = step;

    $$('.step-panel').forEach(p => p.classList.add('hidden'));
    const panel = $(`.step-panel[data-step="${step}"]`);
    panel?.classList.remove('hidden');

    renderProgress();
    updateNavButtons();

    // Populate summary panel
    if (step === 7) {
      $('#summary-name').textContent = state.formData.fullName || '-';
      $('#summary-gender').textContent = state.formData.gender || '-';
      $('#summary-college').textContent = state.formData.collegeName || '-';
      $('#summary-branch').textContent = state.formData.branch ? `${state.formData.branch} (${state.formData.branchCode})` : '-';
      $('#summary-year').textContent = state.formData.graduationYear ? `Class of ${state.formData.graduationYear}` : '-';
      $('#summary-photos').textContent = String(state.formData.profilePictures.length);
      $('#summary-interests').textContent = state.formData.interests.join(', ') || '-';

      hide($('#nav-buttons'));
    } else {
      show($('#nav-buttons'));
    }

    // Focus first relevant input
    if (step === 2) $('#full-name')?.focus();
    if (step === 6) $('#bio')?.focus();
  }

  // ----------------------------
  // Firebase / EmailJS bootstrap
  // ----------------------------
  function initThirdParty() {
    const { auth, db } = window.FirebaseClient.initFirebase();

    // EmailJS (still used only for email verification step in this demo)
    emailjs.init(EMAILJS_PUBLIC_KEY);

    return { auth, db };
  }

  // ----------------------------
  // Firestore operations
  // ----------------------------
  // NOTE: With Firebase Auth + strict rules, we don't pre-check duplicates before signup.
  // Username uniqueness is enforced by a transaction during account creation.

  async function createProfileAndUsernameIndex(services) {
    const username = window.FirebaseClient.normalizeUsername(state.formData.username);
    if (!username || username.length < 3) throw new Error('Invalid username');

    const data = {
      username,
      usernameLower: username,
      collegeEmail: state.formData.collegeEmail,
      fullName: state.formData.fullName,
      gender: state.formData.gender,
      collegeName: state.formData.collegeName,
      branch: state.formData.branch,
      branchCode: state.formData.branchCode,
      graduationYear: state.formData.graduationYear,
      interests: state.formData.interests,
      bio: state.formData.bio,
      profilePicturesCount: state.formData.profilePictures.length,
      avatarDataUrl: state.formData.profilePictures[0] || '',
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      updatedAt: firebase.firestore.FieldValue.serverTimestamp()
    };

    // Ensure we are authenticated (create account)
    const email = (state.formData.collegeEmail || '').trim().toLowerCase();
    const password = state.formData.password;

    let cred;
    try {
      cred = await services.auth.createUserWithEmailAndPassword(email, password);
    } catch (err) {
      // If the email already exists, surface a helpful message.
      throw new Error(describeFirebaseAuthError(err));
    }

    const uid = cred.user.uid;

    // Create username index and user profile atomically
    const usernameRef = services.db.collection('usernames').doc(username);
    const userRef = services.db.collection('users').doc(uid);

    await services.db.runTransaction(async (tx) => {
      const existing = await tx.get(usernameRef);
      if (existing.exists) {
        throw new Error('Username already taken. Please choose another.');
      }
      tx.set(usernameRef, { uid, createdAt: firebase.firestore.FieldValue.serverTimestamp() });
      tx.set(userRef, data, { merge: true });
    });

    return { uid, profile: data };
  }

  // ----------------------------
  // UI builders
  // ----------------------------
  function renderGenderButtons() {
    const wrap = $('#gender-options');
    if (!wrap) return;

    wrap.replaceChildren();

    GENDER_OPTIONS.forEach(option => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'gender-btn';
      btn.textContent = option;
      btn.addEventListener('click', () => {
        state.formData.gender = option;
        $$('.gender-btn', wrap).forEach(b => b.classList.remove('selected'));
        btn.classList.add('selected');
        updateNavButtons();
      });
      wrap.appendChild(btn);
    });
  }

  function renderInterests() {
    const wrap = $('#interests-wrap');
    if (!wrap) return;

    wrap.replaceChildren();

    function makeChip(label, selected, removable) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = `chip ${selected ? 'chip-selected' : ''}`;
      btn.textContent = label;
      if (removable) btn.classList.add('chip-removable');

      btn.addEventListener('click', () => {
        toggleInterest(label);
      });
      return btn;
    }

    // predefined
    PREDEFINED_INTERESTS.forEach(interest => {
      wrap.appendChild(makeChip(interest, state.formData.interests.includes(interest), false));
    });

    // custom interests
    state.formData.interests
      .filter(i => !PREDEFINED_INTERESTS.includes(i))
      .forEach(interest => {
        wrap.appendChild(makeChip(interest, true, true));
      });
  }

  function toggleInterest(interest) {
    const idx = state.formData.interests.indexOf(interest);
    if (idx >= 0) {
      state.formData.interests.splice(idx, 1);
    } else {
      if (state.formData.interests.length >= 10) return;
      state.formData.interests.push(interest);
    }
    renderInterests();
    updateNavButtons();
  }

  function addCustomInterest() {
    const input = $('#custom-interest');
    if (!input) return;
    const trimmed = input.value.trim();

    if (!trimmed) return;
    if (state.formData.interests.includes(trimmed)) return;
    if (state.formData.interests.length >= 10) return;

    state.formData.interests.push(trimmed);
    input.value = '';
    renderInterests();
    updateNavButtons();
  }

  function renderPhotos() {
    const grid = $('#photos-grid');
    if (!grid) return;

    // Keep "Add" tile if < 6
    grid.replaceChildren();

    state.formData.profilePictures.forEach((src, index) => {
      const tile = document.createElement('div');
      tile.className = 'photo-tile';

      const img = document.createElement('img');
      img.src = src;
      img.alt = `Profile ${index + 1}`;

      const remove = document.createElement('button');
      remove.type = 'button';
      remove.className = 'photo-remove';
      remove.textContent = '×';
      remove.addEventListener('click', () => {
        state.formData.profilePictures.splice(index, 1);
        renderPhotos();
        updateNavButtons();
      });

      tile.appendChild(img);
      tile.appendChild(remove);
      grid.appendChild(tile);
    });

    if (state.formData.profilePictures.length < 6) {
      const add = document.createElement('button');
      add.type = 'button';
      add.className = 'photo-add';
      add.innerHTML = '<span class="photo-add-icon">📷</span><span class="photo-add-text">Add Photo</span>';
      add.addEventListener('click', () => $('#photo-input')?.click());
      grid.appendChild(add);
    }
  }

  // ----------------------------
  // Event wiring
  // ----------------------------
  function wireOtpInputs() {
    const inputs = $$('.otp-input');

    inputs.forEach((input, idx) => {
      input.addEventListener('input', () => {
        input.value = input.value.replace(/\D/g, '').slice(0, 1);
        if (input.value && idx < inputs.length - 1) inputs[idx + 1].focus();
        setError('otp', '');
      });

      input.addEventListener('keydown', (e) => {
        if (e.key === 'Backspace' && !input.value && idx > 0) {
          inputs[idx - 1].focus();
          return;
        }

        // Pressing Enter in OTP fields should verify
        if (e.key === 'Enter') {
          e.preventDefault();
          document.getElementById('btn-verify-otp')?.click();
        }
      });

      input.addEventListener('paste', (e) => {
        e.preventDefault();
        const txt = (e.clipboardData.getData('text') || '').trim().slice(0, 6);
        if (!/^\d+$/.test(txt)) return;
        txt.split('').forEach((d, i) => {
          if (inputs[i]) inputs[i].value = d;
        });
        const next = Math.min(txt.length, inputs.length - 1);
        inputs[next]?.focus();
      });
    });
  }

  function wireEvents(services) {
    // Treat the wizard like a real form: Enter triggers the primary action for the current step.
    const formEl = document.getElementById('registration-form');
    if (formEl) {
      formEl.addEventListener('submit', async (e) => {
        e.preventDefault();

        // Decide primary action by step
        if (state.step === 1) {
          // If OTP not yet sent, send it; otherwise verify
          if (!state.otpSent) {
            document.getElementById('btn-send-otp')?.click();
          } else {
            document.getElementById('btn-verify-otp')?.click();
          }
          return;
        }

        if (state.step >= 2 && state.step <= 6) {
          document.getElementById('btn-continue')?.click();
        }
      });

      // Prevent Enter in the custom-interest field from submitting the whole form.
      const customInterest = document.getElementById('custom-interest');
      customInterest?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          addCustomInterest();
        }
      });
    }

    // Email
    $('#college-email')?.addEventListener('input', (e) => {
      state.formData.collegeEmail = e.target.value.toLowerCase();
      setError('email', '');
    });

    // Send OTP
    $('#btn-send-otp')?.addEventListener('click', async () => {
      if (state.loading) return;

      setError('email', '');
      setError('otp', '');

      const email = (state.formData.collegeEmail || '').trim().toLowerCase();
      if (!email) {
        setError('email', 'Please enter your college email.');
        return;
      }

      const emailData = parseCollegeEmail(email);
      if (!emailData.valid) {
        if (emailData.outOfCampus) {
          setError('email', `Invalid branch code: ${emailData.branchCode}. This appears to be an out-of-campus email.`);
        } else {
          setError('email', 'Please enter a valid college email in format: name.initial.branch.year@college.ac.in');
        }
        return;
      }

      setLoading(true, 'Sending OTP...');

      try {
        // No pre-check here. We'll create the Auth user at the final step and show any errors then.

        const otp = generateOTP();
        state.generatedOtp = otp;

        try {
          await emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, {
            to_email: email,
            // Common EmailJS template fields (harmless if unused)
            to_name: emailData.firstName,
            from_name: 'Campus Connect',
            otp_code: otp,
            user_name: emailData.firstName
          });
        } catch (emailErr) {
          console.error('EmailJS send failed:', emailErr);
          setError('email', `Failed to send OTP via EmailJS: ${describeEmailJsError(emailErr)}`);
          return;
        }

        // Update derived fields
        state.formData.collegeEmail = email;
        state.formData.graduationYear = emailData.year;
        state.formData.collegeName = emailData.college;
        state.formData.branch = emailData.branch;
        state.formData.branchCode = emailData.branchCode;

        // Update UI
        $('#derived-email').textContent = state.formData.collegeEmail;
        $('#derived-college').textContent = state.formData.collegeName;
        $('#derived-branch').textContent = `${state.formData.branch} (${state.formData.branchCode})`;
        $('#derived-year').textContent = `Class of ${state.formData.graduationYear}`;

        setOtpUI(true);
        clearOtpInputs();
        startTimer(120);
      } catch (err) {
        console.error('Error sending OTP:', err);
        setError('email', `Failed to send OTP: ${err?.message || String(err)}`);
      } finally {
        setLoading(false);
        updateNavButtons();
      }
    });

    // Verify OTP
    $('#btn-verify-otp')?.addEventListener('click', () => {
      setError('otp', '');

      if (state.timer <= 0) {
        setError('otp', 'OTP expired. Please resend OTP.');
        return;
      }

      const entered = getOtpValue();
      if (entered.length !== 6) {
        setError('otp', 'Please enter the 6-digit OTP.');
        return;
      }

      if (entered === state.generatedOtp) {
        state.formData.isVerified = true;
        setError('otp', '');
        showStep(2);
      } else {
        state.formData.isVerified = false;
        setError('otp', 'Invalid OTP. Please try again.');
        clearOtpInputs();
      }

      updateNavButtons();
    });

    // Resend OTP
    $('#btn-resend-otp')?.addEventListener('click', async () => {
      if (state.timer > 0 || state.loading) return;

      setError('otp', '');
      const email = (state.formData.collegeEmail || '').trim().toLowerCase();
      const emailData = parseCollegeEmail(email);
      if (!emailData.valid) {
        setError('email', 'Please enter a valid email before resending OTP.');
        return;
      }

      setLoading(true, 'Sending OTP...');

      try {
        const otp = generateOTP();
        state.generatedOtp = otp;

        try {
          await emailjs.send(EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, {
            to_email: email,
            to_name: emailData.firstName,
            from_name: 'Campus Connect',
            otp_code: otp,
            user_name: emailData.firstName
          });
        } catch (emailErr) {
          console.error('EmailJS resend failed:', emailErr);
          setError('otp', `Failed to resend OTP via EmailJS: ${describeEmailJsError(emailErr)}`);
          return;
        }

        clearOtpInputs();
        startTimer(120);
      } catch (err) {
        console.error('Error resending OTP:', err);
        setError('otp', `Failed to resend OTP: ${err?.message || String(err)}`);
      } finally {
        setLoading(false);
        updateNavButtons();
      }
    });

    // Account details
    $('#full-name')?.addEventListener('input', (e) => {
      state.formData.fullName = e.target.value;
      setError('username', '');
      setError('password', '');
      updateNavButtons();
    });

    $('#username')?.addEventListener('input', (e) => {
      const normalized = window.FirebaseClient.normalizeUsername(e.target.value);
      // keep the UI input in sync with allowed characters
      e.target.value = normalized;
      state.formData.username = normalized;
      setError('username', '');
      updateNavButtons();
    });

    $('#password')?.addEventListener('input', (e) => {
      state.formData.password = e.target.value;
      setError('password', '');
      updateNavButtons();
    });

    // Gender buttons are wired in renderGenderButtons()

    // Photos
    $('#photo-input')?.addEventListener('change', (e) => {
      const files = Array.from(e.target.files || []);
      files.forEach(file => {
        if (state.formData.profilePictures.length >= 6) return;
        const reader = new FileReader();
        reader.onloadend = () => {
          state.formData.profilePictures.push(reader.result);
          renderPhotos();
          updateNavButtons();
        };
        reader.readAsDataURL(file);
      });

      // allow selecting same file again
      e.target.value = '';
    });

    // Interests
    $('#btn-add-interest')?.addEventListener('click', addCustomInterest);
    // Bio
    $('#bio')?.addEventListener('input', (e) => {
      const val = (e.target.value || '').slice(0, 500);
      e.target.value = val;
      state.formData.bio = val;
      setText('#bio-count', `${val.length}/500`);
      const needed = Math.max(0, 50 - val.length);
      const hint = $('#bio-hint');
      if (hint) {
        if (needed > 0) {
          hint.textContent = `${needed} more characters needed`;
          hint.classList.remove('hidden');
        } else {
          hint.textContent = '';
          hint.classList.add('hidden');
        }
      }
      updateNavButtons();
    });

    // Nav
    $('#btn-back')?.addEventListener('click', () => {
      if (state.step > 1) showStep(state.step - 1);
    });

    $('#btn-continue')?.addEventListener('click', async () => {
      if (state.loading) return;
      if (!canProceed()) return;

      if (state.step === 6) {
        // Final save of profile (Firebase Auth + /users/{uid})
        setLoading(true, 'Creating account...');
        try {
          const { uid, profile } = await createProfileAndUsernameIndex(services);

          // local cache for navbar/profile page (optional)
          localStorage.setItem('currentUserUid', uid);
          localStorage.setItem('currentUserProfile', JSON.stringify(profile));
          if (profile.avatarDataUrl) localStorage.setItem('currentUserAvatar', profile.avatarDataUrl);

          showStep(7);
        } catch (err) {
          console.error('Error creating account:', err);
          const msg = err?.message || String(err);
          if (String(msg).toLowerCase().includes('username')) {
            setError('username', msg);
            showStep(2);
          } else if (String(msg).toLowerCase().includes('password')) {
            setError('password', msg);
            showStep(2);
          } else {
            alert(msg);
          }
        } finally {
          setLoading(false);
        }
      } else {
        showStep(state.step + 1);
      }
    });

    // Start matching button (website-friendly)
    $('#btn-start-matching')?.addEventListener('click', () => {
      window.location.href = 'index.html';
    });
  }

  function boot() {
    const services = initThirdParty();

    // initial UI setup
    renderGenderButtons();
    renderInterests();
    renderPhotos();

    // OTP inputs
    wireOtpInputs();
    setOtpUI(false);

    // timer tick
    window.setInterval(() => {
      if (state.timer > 0) {
        state.timer -= 1;
        updateTimerUI();
      }
    }, 1000);

    // Start at step 1
    showStep(1);

    // wire events after initial render
    wireEvents(services);

    updateTimerUI();
    updateNavButtons();
  }

  document.addEventListener('DOMContentLoaded', boot);
})();
