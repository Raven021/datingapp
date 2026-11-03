export function ageOn(birthDate: Date, today = new Date()): number {
  let age = today.getUTCFullYear() - birthDate.getUTCFullYear();
  const month = today.getUTCMonth() - birthDate.getUTCMonth();
  if (month < 0 || (month === 0 && today.getUTCDate() < birthDate.getUTCDate())) age -= 1;
  return age;
}

export function isAdult(birthDate: Date, today = new Date()): boolean {
  return ageOn(birthDate, today) >= 18;
}
