// The bell's unread count (top bar), refreshed every minute while the page is visible.

export const unread = $state({ count: 0 });

export async function refreshUnread() {
	if (typeof document !== 'undefined' && document.visibilityState !== 'visible') return;
	try {
		const r = await fetch('/api/notifications?count=1');
		if (r.ok) unread.count = (await r.json()).unread;
	} catch {}
}
