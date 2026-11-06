/** R2 needs every part except the last to have the same size (min 5 MB). */
export const PART_SIZE = 16 * 1024 * 1024;
export const MAX_FILE_BYTES = 20 * 1024 ** 3; // 20 GB
export const MAX_PARTS = Math.ceil(MAX_FILE_BYTES / PART_SIZE);

const VIDEO_EXT = /\.(mov|mp4|m4v|3gp|webm|mkv|avi)$/i;
const PHOTO_EXT = /\.(jpe?g|png|heic|heif|webp|gif|avif|dng|tiff?)$/i;

export function kindOf(name: string, type: string): 'photo' | 'video' | null {
	if (type.startsWith('video/') || VIDEO_EXT.test(name)) return 'video';
	if (type.startsWith('image/') || PHOTO_EXT.test(name)) return 'photo';
	return null;
}
