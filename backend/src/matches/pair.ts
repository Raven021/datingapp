export function pairIds(a: string, b: string): [string, string] {
  return a < b ? [a, b] : [b, a];
}
