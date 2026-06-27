/* Shared light/dark theme bootstrap. Runs early to avoid a flash. */
(() => {
  'use strict';
  const KEY = 'inir-web-theme';
  const root = document.documentElement;
  const preferred = window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  const stored = localStorage.getItem(KEY);
  const initial = stored || preferred;
  root.dataset.theme = initial;

  window.InirTheme = {
    current: () => root.dataset.theme || initial,
    toggle: () => {
      const next = root.dataset.theme === 'dark' ? 'light' : 'dark';
      root.dataset.theme = next;
      localStorage.setItem(KEY, next);
      document.querySelectorAll('[data-theme-icon]').forEach(el => { el.textContent = next === 'dark' ? '☀' : '☾'; });
      return next;
    },
    sync: () => {
      const theme = root.dataset.theme || initial;
      document.querySelectorAll('[data-theme-icon]').forEach(el => { el.textContent = theme === 'dark' ? '☀' : '☾'; });
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      window.InirTheme.sync();
      document.querySelectorAll('[data-theme-toggle]').forEach(btn => btn.addEventListener('click', window.InirTheme.toggle));
    }, { once: true });
  } else {
    window.InirTheme.sync();
    document.querySelectorAll('[data-theme-toggle]').forEach(btn => btn.addEventListener('click', window.InirTheme.toggle));
  }
})();
