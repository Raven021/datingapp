export const GENDERS = ["woman", "man", "nonbinary"] as const;
export type Gender = (typeof GENDERS)[number];

export function isGender(value: string): value is Gender {
  return (GENDERS as readonly string[]).includes(value);
}
