/* iNiR docs reader — fetches markdown from ../docs and renders it in-page.
   No build step. Uses marked (CDN) for parsing.
   Features: live search, auto TOC, scroll-spy, copy-code, callouts, prev/next, progress. */
(() => {
  'use strict';

  // The docs live one level up from /web in the repo. When the site is deployed
  // standalone, set DOCS_BASE accordingly (e.g. copy docs/ into web/docs/).
  const DOCS_BASE = '../docs/';

  // Curated nav — grouped, ordered, human labels. Keys are the .md basenames.
  const NAV = [
    { group: 'Start here', items: [
      ['index', 'Overview'],
      ['INSTALL', 'Installation'],
      ['SETUP', 'Setup & updates'],
      ['PACKAGES', 'Packages'],
      ['NIXOS', 'NixOS'],
      ['COMPOSITORS', 'Compositors'],
    ]},
    { group: 'Using iNiR', items: [
      ['PANEL_FAMILIES', 'Panel families'],
      ['KEYBINDS', 'Keybinds'],
      ['GLOBAL_ACTIONS', 'Global actions'],
      ['MODULES', 'Modules'],
      ['NOTIFICATIONS', 'Notifications'],
      ['AUDIO_MEDIA', 'Audio & media'],
      ['CALENDAR', 'Calendar'],
      ['WALLPAPER', 'Wallpaper'],
      ['AUTOSTART', 'Autostart'],
    ]},
    { group: 'Theming', items: [
      ['THEMING_ARCHITECTURE', 'Architecture'],
      ['THEMING_PRESETS', 'Presets'],
      ['THEMING_MODULES', 'Modules'],
      ['THEMING_TARGETS', 'Targets'],
    ]},
    { group: 'Under the hood', items: [
      ['ARCHITECTURE_OVERVIEW', 'Architecture overview'],
      ['CONFIG_SYSTEM', 'Config system'],
      ['SERVICES', 'Services'],
      ['IPC', 'IPC reference'],
      ['RUNTIME', 'Runtime'],
      ['PROJECT_MAP', 'Project map'],
      ['OPTIMIZATION', 'Optimization'],
      ['LIMITATIONS', 'Limitations'],
    ]},
  ];

  // flat ordered list of [key, label] for prev/next + search
  const FLAT = [];
  NAV.forEach(g => g.items.forEach(it => FLAT.push(it)));
  const KEYS = FLAT.map(it => it[0]);
  const LABELS = {};
  FLAT.forEach(([k, l]) => LABELS[k] = l);

  const elNavTree = document.getElementById('docnav-tree');
  const elNav = document.getElementById('docnav');
  const elContent = document.getElementById('content');
  const elCrumb = document.getElementById('crumb-page');
  const elToc = document.getElementById('doctoc');
  const elPager = document.getElementById('docpager');
  const elProgress = document.getElementById('docprogress');
  const elSearch = document.getElementById('docsearch');

  let scrollSpyRaf = null;
  let currentKey = null;

  /* ---- build sidebar nav tree ---- */
  function buildNav(active) {
    elNavTree.innerHTML = NAV.map(g => `
      <div class="docnav__group" data-group="${g.group}">
        <h6>${g.group}</h6>
        ${g.items.map(([k, l]) =>
          `<a href="?p=${k}" data-page="${k}" class="${k === active ? 'active' : ''}">${l}</a>`
        ).join('')}
      </div>`).join('');

    elNavTree.querySelectorAll('a').forEach(a => {
      a.addEventListener('click', (e) => {
        e.preventDefault();
        load(a.dataset.page, true);
        elNav.classList.remove('open');
      });
    });
  }

  /* ---- live search: filter nav by label, hide empty groups ---- */
  if (elSearch) {
    elSearch.addEventListener('input', () => {
      const q = elSearch.value.trim().toLowerCase();
      const groups = elNavTree.querySelectorAll('.docnav__group');
      if (!q) {
        groups.forEach(g => { g.hidden = false; g.querySelectorAll('a').forEach(a => { a.style.display = ''; }); });
        return;
      }
      groups.forEach(g => {
        let any = false;
        g.querySelectorAll('a').forEach(a => {
          const match = a.textContent.toLowerCase().includes(q) || (a.dataset.page || '').toLowerCase().includes(q);
          a.style.display = match ? '' : 'none';
          if (match) any = true;
        });
        g.hidden = !any;
      });
    });
  }

  /* ---- configure marked: rewrite links + images + code blocks ---- */
  function configureMarked() {
    const renderer = new marked.Renderer();
    const baseLink = renderer.link.bind(renderer);
    renderer.link = (href, title, text) => {
      let h = href || '';
      // internal .md links → in-page navigation
      const md = h.match(/^([A-Za-z0-9_./-]+?)\.md(#.*)?$/);
      if (md && !/^https?:/.test(h)) {
        const key = md[1].split('/').pop();
        if (LABELS[key] || key) return `<a href="?p=${key}" data-internal="${key}">${text}</a>`;
      }
      // root README / CHANGELOG references → GitHub
      if (/^\.\.?\/(README|CHANGELOG)/i.test(h) || /^(README|CHANGELOG)/i.test(h)) {
        return `<a href="https://github.com/snowarch/inir/blob/main/${h.replace(/^\.\.?\//, '')}" target="_blank" rel="noopener">${text} ↗</a>`;
      }
      const out = baseLink(h, title, text);
      return /^https?:/.test(h) ? out.replace('<a ', '<a target="_blank" rel="noopener" ') : out;
    };
    const baseImg = renderer.image.bind(renderer);
    renderer.image = (href, title, text) => {
      let h = href || '';
      if (!/^https?:/.test(h)) h = DOCS_BASE + h.replace(/^\.?\//, '');
      return `<img src="${h}" alt="${text || ''}" loading="lazy">`;
    };
    // tag code blocks with language for the label
    const baseCode = renderer.code.bind(renderer);
    renderer.code = (code, lang) => {
      const escaped = (code || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
      const l = lang || '';
      return `<pre data-lang="${l}"><code>${escaped}</code><button class="codecopy" type="button" aria-label="Copy code">Copy</button></pre>`;
    };
    marked.setOptions({ renderer, gfm: true, breaks: false });
  }

  /* ---- delegate internal links rendered inside content ---- */
  elContent.addEventListener('click', (e) => {
    const a = e.target.closest('a[data-internal]');
    if (a) { e.preventDefault(); load(a.dataset.internal, true); return; }
    // copy code button
    const cp = e.target.closest('.codecopy');
    if (cp) {
      e.preventDefault();
      const code = cp.parentElement.querySelector('code');
      if (!code) return;
      navigator.clipboard?.writeText(code.textContent).then(() => {
        const old = cp.textContent;
        cp.textContent = 'Copied ✓';
        cp.style.color = 'var(--lime)';
        cp.style.borderColor = 'var(--lime)';
        setTimeout(() => { cp.textContent = old; cp.style.color = ''; cp.style.borderColor = ''; }, 1400);
      }).catch(() => {});
    }
  });

  /* ---- post-process rendered HTML: callouts, TOC, headings scroll-margin ---- */
  function postProcess() {
    // callouts from blockquotes starting with [!note] / [!warning] / [!tip]
    elContent.querySelectorAll('blockquote').forEach(bq => {
      const first = bq.querySelector('p');
      if (!first) return;
      const txt = first.textContent;
      const m = txt.match(/^\[!(note|warning|tip)\]\s*(.*)$/i);
      if (!m) return;
      const kind = m[1].toLowerCase();
      const title = m[2] || kind;
      first.remove();
      const callout = document.createElement('div');
      callout.className = 'callout callout--' + (kind === 'warning' ? 'warning' : 'note');
      callout.innerHTML = `<span class="callout__title">${title}</span>` + bq.innerHTML;
      bq.replaceWith(callout);
    });

    // build TOC from h2 / h3
    const heads = elContent.querySelectorAll('h2, h3');
    if (heads.length > 0) {
      let html = '<h6>On this page</h6>';
      heads.forEach((h, i) => {
        if (!h.id) h.id = 'sec-' + i;
        const cls = h.tagName === 'H3' ? 'toc-h3' : '';
        html += `<a href="#${h.id}" class="${cls}" data-toc="${h.id}">${h.textContent}</a>`;
      });
      elToc.innerHTML = html;
      elToc.querySelectorAll('a').forEach(a => {
        a.addEventListener('click', (e) => {
          e.preventDefault();
          const t = document.getElementById(a.dataset.toc);
          if (t) t.scrollIntoView({ behavior: 'smooth', block: 'start' });
        });
      });
    } else {
      elToc.innerHTML = '';
    }
  }

  /* ---- scroll-spy: highlight active nav + TOC entry ---- */
  function setupScrollSpy() {
    if (!('IntersectionObserver' in window)) return;
    const navLinks = elNavTree.querySelectorAll('a[data-page]');
    const tocLinks = elToc.querySelectorAll('a[data-toc]');
    const heads = elContent.querySelectorAll('h2, h3');

    // nav active follows current page (already set in buildNav)
    // TOC active follows the heading nearest the top
    if (heads.length === 0) return;
    const tocIO = new IntersectionObserver((entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          tocLinks.forEach(a => a.classList.toggle('active', a.dataset.toc === e.target.id));
        }
      });
    }, { rootMargin: '-80px 0px -70% 0px', threshold: 0 });
    heads.forEach(h => tocIO.observe(h));
  }

  /* ---- reading progress bar ---- */
  function setupProgress() {
    if (!elProgress) return;
    const update = () => {
      const st = window.scrollY;
      const sh = document.documentElement.scrollHeight - window.innerHeight;
      const p = sh > 0 ? (st / sh) * 100 : 0;
      elProgress.style.width = p + '%';
    };
    update();
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update, { passive: true });
  }

  /* ---- prev / next pager ---- */
  function buildPager(key) {
    const idx = KEYS.indexOf(key);
    if (idx < 0) { elPager.innerHTML = ''; return; }
    const prev = idx > 0 ? FLAT[idx - 1] : null;
    const next = idx < FLAT.length - 1 ? FLAT[idx + 1] : null;
    let html = '';
    if (prev) html += `<a class="docpager__a docpager__a--prev" href="?p=${prev[0]}" data-pager="${prev[0]}"><span class="docpager__dir">← Previous</span><span class="docpager__title">${prev[1]}</span></a>`;
    else html += `<span class="docpager__spacer"></span>`;
    if (next) html += `<a class="docpager__a docpager__a--next" href="?p=${next[0]}" data-pager="${next[0]}"><span class="docpager__dir">Next →</span><span class="docpager__title">${next[1]}</span></a>`;
    else html += `<span class="docpager__spacer"></span>`;
    elPager.innerHTML = html;
    elPager.querySelectorAll('a[data-pager]').forEach(a => {
      a.addEventListener('click', (e) => { e.preventDefault(); load(a.dataset.pager, true); });
    });
  }

  /* ---- load a page ---- */
  async function load(page, push) {
    page = page || 'index';
    currentKey = page;
    buildNav(page);
    buildPager(page);
    const q = new URLSearchParams(location.search).get('q');
    if (q && elSearch && !elSearch.value) {
      elSearch.value = q;
      elSearch.dispatchEvent(new Event('input'));
    }
    elCrumb.textContent = (LABELS[page] || page);
    document.title = `${LABELS[page] || page} — iNiR docs`;
    elContent.innerHTML = `<div class="docloading">LOADING ${page} <span class="blink">█</span></div>`;
    elToc.innerHTML = '';
    window.scrollTo({ top: 0, behavior: 'instant' in window ? 'instant' : 'auto' });

    try {
      const res = await fetch(DOCS_BASE + page + '.md', { cache: 'no-cache' });
      if (!res.ok) throw new Error(res.status);
      const text = await res.text();
      // strip leading mkdocs/HTML frontmatter comment blocks if present
      const clean = text.replace(/^---\n[\s\S]*?\n---\n/, '').replace(/^<!--[\s\S]*?-->\n*/, '');
      elContent.innerHTML = marked.parse(clean);
      postProcess();
      setupScrollSpy();
      // re-run progress after content height settles
      requestAnimationFrame(() => { window.dispatchEvent(new Event('scroll')); });
    } catch (err) {
      elContent.innerHTML = `
        <h1>Page not available</h1>
        <p>Couldn't load <code>${page}.md</code>. If you're viewing this site standalone,
        the documentation markdown needs to sit at <code>${DOCS_BASE}</code> relative to this page.</p>
        <p><a href="https://github.com/snowarch/inir/tree/main/docs" target="_blank" rel="noopener">Browse the docs on GitHub ↗</a></p>`;
      elToc.innerHTML = '';
    }

    if (push) history.pushState({ page }, '', `?p=${page}`);
  }

  /* ---- routing ---- */
  function currentPage() {
    return new URLSearchParams(location.search).get('p') || 'index';
  }
  window.addEventListener('popstate', () => load(currentPage(), false));

  document.getElementById('docToggle')?.addEventListener('click', () => {
    elNav.classList.toggle('open');
  });

  /* ---- keyboard: '/' focuses search, Esc clears ---- */
  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && document.activeElement !== elSearch && !/^(input|textarea)$/i.test(document.activeElement?.tagName)) {
      e.preventDefault(); elSearch?.focus();
    } else if (e.key === 'Escape' && document.activeElement === elSearch) {
      elSearch.value = ''; elSearch.dispatchEvent(new Event('input')); elSearch.blur();
    }
  });

  /* ---- boot ---- */
  function boot() {
    if (typeof marked === 'undefined') { setTimeout(boot, 50); return; }
    configureMarked();
    setupProgress();
    load(currentPage(), false);
  }
  boot();
})();
