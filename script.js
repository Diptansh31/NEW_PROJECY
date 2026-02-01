// Smooth scrolling for navigation links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    const href = this.getAttribute('href');
    // Only intercept in-page anchors that exist on this page
    const target = href ? document.querySelector(href) : null;
    if (!target) return;

    e.preventDefault();
    target.scrollIntoView({
      behavior: 'smooth',
      block: 'start'
    });
  });
});

// Heart button toggle
document.querySelectorAll('.heart-btn').forEach(btn => {
  btn.addEventListener('click', function(e) {
    e.preventDefault();
    if (this.textContent === '❤️') {
      this.textContent = '🤍';
    } else {
      this.textContent = '❤️';
    }
    this.style.transform = 'scale(1.3)';
    setTimeout(() => {
      this.style.transform = 'scale(1)';
    }, 200);
  });
});

// Play button functionality for success stories
document.querySelectorAll('.play-btn').forEach(btn => {
  btn.addEventListener('click', function() {
    alert('Video player would open here! 🎥');
  });
});

// Mailing list form submission
const mailingForm = document.querySelector('.mailing-form');
if (mailingForm) {
  mailingForm.addEventListener('submit', function(e) {
    e.preventDefault();
    const emailInput = this.querySelector('.email-input');
    const email = emailInput.value;
    
    if (email && email.includes('@')) {
      alert(`Thank you for subscribing! We'll send updates to ${email} 💕`);
      emailInput.value = '';
    } else {
      alert('Please enter a valid email address.');
    }
  });
}

// Animate elements on scroll
const observerOptions = {
  threshold: 0.1,
  rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.style.opacity = '1';
      entry.target.style.transform = 'translateY(0)';
    }
  });
}, observerOptions);

// Observe elements for animation
document.addEventListener('DOMContentLoaded', () => {
  const animateElements = document.querySelectorAll('.profile-card, .step-card, .story-card');
  
  animateElements.forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(30px)';
    el.style.transition = 'opacity 0.6s ease-out, transform 0.6s ease-out';
    observer.observe(el);
  });
});

// Mobile menu toggle (for future implementation)
const createMobileMenu = () => {
  const navbar = document.querySelector('.navbar');
  const navMenu = document.querySelector('.nav-menu');
  
  if (window.innerWidth <= 768 && !document.querySelector('.mobile-menu-toggle')) {
    const menuToggle = document.createElement('button');
    menuToggle.className = 'mobile-menu-toggle';
    menuToggle.innerHTML = '☰';
    menuToggle.style.cssText = `
      display: block;
      background: none;
      border: none;
      font-size: 1.8rem;
      cursor: pointer;
      color: #d946ef;
    `;
    
    menuToggle.addEventListener('click', () => {
      navMenu.style.display = navMenu.style.display === 'flex' ? 'none' : 'flex';
      navMenu.style.flexDirection = 'column';
      navMenu.style.position = 'absolute';
      navMenu.style.top = '70px';
      navMenu.style.left = '0';
      navMenu.style.right = '0';
      navMenu.style.background = 'white';
      navMenu.style.padding = '20px';
      navMenu.style.boxShadow = '0 5px 20px rgba(0,0,0,0.1)';
    });
    
    navbar.querySelector('.nav-content').insertBefore(menuToggle, navMenu);
  }
};

// Initialize mobile menu on load and resize
window.addEventListener('load', createMobileMenu);
window.addEventListener('resize', createMobileMenu);

// Add hover effect to badges
document.querySelectorAll('.badge').forEach(badge => {
  badge.addEventListener('mouseenter', function() {
    this.style.transform = 'scale(1.1) translateY(-5px)';
  });
  
  badge.addEventListener('mouseleave', function() {
    this.style.transform = 'scale(1) translateY(0)';
  });
});

// Members section filtering/search is handled by homeDiscover.js when logged in.
// (The old demo alert-based filtering was removed.)

