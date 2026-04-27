/* =========================================================
   Drivora — script.js
   Active nav highlight on scroll + smooth UX
   ========================================================= */

(function () {
  'use strict';

  /* ---- Active nav highlight on scroll ---- */
  const navLinks = document.querySelectorAll('.main-nav a[data-section]');
  const sections = Array.from(navLinks).map(link => {
    const id = link.getAttribute('href').slice(1);
    return document.getElementById(id);
  }).filter(Boolean);

  let ticking = false;

  function updateActiveNav() {
    const scrollY = window.scrollY;
    const offset = 120; // header height + buffer

    let currentSection = null;

    sections.forEach(section => {
      const top = section.offsetTop - offset;
      const bottom = top + section.offsetHeight;
      if (scrollY >= top && scrollY < bottom) {
        currentSection = section.id;
      }
    });

    navLinks.forEach(link => {
      const isActive = link.getAttribute('data-section') === currentSection;
      link.classList.toggle('active', isActive);
    });

    ticking = false;
  }

  window.addEventListener('scroll', () => {
    if (!ticking) {
      requestAnimationFrame(updateActiveNav);
      ticking = true;
    }
  }, { passive: true });

  /* ---- Header scrolled class (transparent at top) ---- */
  const header = document.getElementById('site-header');

  function updateHeaderState() {
    header.classList.toggle('scrolled', window.scrollY > 0);
  }
  updateHeaderState(); // run on load
  window.addEventListener('scroll', updateHeaderState, { passive: true });

  /* ---- Smooth scroll for all anchor links ---- */
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const href = this.getAttribute('href');
      if (href === '#') return;
      const target = document.querySelector(href);
      if (!target) return;
      e.preventDefault();
      const headerH = document.getElementById('site-header').offsetHeight;
      const top = target.getBoundingClientRect().top + window.scrollY - headerH;
      window.scrollTo({ top, behavior: 'smooth' });
    });
  });

  /* ---- Intersection Observer for fade-in animations ---- */
  const observerOptions = {
    threshold: 0.12,
    rootMargin: '0px 0px -40px 0px'
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);

  // Observe all cards and sections
  document.querySelectorAll(
    '.feature-card, .problem-card, .audience-card, .sensor-card, ' +
    '.proc-card, .comm-card, .testing-phase, .commercial-card, ' +
    '.team-card, .legend-item, .flow-step, .conclusion-block, ' +
    '.link-card, .inst-link, .app-feature, .stat-item'
  ).forEach((el, i) => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(14px)';
    el.style.transition = 'opacity 0.35s ease, transform 0.35s ease';
    observer.observe(el);
  });

  // Add 'visible' class CSS rule
  const style = document.createElement('style');
  style.textContent = `.visible { opacity: 1 !important; transform: translateY(0) !important; }`;
  document.head.appendChild(style);

  /* ---- Initialize active nav on load ---- */
  updateActiveNav();
})();
