// Smooth scrolling for navigation links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    e.preventDefault();
    const target = document.querySelector(this.getAttribute('href'));
    if (target) {
      target.scrollIntoView({
        behavior: 'smooth',
        block: 'start'
      });
    }
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

// Filter functionality
const filterLocation = document.getElementById('filter-location');
const filterGender = document.getElementById('filter-gender');
const filterInterests = document.getElementById('filter-interests');
const searchBtn = document.querySelector('.btn-search');

if (searchBtn) {
  searchBtn.addEventListener('click', () => {
    const filters = {
      location: filterLocation?.value || 'Any',
      gender: filterGender?.value || 'Any',
      interests: filterInterests?.value || 'Any'
    };
    
    console.log('Searching with filters:', filters);
    
    let message = '🔍 Searching for matches with:\n';
    if (filters.location !== 'Location') message += `📍 Location: ${filters.location}\n`;
    if (filters.gender !== 'Gender') message += `👤 Gender: ${filters.gender}\n`;
    if (filters.interests !== 'Interests') message += `💕 Interest: ${filters.interests}\n`;
    
    alert(message + '\nMatching profiles would appear here!');
  });
}

// Reset filters
document.querySelectorAll('.filter-select').forEach(select => {
  select.addEventListener('change', function() {
    console.log(`Filter changed: ${this.id} = ${this.value}`);
  });
});

// Console welcome message
console.log('%c💕 Find Your Valentine 💕', 'color: #d946ef; font-size: 24px; font-weight: bold;');
console.log('%cWelcome to the dating app landing page!', 'color: #ec4899; font-size: 14px;');