// Mobile nav toggle
(function initMobileNavToggle() {
  const navbar = document.querySelector('.navbar');
  const toggle = document.getElementById('nav-toggle');
  const menu = document.getElementById('nav-menu');
  if (!navbar || !toggle || !menu) return;

  toggle.addEventListener('click', () => {
    const open = navbar.classList.toggle('nav-open');
    toggle.setAttribute('aria-expanded', String(open));
    toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
  });

  // Close menu when clicking a link
  menu.querySelectorAll('a').forEach(a => {
    a.addEventListener('click', () => {
      navbar.classList.remove('nav-open');
      toggle.setAttribute('aria-expanded', 'false');
      toggle.setAttribute('aria-label', 'Open menu');
    });
  });

  // Close if clicking outside
  document.addEventListener('click', (e) => {
    if (!navbar.classList.contains('nav-open')) return;
    if (navbar.contains(e.target)) return;
    navbar.classList.remove('nav-open');
    toggle.setAttribute('aria-expanded', 'false');
    toggle.setAttribute('aria-label', 'Open menu');
  });
})();

// Navbar auth UI (Profile avatar + Logout)
(function initNavbarAuth() {
  const loginLink = document.getElementById('nav-login');
  const signupLink = document.getElementById('nav-signup');
  const profileLink = document.getElementById('nav-profile');
  const profileImg = document.getElementById('nav-profile-img');
  const logoutBtn = document.getElementById('nav-logout');

  // If this page doesn't have the navbar ids, do nothing.
  if (!loginLink || !signupLink || !profileLink || !logoutBtn || !profileImg) return;

  // If firebaseClient isn't loaded on this page, fall back to old localStorage behavior.
  if (!window.FirebaseClient) {
    const avatar = localStorage.getItem('currentUserAvatar');
    const uid = localStorage.getItem('currentUserUid');
    const isLoggedIn = !!uid;

    if (isLoggedIn) {
      loginLink.classList.add('hidden');
      signupLink.classList.add('hidden');
      profileLink.classList.remove('hidden');
      logoutBtn.classList.remove('hidden');
      profileImg.src = avatar || 'https://via.placeholder.com/100?text=%F0%9F%91%A4';
    } else {
      loginLink.classList.remove('hidden');
      signupLink.classList.remove('hidden');
      profileLink.classList.add('hidden');
      logoutBtn.classList.add('hidden');
    }

    logoutBtn.addEventListener('click', () => {
      localStorage.removeItem('currentUserUid');
      localStorage.removeItem('currentUserProfile');
      localStorage.removeItem('currentUserAvatar');
      window.location.href = 'index.html';
    });
    return;
  }

  const { auth, db } = window.FirebaseClient.initFirebase();

  auth.onAuthStateChanged(async (user) => {
    const isLoggedIn = !!user;

    if (isLoggedIn) {
      loginLink.classList.add('hidden');
      signupLink.classList.add('hidden');
      profileLink.classList.remove('hidden');
      logoutBtn.classList.remove('hidden');

      try {
        const snap = await db.collection('users').doc(user.uid).get();
        const profile = snap.exists ? snap.data() : null;
        if (profile) {
          localStorage.setItem('currentUserUid', user.uid);
          localStorage.setItem('currentUserProfile', JSON.stringify(profile));
          if (profile.avatarDataUrl) localStorage.setItem('currentUserAvatar', profile.avatarDataUrl);
        }
        const avatar = (profile && profile.avatarDataUrl) || localStorage.getItem('currentUserAvatar');
        profileImg.src = avatar || 'https://via.placeholder.com/100?text=%F0%9F%91%A4';
      } catch (e) {
        const avatar = localStorage.getItem('currentUserAvatar');
        profileImg.src = avatar || 'https://via.placeholder.com/100?text=%F0%9F%91%A4';
      }
    } else {
      loginLink.classList.remove('hidden');
      signupLink.classList.remove('hidden');
      profileLink.classList.add('hidden');
      logoutBtn.classList.add('hidden');
    }
  });

  logoutBtn.addEventListener('click', async () => {
    try {
      await auth.signOut();
    } catch (e) {
      // ignore
    }
    localStorage.removeItem('currentUserUid');
    localStorage.removeItem('currentUserProfile');
    localStorage.removeItem('currentUserAvatar');

    loginLink.classList.remove('hidden');
    signupLink.classList.remove('hidden');
    profileLink.classList.add('hidden');
    logoutBtn.classList.add('hidden');

    window.location.href = 'index.html';
  });
})();

// Console welcome message
console.log('%c💕 Find Your Valentine 💕', 'color: #d946ef; font-size: 24px; font-weight: bold;');
console.log('%cWelcome to the dating app landing page!', 'color: #ec4899; font-size: 14px;');