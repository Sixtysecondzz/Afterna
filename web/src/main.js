const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

const year = document.getElementById('year');
if (year) year.textContent = String(new Date().getFullYear());

const nav = document.querySelector('.nav');
let navTicking = false;

const updateNav = () => {
  if (!nav) return;
  nav.classList.toggle('is-solid', window.scrollY > 12);
  navTicking = false;
};

window.addEventListener(
  'scroll',
  () => {
    if (navTicking) return;
    navTicking = true;
    requestAnimationFrame(updateNav);
  },
  { passive: true }
);
updateNav();

const revealNodes = document.querySelectorAll('.reveal');

if (reduceMotion) {
  revealNodes.forEach((el) => el.classList.add('is-in'));
} else {
  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add('is-in');
        io.unobserve(entry.target);
      }
    },
    { threshold: 0.12, rootMargin: '0px 0px -4% 0px' }
  );

  revealNodes.forEach((el) => {
    if (el.closest('.hero')) {
      window.setTimeout(() => el.classList.add('is-in'), 60);
    } else {
      io.observe(el);
    }
  });
}

/* Moments tabs */
const momentsRoot = document.querySelector('[data-moments]');
if (momentsRoot) {
  const tabs = [...momentsRoot.querySelectorAll('[data-moment]')];
  const panels = [...momentsRoot.querySelectorAll('[data-panel]')];

  const activate = (key) => {
    tabs.forEach((tab) => {
      const on = tab.dataset.moment === key;
      tab.classList.toggle('is-active', on);
      tab.setAttribute('aria-selected', on ? 'true' : 'false');
    });
    panels.forEach((panel) => {
      const on = panel.dataset.panel === key;
      panel.classList.toggle('is-active', on);
      panel.hidden = !on;
    });
  };

  tabs.forEach((tab) => {
    tab.addEventListener('click', () => activate(tab.dataset.moment));
  });
}

/* Waitlist */
const form = document.getElementById('waitlist-form');
const note = document.getElementById('form-note');

form?.addEventListener('submit', (event) => {
  event.preventDefault();
  const email = String(new FormData(form).get('email') || '').trim();
  if (!email) return;
  try {
    const key = 'afterna-waitlist';
    const prev = JSON.parse(localStorage.getItem(key) || '[]');
    if (!prev.includes(email)) prev.push(email);
    localStorage.setItem(key, JSON.stringify(prev));
  } catch {
    /* ignore */
  }
  form.reset();
  if (note) note.hidden = false;
});
