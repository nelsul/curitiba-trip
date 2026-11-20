import { getContext, setContext } from 'svelte';

/** Whether the person looking is a visitor (read-only Diário). Set by the app layout, read by the buttons that act. */
const KEY = Symbol('guest');
export const provideGuest = (get: () => boolean) => setContext(KEY, get);
export const isGuest = () => getContext<(() => boolean) | undefined>(KEY)?.() ?? false;
