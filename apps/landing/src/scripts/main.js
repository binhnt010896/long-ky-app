// Long Ký landing — progressive enhancement only. The page reads fine
// without this file; it adds the depth rail, the colour wash, lazy video
// and the floating download button.
(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const saveData = navigator.connection && navigator.connection.saveData;

  // --- Depth rail + colour wash: follow the layer nearest the middle ---
  const sections = $$('[data-layer]');
  const ticks = $$('.rail__tick');
  const yearEl = $('[data-year]');
  const order = ticks.map((t) => t.dataset.period);
  const rgb = (hex) => hex.replace('#', '').match(/../g).map((h) => parseInt(h, 16)).join(', ');

  function activate(el) {
    if (yearEl && el.dataset.year) yearEl.textContent = el.dataset.year;
    if (el.dataset.accent) {
      document.body.style.setProperty('--tint', el.dataset.accent);
      document.body.style.setProperty('--tint-rgb', rgb(el.dataset.accent));
    }
    const idx = order.indexOf(el.dataset.period);
    ticks.forEach((t, i) => {
      t.classList.toggle('is-active', i === idx);
      t.classList.toggle('is-passed', idx >= 0 && i < idx);
    });
  }

  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => { if (e.isIntersecting) activate(e.target); });
    }, { rootMargin: '-45% 0px -45% 0px' });
    sections.forEach((s) => io.observe(s));

    // --- Floating download button: after the hero, away at the finale ---
    const dock = $('[data-dock]');
    const hero = $('.hero');
    const finale = $('.finale');
    if (dock && hero) {
      let heroGone = false, atFinale = false;
      const sync = () => { dock.hidden = !heroGone; dock.classList.toggle('is-away', atFinale); };
      new IntersectionObserver(([e]) => { heroGone = !e.isIntersecting; sync(); }, { threshold: 0.15 }).observe(hero);
      if (finale) new IntersectionObserver(([e]) => { atFinale = e.isIntersecting; sync(); }, { threshold: 0.2 }).observe(finale);
    }

    // --- Video loops: fetch when near, play only while visible ---
    if (!reduce && !saveData) {
      const want = new WeakSet();
      const tryPlay = (v) => { if (want.has(v)) v.play().catch(() => {}); };
      // The clip ends somewhere else than it starts, so it cannot loop by
      // itself. Instead it fades out over the still image below it (which is
      // its first frame), restarts unseen, and fades back in.
      $$('video[data-src]').forEach((v) => {
        v.addEventListener('playing', () => v.classList.add('is-playing'));
        v.addEventListener('canplay', () => tryPlay(v));
        v.addEventListener('timeupdate', () => {
          if (v.duration && v.currentTime > v.duration - 0.9) v.classList.add('is-fading');
        });
        v.addEventListener('ended', () => {
          v.currentTime = 0;
          v.classList.remove('is-fading');
          tryPlay(v);
        });
      });
      document.addEventListener('visibilitychange', () => { if (!document.hidden) $$('video[data-src]').forEach(tryPlay); });
      const vio = new IntersectionObserver((entries) => {
        entries.forEach((e) => {
          const v = e.target;
          if (e.isIntersecting) {
            want.add(v);
            if (!v.src && v.dataset.src) v.src = v.dataset.src;
            tryPlay(v);
          } else {
            want.delete(v);
            v.pause();
          }
        });
      }, { rootMargin: '30% 0px' });
      $$('video[data-src]').forEach((v) => vio.observe(v));
    }
  }
})();
