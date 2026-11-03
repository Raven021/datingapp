const PERSIAN = "۰۱۲۳۴۵۶۷۸۹";
const ARABIC = "٠١٢٣٤٥٦٧٨٩";

export function toAsciiDigits(input: string): string {
  return input.replace(/[۰-۹٠-٩]/g, (char) => {
    const persian = PERSIAN.indexOf(char);
    if (persian >= 0) return String(persian);
    return String(ARABIC.indexOf(char));
  });
}

export function normalizePhone(input: string): string | null {
  let digits = toAsciiDigits(input).replace(/[^\d+]/g, "");
  if (digits.startsWith("+")) digits = digits.slice(1);
  if (digits.startsWith("0098")) digits = digits.slice(4);
  else if (digits.startsWith("98")) digits = digits.slice(2);
  else if (digits.startsWith("0")) digits = digits.slice(1);
  if (!/^9\d{9}$/.test(digits)) return null;
  return `+98${digits}`;
}
