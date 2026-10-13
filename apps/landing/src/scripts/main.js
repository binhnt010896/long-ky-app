// Long Ký landing — progressive enhancement only. The page reads fine
// without this file; it adds the depth rail, the colour wash, scroll-scrubbed
// video and the floating download button.
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
  }

  // --- Scroll-scrubbed video: scroll position IS the playhead ---
  // Nothing plays by itself: scrolling down advances the clip, scrolling up
  // rewinds it, and when scrolling stops the frame holds. The clips are
  // all-keyframe encodes, so any time can be shown instantly. The still image
  // under each video is its first frame, so there is no jump when it loads.
  const clamp01 = (x) => Math.min(1, Math.max(0, x));
  const hero = $('.hero');
  const items = $$('[data-scrub-host]').map((host) => ({
    host,
    isHero: host.dataset.scrubHost === 'hero',
    video: $('video[data-scrub]', host),
    pos: 0,         // smoothed playhead (0..1 of the clip's range)
    shown: -1,      // last time value written to the video
    loaded: false,
  })).filter((it) => it.host);

  // Progress of a host through the screen.
  //  hero:  0 at the top of the page, 1 when the pin releases.
  //  layer: 0 when its top edge reaches the bottom of the screen, 1 when its
  //         bottom edge leaves the top: the clip moves the whole time it is
  //         on screen.
  function progress(it) {
    const r = it.host.getBoundingClientRect(), vh = innerHeight;
    return it.isHero
      ? clamp01(-r.top / Math.max(1, r.height - vh))
      : clamp01((vh - r.top) / (r.height + vh));
  }

  const canScrub = !reduce && !saveData && 'IntersectionObserver' in window;
  let ticking = false;

  function frame() {
    ticking = false;
    let moving = false;
    for (const it of items) {
      const p = progress(it);
      if (it.isHero) document.documentElement.style.setProperty('--hero-p', p.toFixed(3));
      const v = it.video;
      if (!v || !canScrub || !it.loaded) continue;
      it.pos += (p - it.pos) * 0.35;                       // ease toward the target
      if (Math.abs(p - it.pos) < 0.0015) it.pos = p;
      else moving = true;
      const from = +v.dataset.from || 0, to = +v.dataset.to || v.duration;
      const t = from + it.pos * (to - from);
      if (!v.seeking && Math.abs(t - it.shown) > 0.012) { v.currentTime = t; it.shown = t; }
      else if (v.seeking) moving = true;                   // try again next frame
    }
    if (moving) schedule();
  }
  function schedule() { if (!ticking) { ticking = true; requestAnimationFrame(frame); } }

  if (canScrub) {
    // Fetch a clip when its section is within about a screen of the viewport.
    const lio = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        const it = items.find((x) => x.host === e.target);
        const v = it && it.video;
        if (!v || v.src) return;
        v.addEventListener('loadedmetadata', () => { it.loaded = true; it.pos = progress(it); schedule(); }, { once: true });
        v.addEventListener('seeked', () => { v.classList.add('is-ready'); schedule(); });
        v.src = v.dataset.src;
        v.load();
      });
    }, { rootMargin: '100% 0px' });
    items.forEach((it) => it.video && lio.observe(it.host));
  }

  addEventListener('scroll', schedule, { passive: true });
  addEventListener('resize', schedule);
  schedule();
})();
