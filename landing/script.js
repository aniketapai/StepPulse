// ── NAV SCROLL EFFECT ──
const nav = document.getElementById('nav');
window.addEventListener('scroll', () => {
  nav.classList.toggle('scrolled', window.scrollY > 20);
});

// ── MOBILE MENU ──
const hamburger = document.getElementById('hamburger');
const mobileMenu = document.getElementById('mobileMenu');
hamburger.addEventListener('click', () => {
  mobileMenu.classList.toggle('open');
});
// Close on link click
mobileMenu.querySelectorAll('a').forEach(a => {
  a.addEventListener('click', () => mobileMenu.classList.remove('open'));
});

// ── FAQ ACCORDION ──
function toggleFaq(btn) {
  const answer = btn.nextElementSibling;
  const isOpen = btn.classList.contains('open');

  // Close all
  document.querySelectorAll('.faq-q').forEach(q => {
    q.classList.remove('open');
    q.nextElementSibling.classList.remove('open');
  });

  // Open clicked if it was closed
  if (!isOpen) {
    btn.classList.add('open');
    answer.classList.add('open');
  }
}

// ── HEATMAP GENERATOR ──
function buildHeatmap() {
  const grid = document.querySelector('.heatmap-grid');
  if (!grid) return;

  const colors = [
    '#232B22', // 0 - empty
    '#3A4A38', // 1 - low
    '#4E6B42', // 2 - medium
    '#628141', // 3 - good
    '#8BAE66', // 4 - great
  ];

  const totalCells = 26 * 7; // 26 weeks × 7 days
  const cells = [];

  for (let i = 0; i < totalCells; i++) {
    // Simulate realistic step data with some pattern
    const rand = Math.random();
    let intensity;
    if (rand < 0.12) intensity = 0;
    else if (rand < 0.30) intensity = 1;
    else if (rand < 0.55) intensity = 2;
    else if (rand < 0.78) intensity = 3;
    else intensity = 4;

    // Make last few days look active
    if (i > totalCells - 10) intensity = Math.max(intensity, 3);

    // Sprinkle a gold PR cell
    const isPr = i === totalCells - 22;

    const cell = document.createElement('div');
    cell.className = 'hm-cell';
    cell.style.background = isPr ? '#FFD700' : colors[intensity];
    if (isPr) {
      cell.style.boxShadow = '0 0 6px rgba(255,215,0,0.5)';
      cell.title = '🏆 All-time record!';
    }
    cells.push(cell);
  }

  // Render column by column (week by week)
  for (let week = 0; week < 26; week++) {
    for (let day = 0; day < 7; day++) {
      grid.appendChild(cells[week * 7 + day]);
    }
  }
}

// ── INTERSECTION OBSERVER (fade-up animations) ──
function initAnimations() {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.1, rootMargin: '0px 0px -40px 0px' }
  );

  // Add fade-up to key sections
  const targets = document.querySelectorAll(
    '.feature-card, .stat-item, .step-item, .faq-item'
  );
  targets.forEach((el, i) => {
    el.classList.add('fade-up');
    el.style.transitionDelay = `${(i % 4) * 80}ms`;
    observer.observe(el);
  });
}

// ── XP BAR ANIMATION ──
function animateXpBar() {
  const fill = document.querySelector('.xp-fill');
  if (!fill) return;

  const observer = new IntersectionObserver(entries => {
    if (entries[0].isIntersecting) {
      fill.style.width = '87%';
      observer.disconnect();
    }
  }, { threshold: 0.5 });

  fill.style.width = '0%';
  observer.observe(fill);
}

// ── RING ANIMATION ──
function animateRing() {
  const circle = document.querySelector('.ring-svg circle:last-child');
  if (!circle) return;
  // Already set via SVG attributes; add a CSS transition for entrance
  circle.style.transition = 'stroke-dashoffset 1.2s ease';
}

// ── INIT ──
document.addEventListener('DOMContentLoaded', () => {
  buildHeatmap();
  initAnimations();
  animateXpBar();
  animateRing();
});
