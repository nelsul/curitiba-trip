// A streaming ZIP writer (files stored as they are, no compression: photos and videos don't shrink anyway).
// Each file is streamed straight through with its CRC in a data descriptor, so nothing is held in memory or on
// disk. ZIP64 records are added only when a size or offset passes 4 GB, so ordinary archives open everywhere.

const CRC_TABLE = (() => {
	const t = new Uint32Array(256);
	for (let n = 0; n < 256; n++) {
		let c = n;
		for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
		t[n] = c >>> 0;
	}
	return t;
})();

function crc32(crc: number, data: Uint8Array) {
	let c = ~crc;
	for (let i = 0; i < data.length; i++) c = CRC_TABLE[(c ^ data[i]) & 0xff] ^ (c >>> 8);
	return ~c >>> 0;
}

const MAX32 = 0xffffffff;
/** sizes and offsets from here on need ZIP64 records (the same as MAX32; separate so tests can lower it) */
const LIMIT = MAX32;

class Bytes {
	private buf: number[] = [];
	u16(v: number) {
		this.buf.push(v & 0xff, (v >>> 8) & 0xff);
		return this;
	}
	u32(v: number) {
		this.buf.push(v & 0xff, (v >>> 8) & 0xff, (v >>> 16) & 0xff, (v >>> 24) & 0xff);
		return this;
	}
	u64(v: number) {
		return this.u32(v % 2 ** 32).u32(Math.floor(v / 2 ** 32));
	}
	raw(b: Uint8Array) {
		for (const x of b) this.buf.push(x);
		return this;
	}
	done() {
		return new Uint8Array(this.buf);
	}
}

/** MS-DOS date and time (local fields; ZIP has no time zone). */
function dos(d: Date) {
	const time = (d.getHours() << 11) | (d.getMinutes() << 5) | Math.floor(d.getSeconds() / 2);
	const date = ((Math.max(1980, d.getFullYear()) - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate();
	return { time, date };
}

export type ZipEntry = { name: string; size: number; date: Date; body: () => Promise<AsyncIterable<Uint8Array>> };

/** The archive as a byte stream. `size` must be the file's real length (it decides whether ZIP64 is needed). */
export function zipStream(entries: ZipEntry[]): ReadableStream<Uint8Array> {
	const enc = new TextEncoder();
	const central: { name: Uint8Array; crc: number; size: number; offset: number; time: number; date: number; z64: boolean }[] = [];
	let offset = 0;
	let i = 0;
	let phase: 'files' | 'end' = 'files';

	return new ReadableStream<Uint8Array>({
		async pull(ctrl) {
			const push = (b: Uint8Array) => {
				ctrl.enqueue(b);
				offset += b.length;
			};
			if (phase === 'end') return ctrl.close();
			if (i >= entries.length) {
				phase = 'end';
				const cdStart = offset;
				for (const e of central) {
					const bigOffset = e.offset >= LIMIT;
					const extra = new Bytes();
					if (e.z64) extra.u64(e.size).u64(e.size);
					if (bigOffset) extra.u64(e.offset);
					const x = extra.done();
					const ext = x.length ? new Bytes().u16(0x0001).u16(x.length).raw(x).done() : new Uint8Array();
					push(
						new Bytes()
							.u32(0x02014b50).u16(45).u16(e.z64 || bigOffset ? 45 : 20).u16(0x0808).u16(0)
							.u16(e.time).u16(e.date).u32(e.crc)
							.u32(e.z64 ? MAX32 : e.size).u32(e.z64 ? MAX32 : e.size)
							.u16(e.name.length).u16(ext.length).u16(0).u16(0).u16(0).u32(0)
							.u32(bigOffset ? MAX32 : e.offset)
							.raw(e.name).raw(ext).done()
					);
				}
				const cdSize = offset - cdStart;
				const n = central.length;
				if (n >= 0xffff || cdStart >= LIMIT || cdSize >= LIMIT) {
					const eocd64 = offset;
					push(new Bytes().u32(0x06064b50).u64(44).u16(45).u16(45).u32(0).u32(0).u64(n).u64(n).u64(cdSize).u64(cdStart).done());
					push(new Bytes().u32(0x07064b50).u32(0).u64(eocd64).u32(1).done());
				}
				push(
					new Bytes()
						.u32(0x06054b50).u16(0).u16(0).u16(Math.min(n, 0xffff)).u16(Math.min(n, 0xffff))
						.u32(Math.min(cdSize, MAX32)).u32(Math.min(cdStart, MAX32)).u16(0).done()
				);
				return;
			}

			const e = entries[i++];
			const name = enc.encode(e.name);
			const z64 = e.size >= LIMIT;
			const { time, date } = dos(e.date);
			const start = offset;
			const ext = z64 ? new Bytes().u16(0x0001).u16(16).u64(0).u64(0).done() : new Uint8Array();
			push(
				new Bytes()
					.u32(0x04034b50).u16(z64 ? 45 : 20).u16(0x0808).u16(0).u16(time).u16(date)
					.u32(0).u32(z64 ? MAX32 : 0).u32(z64 ? MAX32 : 0).u16(name.length).u16(ext.length)
					.raw(name).raw(ext).done()
			);
			let crc = 0;
			let size = 0;
			for await (const chunk of await e.body()) {
				crc = crc32(crc, chunk);
				size += chunk.length;
				push(chunk);
			}
			const dd = new Bytes().u32(0x08074b50).u32(crc);
			push((z64 ? dd.u64(size).u64(size) : dd.u32(size).u32(size)).done());
			central.push({ name, crc, size, offset: start, time, date, z64 });
		},
	});
}
