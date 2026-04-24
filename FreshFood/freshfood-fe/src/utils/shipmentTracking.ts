/** Quick partner tracking URLs (GHN/GHTK patterns may change over time). */
export function partnerTrackingUrl(carrier: string | null | undefined, tracking: string | null | undefined): string | null {
  const t = (tracking ?? '').trim();
  if (!t) return null;
  const c = (carrier ?? '').toLowerCase();
  if (c.includes('ghn') || c.includes('giao hàng nhanh')) {
    return `https://donhang.ghn.vn/?order_code=${encodeURIComponent(t)}`;
  }
  if (c.includes('ghtk') || c.includes('giao hàng tiết kiệm')) {
    return `https://i.ghtk.vn/${encodeURIComponent(t)}`;
  }
  return null;
}
