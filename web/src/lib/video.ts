import type { Action } from 'svelte/action';

/**
 * Videos only play while you're looking at them: paused as soon as less than half is on screen
 * (scrolled away, swiped to another carousel slide) or the tab is hidden.
 * With `autoplay`, they also start by themselves when they come into view (the Galeria).
 */
export const visiblePlayback: Action<HTMLVideoElement, { autoplay?: boolean } | undefined> = (video, opts) => {
	let autoplay = opts?.autoplay ?? false;
	let visible = false;

	const play = () => {
		video.play().catch(() => {
			// browsers refuse unmuted autoplay without a tap: try again muted
			if (!video.muted) {
				video.muted = true;
				video.dispatchEvent(new Event('volumechange'));
				video.play().catch(() => {});
			}
		});
	};

	const io = new IntersectionObserver(
		([e]) => {
			visible = e.isIntersecting && e.intersectionRatio >= 0.5;
			if (!visible) video.pause();
			else if (autoplay && document.visibilityState === 'visible') play();
		},
		{ threshold: [0, 0.5, 1] }
	);
	io.observe(video);

	const onVisibility = () => {
		if (document.visibilityState !== 'visible') video.pause();
		else if (visible && autoplay) play();
	};
	document.addEventListener('visibilitychange', onVisibility);

	return {
		update(o) {
			autoplay = o?.autoplay ?? false;
		},
		destroy() {
			io.disconnect();
			document.removeEventListener('visibilitychange', onVisibility);
		}
	};
};
