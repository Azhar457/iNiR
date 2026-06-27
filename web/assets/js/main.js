/* iNiR website — reference-faithful interactions, no dependencies. */
(() => {
  'use strict';

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const nav = document.getElementById('nav');
  const burger = document.getElementById('burger');
  const links = document.getElementById('navlinks');
  const railLinks = [...document.querySelectorAll('.rail__nav a[href^="#"]')];

  const onScroll = () => {
    nav?.classList.toggle('scrolled', window.scrollY > 12);

    let active = railLinks[0];
    for (const link of railLinks) {
      const target = document.querySelector(link.getAttribute('href'));
      if (target && target.getBoundingClientRect().top < window.innerHeight * 0.38) active = link;
    }
    railLinks.forEach(link => link.classList.toggle('active', link === active));
  };
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  const setMenu = (open) => {
    links?.classList.toggle('open', open);
    burger?.classList.toggle('open', open);
    burger?.setAttribute('aria-expanded', open ? 'true' : 'false');
    document.body.classList.toggle('menu-open', open);
  };

  burger?.addEventListener('click', () => setMenu(!links?.classList.contains('open')));
  links?.querySelectorAll('a').forEach(a => a.addEventListener('click', () => setMenu(false)));
  document.addEventListener('keydown', e => { if (e.key === 'Escape') setMenu(false); });

  /* Reveal enhances already-visible content. */
  const reveals = document.querySelectorAll('[data-reveal]');
  if (reduce || !('IntersectionObserver' in window)) {
    reveals.forEach(el => el.classList.add('in'));
  } else {
    const io = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('in');
        io.unobserve(entry.target);
      });
    }, { threshold: 0.14, rootMargin: '0px 0px -7% 0px' });
    reveals.forEach(el => io.observe(el));
  }

  /* Copy quick-start command. */
  const copybtn = document.getElementById('copybtn');
  copybtn?.addEventListener('click', async () => {
    const old = copybtn.textContent;
    try {
      await navigator.clipboard.writeText(copybtn.dataset.copy || '');
      copybtn.textContent = 'Copied ✓';
    } catch (_) {
      copybtn.textContent = 'Ctrl+C';
    }
    setTimeout(() => { copybtn.textContent = old; }, 1500);
  });

  /* Install terminal typing from data-lines. */
  const termbody = document.getElementById('termbody');
  if (termbody) {
    let lines = [];
    try { lines = JSON.parse(termbody.dataset.lines || '[]'); } catch (_) {}

    const renderAll = () => {
      termbody.textContent = lines.map(line => `${line.p || ''}${line.cmd || line.c || line.out || ''}`).join('\n');
    };

    renderAll();
  }
})();
