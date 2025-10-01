export function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[™®]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function canon(s: string): string {
  return s.trim().replace(/\s+/g, " ");
}

export function parsePrice(s?: string) {
  if (!s) return undefined;
  const m = s.replace(/,/g, "").match(/(\$)?(\d+(\.\d+)?)/);
  const amount = m ? Number(m[2]) : undefined;
  const currency = /\$/.test(s) ? "USD" : (s.match(/[A-Z]{3}/)?.[0] ?? "USD");
  return amount ? { amount, currency } : undefined;
}
