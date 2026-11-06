import './map-markers.css';
import { initials } from './format';

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

/** Small stable pseudo-random tilt per id, so polaroids look hand-placed but don't jump around. */
export function tiltFor(id: string) {
	let h = 0;
	for (const ch of id) h = (h * 31 + ch.charCodeAt(0)) | 0;
	return ((Math.abs(h) % 9) - 4) * 1.2;
}

/** Teardrop pin. Call replayDrop() to animate a (re)placement. */
export function pinElement(color: string, opts: { href?: string; label?: string } = {}) {
	const root = document.createElement(opts.href ? 'a' : 'div');
	root.className = 'mk-pin-root';
	if (opts.href) (root as HTMLAnchorElement).href = opts.href;
	if (opts.label) root.setAttribute('aria-label', opts.label);
	root.innerHTML = `<span class="mk-shadow"></span><span class="mk-ripple" style="border-color:${color}"></span><span class="mk-pin"><svg viewBox="0 0 40 52" aria-hidden="true"><path d="M20 50s16-15.5 16-28A16 16 0 0 0 4 22c0 12.5 16 28 16 28z" fill="${color}" stroke="#fff" stroke-width="3"/><circle cx="20" cy="21" r="6.5" fill="#fff"/></svg></span>`;
	return root;
}

export function replayDrop(root: HTMLElement, delayMs = 0) {
	root.style.setProperty('--d', `${delayMs}ms`);
	root.classList.remove('dropping');
	void root.offsetWidth; // restart the animation
	root.classList.add('dropping');
}

export function polaroidElement(o: { id: string; href: string; thumb: string | null; color: string; video: boolean; label: string }) {
	const root = document.createElement('a');
	root.className = 'mk-pol-root';
	root.href = o.href;
	root.setAttribute('aria-label', o.label);
	root.innerHTML = `<span class="mk-pol${o.video ? ' video' : ''}" style="--r:${tiltFor(o.id)}deg;--c:${o.color}">${o.thumb ? `<img src="${esc(o.thumb)}" alt="">` : '<span class="mk-pol-empty"></span>'}</span>`;
	return root;
}

export function personElement(o: { name: string; color: string; ago: string; fresh: boolean }) {
	const root = document.createElement('div');
	root.className = `mk-person-root${o.fresh ? ' fresh' : ''}`;
	root.setAttribute('role', 'img');
	root.setAttribute('aria-label', `${o.name}, ${o.ago}`);
	root.innerHTML = `<span class="mk-person"><span class="mk-tag">${esc(o.name)} · ${esc(o.ago)}</span><span class="mk-av" style="background:${o.color}">${esc(initials(o.name))}</span></span>`;
	return root;
}

/** Marks an element to play its entrance animation (pop / drop) after a stagger delay. */
export function animateIn(root: HTMLElement, delayMs: number) {
	root.style.setProperty('--d', `${delayMs}ms`);
	root.classList.add('entering');
	if (root.classList.contains('mk-pin-root')) root.classList.add('dropping');
}
