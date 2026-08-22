export function parseNickname(raw: string): string | null {
  const value = raw.trim().replace(/^@+/, "");
  if (!/^[A-Za-z0-9_]{2,16}$/.test(value)) return null;
  return value;
}

export function displayNickname(raw: string): string {
  return `@${raw.replace(/^@+/, "")}`;
}
