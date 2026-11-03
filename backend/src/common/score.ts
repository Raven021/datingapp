export function likeRate(likes: number, shows: number): number {
  if (shows < 8) return 0.2;
  return (likes + 2) / (shows + 10);
}
