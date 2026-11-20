/**
 * The yellow "Enviar" in the header. While /enviar has photos/videos picked and ready, the page fills `run`
 * and `count`, and the header button sends them instead of just opening /enviar.
 */
export const headerSend = $state<{ count: number; run: (() => void) | null }>({ count: 0, run: null });
