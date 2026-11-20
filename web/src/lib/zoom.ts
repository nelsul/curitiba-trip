// Instagram-style zoom on photos (Diário and reels). Touch: pinch with two fingers; the photo grows over
// the page and springs back when the fingers lift. Desktop: Ctrl + wheel (or a trackpad pinch), zooming
// at the pointer; it springs back a moment after you stop.

let lastZoom = 0;
/** True right after a pinch, so lifting the fingers doesn't count as a tap (like, open). */
export const justZoomed = () => Date.now() - lastZoom < 450;

type Overlay = { root: HTMLDivElement; img: HTMLImageElement; rect: DOMRect };

function open(src: HTMLImageElement): Overlay {
	const rect = src.getBoundingClientRect();
	const root = document.createElement('div');
	root.style.cssText = 'position:fixed;inset:0;z-index:200;pointer-events:none;background-color:rgba(0,0,0,0);transition:background-color .2s';
	const img = document.createElement('img');
	img.src = src.currentSrc || src.src;
	img.alt = '';
	const fit = getComputedStyle(src).objectFit || 'cover';
	img.style.cssText = `position:absolute;left:${rect.left}px;top:${rect.top}px;width:${rect.width}px;height:${rect.height}px;object-fit:${fit};transform-origin:0 0;will-change:transform`;
	root.append(img);
	document.body.append(root);
	src.style.visibility = 'hidden';
	return { root, img, rect };
}

function close(o: Overlay, src: HTMLImageElement) {
	o.img.style.transition = 'transform .25s cubic-bezier(.2,.8,.2,1)';
	o.img.style.transform = 'none';
	o.root.style.backgroundColor = 'rgba(0, 0, 0, 0)';
	setTimeout(() => {
		o.root.remove();
		src.style.visibility = '';
	}, 260);
}

/** Use on the element that holds the <img> (the slide); videos and missing images are ignored. */
export function pinchZoom(node: HTMLElement) {
	let o: Overlay | null = null;
	let img: HTMLImageElement | null = null;
	let d0 = 0, mx0 = 0, my0 = 0;
	const dist = (t: TouchList) => Math.hypot(t[0].clientX - t[1].clientX, t[0].clientY - t[1].clientY);
	const mid = (t: TouchList) => [(t[0].clientX + t[1].clientX) / 2, (t[0].clientY + t[1].clientY) / 2];

	function apply(scale: number, mx: number, my: number, ox: number, oy: number) {
		if (!o) return;
		// keep the point under the fingers (ox, oy at the start) under the fingers (mx, my) now
		const x = mx - o.rect.left - (ox - o.rect.left) * scale;
		const y = my - o.rect.top - (oy - o.rect.top) * scale;
		o.img.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
		o.root.style.backgroundColor = `rgba(0, 0, 0, ${Math.min(0.7, (scale - 1) * 0.7).toFixed(2)})`;
	}

	function start(e: TouchEvent) {
		if (e.touches.length !== 2) return;
		img = node.querySelector('img');
		if (!img || !img.complete) return;
		e.preventDefault();
		o = open(img);
		d0 = dist(e.touches);
		[mx0, my0] = mid(e.touches);
	}
	function move(e: TouchEvent) {
		if (!o || e.touches.length !== 2) return;
		e.preventDefault();
		lastZoom = Date.now();
		const [mx, my] = mid(e.touches);
		apply(Math.min(5, Math.max(1, dist(e.touches) / d0)), mx, my, mx0, my0);
	}
	function end(e: TouchEvent) {
		if (!o || e.touches.length >= 2) return;
		lastZoom = Date.now();
		close(o, img!);
		o = null;
	}

	// desktop: Ctrl + wheel / trackpad pinch
	let scale = 1, idle: ReturnType<typeof setTimeout> | undefined, wx = 0, wy = 0;
	function wheel(e: WheelEvent) {
		if (!e.ctrlKey) return;
		const target = node.querySelector('img');
		if (!target) return;
		e.preventDefault();
		if (!o) {
			img = target;
			o = open(target);
			scale = 1;
			wx = e.clientX;
			wy = e.clientY;
		}
		scale = Math.min(5, Math.max(1, scale * Math.exp(-e.deltaY / 100)));
		apply(scale, e.clientX, e.clientY, wx, wy);
		clearTimeout(idle);
		idle = setTimeout(() => {
			if (o) close(o, img!);
			o = null;
		}, 900);
	}

	node.addEventListener('touchstart', start, { passive: false });
	node.addEventListener('touchmove', move, { passive: false });
	node.addEventListener('touchend', end);
	node.addEventListener('touchcancel', end);
	node.addEventListener('wheel', wheel, { passive: false });
	return {
		destroy() {
			node.removeEventListener('touchstart', start);
			node.removeEventListener('touchmove', move);
			node.removeEventListener('touchend', end);
			node.removeEventListener('touchcancel', end);
			node.removeEventListener('wheel', wheel);
			o?.root.remove();
		}
	};
}
