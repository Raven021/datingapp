export function wordCount(text: string): number {
  const trimmed = text.trim();
  if (!trimmed) return 0;
  return trimmed.split(/\s+/).filter(Boolean).length;
}

export function isValidOpener(text: string): boolean {
  return wordCount(text) >= 2 && text.trim().length <= 1000;
}
