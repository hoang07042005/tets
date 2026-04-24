import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { BadgeAlert, BadgePercent, Package, ShoppingBag, Users, Wallet } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { apiService, resolveMediaUrl } from '../services/api';
import type { AdminDashboardDto, AdminDashboardKpi, AdminLowStockProduct, AdminRecentImport, AdminRevenuePoint, AdminRecentOrder, AdminReviewRow } from '../types';

type RangeKey = 'week' | 'month';

const IMG_FALLBACK =
  'https://images.pexels.com/photos/616404/pexels-photo-616404.jpeg?auto=compress&cs=tinysrgb&w=160&h=160&dpr=2';

function formatVnd(amount: number) {
  return new Intl.NumberFormat('vi-VN').format(amount) + 'đ';
}

function relativeTimeVi(iso: string) {
  const t = new Date(iso).getTime();
  if (!Number.isFinite(t)) return '';
  const diff = Date.now() - t;
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'vừa xong';
  if (m < 60) return `${m} phút trước`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} giờ trước`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d} ngày trước`;
  return new Date(iso).toLocaleString('vi-VN');
}

export function AdminDashboard() {
  const { user } = useAuth();
  const [range, setRange] = useState<RangeKey>('week');
  const [data, setData] = useState<AdminDashboardDto | null>(null);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [hoverIdx, setHoverIdx] = useState<number | null>(null);
  const [lowStockThreshold, setLowStockThreshold] = useState(10);
  const [lowStock, setLowStock] = useState<AdminLowStockProduct[]>([]);
  const [lowLoading, setLowLoading] = useState(false);
  const [recentImports, setRecentImports] = useState<AdminRecentImport[]>([]);
  const [importsLoading, setImportsLoading] = useState(false);
  const [recentReturns, setRecentReturns] = useState<{ returnRequestID: number; orderID: number; orderToken: string; orderCode: string; userID: number; customerName: string; status: string; requestType: string; reason: string; createdAt: string }[]>([]);
  const [returnsLoading, setReturnsLoading] = useState(false);
  const [recentReviewRows, setRecentReviewRows] = useState<AdminReviewRow[]>([]);
  const [reviewsLoading, setReviewsLoading] = useState(false);
  const [importQty, setImportQty] = useState<Record<number, number>>({});
  const [importNote, setImportNote] = useState<Record<number, string>>({});
  const [importing, setImporting] = useState<Record<number, boolean>>({});

  useEffect(() => {
    let ignore = false;
    setLoading(true);
    setErr(null);
    apiService
      .getAdminDashboard(range)
      .then((d) => {
        if (!ignore) setData(d);
      })
      .catch((e: any) => {
        if (!ignore) setErr(e?.message || 'Không tải được dữ liệu dashboard');
      })
      .finally(() => {
        if (!ignore) setLoading(false);
      });
    return () => {
      ignore = true;
    };
  }, [range]);

  useEffect(() => {
    let ignore = false;
    setLowLoading(true);
    apiService
      .getAdminLowStock({ threshold: lowStockThreshold, take: 10 })
      .then((rows) => {
        if (!ignore) setLowStock(rows || []);
      })
      .catch(() => {
        if (!ignore) setLowStock([]);
      })
      .finally(() => {
        if (!ignore) setLowLoading(false);
      });
    return () => {
      ignore = true;
    };
  }, [lowStockThreshold]);

  useEffect(() => {
    let ignore = false;
    setImportsLoading(true);
    apiService
      .getAdminRecentImports({ take: 6 })
      .then((rows) => {
        if (!ignore) setRecentImports(rows || []);
      })
      .catch(() => {
        if (!ignore) setRecentImports([]);
      })
      .finally(() => {
        if (!ignore) setImportsLoading(false);
      });
    return () => {
      ignore = true;
    };
  }, []);

  useEffect(() => {
    let ignore = false;
    setReturnsLoading(true);
    apiService
      .adminGetRecentReturnRequests(4)
      .then((rows) => {
        if (!ignore) setRecentReturns(Array.isArray(rows) ? rows : []);
      })
      .catch(() => {
        if (!ignore) setRecentReturns([]);
      })
      .finally(() => {
        if (!ignore) setReturnsLoading(false);
      });
    return () => {
      ignore = true;
    };
  }, []);

  useEffect(() => {
    let ignore = false;
    setReviewsLoading(true);
    apiService
      .adminGetReviews({ status: 'pending', take: 4, skip: 0 })
      .then((res: any) => {
        if (!ignore) setRecentReviewRows(Array.isArray(res?.items) ? (res.items as AdminReviewRow[]) : []);
      })
      .catch(() => {
        if (!ignore) setRecentReviewRows([]);
      })
      .finally(() => {
        if (!ignore) setReviewsLoading(false);
      });
    return () => {
      ignore = true;
    };
  }, []);

  const refreshLowStock = async () => {
    setLowLoading(true);
    try {
      const rows = await apiService.getAdminLowStock({ threshold: lowStockThreshold, take: 10 });
      setLowStock(rows || []);
    } catch {
      setLowStock([]);
    } finally {
      setLowLoading(false);
    }
  };

  const refreshRecentImports = async () => {
    setImportsLoading(true);
    try {
      const rows = await apiService.getAdminRecentImports({ take: 6 });
      setRecentImports(rows || []);
    } catch {
      setRecentImports([]);
    } finally {
      setImportsLoading(false);
    }
  };

  const stats = useMemo(() => {
    const kpis: AdminDashboardKpi[] = data?.kpis ?? [];
    const toneFor = (key: string) => {
      if (key === 'revenue') return 'green';
      if (key === 'orders') return 'orange';
      if (key === 'newCustomers') return 'blue';
      if (key === 'stock') return 'red';
      return 'green';
    };
    const iconFor = (key: string) => {
      if (key === 'revenue') return <Wallet size={18} aria-hidden />;
      if (key === 'orders') return <ShoppingBag size={18} aria-hidden />;
      if (key === 'newCustomers') return <Users size={18} aria-hidden />;
      if (key === 'stock') return <Package size={18} aria-hidden />;
      return <Wallet size={18} aria-hidden />;
    };
    const fmtValue = (k: AdminDashboardKpi) => {
      if (k.key === 'revenue') return formatVnd(k.value || 0);
      return new Intl.NumberFormat('vi-VN').format(k.value || 0);
    };
    const fmtDelta = (p: number) => {
      const sign = p > 0 ? '+' : '';
      return `${sign}${p}%`;
    };
    return kpis.map((k) => ({
      tone: toneFor(k.key),
      icon: iconFor(k.key),
      label: k.label,
      delta: fmtDelta(k.deltaPercent || 0),
      value: fmtValue(k),
    }));
  }, [data]);

  const series: AdminRevenuePoint[] = data?.revenueSeries ?? [];
  const orders: AdminRecentOrder[] = data?.recentOrders ?? [];

  const chartLabels = range === 'week' ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'] : ['Tu1', 'Tu2', 'Tu3', 'Tu4'];
  const chartPoints = (series.length ? series : chartLabels.map((l) => ({ label: l, value: 0 }))).map((p) => ({
    label: p.label,
    value: Number(p.value || 0),
  }));

  const chartMax = useMemo(() => {
    const max = Math.max(0, ...chartPoints.map((p) => p.value));
    if (max <= 0) return 1;
    // add headroom so the top line isn't stuck to the ceiling
    return max * 1.12;
  }, [chartPoints]);

  const hoverPoint = hoverIdx == null ? null : chartPoints[hoverIdx] ?? null;

  const smoothPath = (pts: Array<{ x: number; y: number }>, tension = 0.22) => {
    if (pts.length === 0) return '';
    if (pts.length === 1) return `M ${pts[0].x} ${pts[0].y}`;
    const clamp = (v: number, min: number, max: number) => Math.max(min, Math.min(max, v));
    const t = clamp(tension, 0, 1);
    let d = `M ${pts[0].x.toFixed(2)} ${pts[0].y.toFixed(2)}`;
    for (let i = 0; i < pts.length - 1; i++) {
      const p0 = pts[i - 1] ?? pts[i];
      const p1 = pts[i];
      const p2 = pts[i + 1];
      const p3 = pts[i + 2] ?? p2;
      const cp1x = p1.x + ((p2.x - p0.x) / 6) * (1 - t);
      const cp1y = p1.y + ((p2.y - p0.y) / 6) * (1 - t);
      const cp2x = p2.x - ((p3.x - p1.x) / 6) * (1 - t);
      const cp2y = p2.y - ((p3.y - p1.y) / 6) * (1 - t);
      d += ` C ${cp1x.toFixed(2)} ${cp1y.toFixed(2)}, ${cp2x.toFixed(2)} ${cp2y.toFixed(2)}, ${p2.x.toFixed(2)} ${p2.y.toFixed(2)}`;
    }
    return d;
  };

  // Tooltip anchor in CSS coords (% inside viewBox).
  const hoverAnchor = useMemo(() => {
    if (hoverIdx == null) return null;
    const left = 44;
    const right = 18;
    const top = 12;
    const bottom = 34;
    const W = 640;
    const H = 240;
    const innerW = W - left - right;
    const innerH = H - top - bottom;
    const n = chartPoints.length;
    const max = chartMax;
    const min = 0;
    const toX = (i: number) => left + (n <= 1 ? innerW / 2 : (i * innerW) / (n - 1));
    const toY = (v: number) => top + innerH - ((v - min) / (max - min)) * innerH;
    const x = toX(hoverIdx);
    const y = toY(chartPoints[hoverIdx]?.value ?? 0);
    return { xPct: (x / W) * 100, yPct: (y / H) * 100 };
  }, [hoverIdx, chartPoints, chartMax]);

  return (
    <div className="admin-dash">
      <div className="admin-dash-hero">
        <div>
          <h2>Chào buổi sáng, {user?.fullName?.split(' ').slice(-1)[0] || 'Admin'}!</h2>
          <p className="muted">Đây là những gì đang diễn ra tại cửa hàng nông sản của bạn hôm nay.</p>
        </div>
      </div>

      <div className="admin-dash-stats">
        {stats.map((s) => (
          <div key={s.label} className={`admin-kpi ${s.tone}`}>
            <div className="admin-kpi-top">
              <div className="admin-kpi-ico">{s.icon}</div>
              <div className="admin-kpi-delta">
                <span>{s.delta}</span>
              </div>
            </div>
            <div className="admin-kpi-label">{s.label}</div>
            <div className="admin-kpi-value">{s.value}</div>
          </div>
        ))}
      </div>

      <div className="admin-dash-columns">
        <div className="admin-dash-col">
          <div className="admin-panel">
          <div className="admin-panel-head">
            <div>
              <div className="admin-panel-title">Biểu đồ doanh thu</div>
              <div className="admin-panel-sub muted">{range === 'week' ? 'Thống kê 7 ngày gần nhất' : 'Thống kê 30 ngày (theo tuần)'}</div>
            </div>
            <div className="admin-seg">
              <button type="button" className={range === 'week' ? 'active' : ''} onClick={() => setRange('week')}>
                Tuần
              </button>
              <button type="button" className={range === 'month' ? 'active' : ''} onClick={() => setRange('month')}>
                Tháng
              </button>
            </div>
          </div>

          <div className="admin-chart">
            <div className="admin-chart-wrap">
              <svg
                viewBox="0 0 640 240"
                role="img"
                aria-label="Biểu đồ doanh thu"
                onMouseLeave={() => setHoverIdx(null)}
                onMouseMove={(e) => {
                  const svg = e.currentTarget;
                  const rect = svg.getBoundingClientRect();
                  const x = e.clientX - rect.left;
                  const left = 44;
                  const right = 18;
                  const w = rect.width - left - right;
                  if (w <= 0 || chartPoints.length <= 1) return;
                  const t = Math.max(0, Math.min(1, (x - left) / w));
                  const idx = Math.round(t * (chartPoints.length - 1));
                  setHoverIdx(idx);
                }}
              >
                {(() => {
                  const left = 44;
                  const right = 18;
                  const top = 12;
                  const bottom = 34;
                  const W = 640;
                  const H = 240;
                  const innerW = W - left - right;
                  const innerH = H - top - bottom;
                  const n = chartPoints.length;
                  const max = chartMax;
                  const min = 0;
                  const toX = (i: number) => left + (n <= 1 ? innerW / 2 : (i * innerW) / (n - 1));
                  const toY = (v: number) => top + innerH - ((v - min) / (max - min)) * innerH;

                  const pts = chartPoints.map((p, i) => ({ x: toX(i), y: toY(p.value), v: p.value, label: p.label }));
                  const corePts = pts.map((p) => ({ x: p.x, y: p.y }));
                  const line = smoothPath(corePts, 0.18);
                  const area = `${line} L ${(left + innerW).toFixed(2)} ${(top + innerH).toFixed(2)} L ${left.toFixed(2)} ${(top + innerH).toFixed(2)} Z`;

                  const gridLines = 4;
                  const ticks = Array.from({ length: gridLines + 1 }, (_, i) => i);

                  const yTickValue = (i: number) => (max * (gridLines - i)) / gridLines;
                  const formatCompact = (v: number) => {
                    if (v >= 1_000_000_000) return `${(v / 1_000_000_000).toFixed(1)}B`;
                    if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1)}M`;
                    if (v >= 1_000) return `${Math.round(v / 1000)}K`;
                    return `${Math.round(v)}`;
                  };

                  const hi = hoverIdx == null ? -1 : hoverIdx;
                  const hp = hi >= 0 ? pts[hi] : null;

                  return (
                    <>
                      <defs>
                        <linearGradient id="adminChartFill" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="rgba(46,204,113,0.22)" />
                          <stop offset="100%" stopColor="rgba(46,204,113,0.04)" />
                        </linearGradient>
                        <filter id="adminChartGlow" x="-20%" y="-20%" width="140%" height="140%">
                          <feGaussianBlur stdDeviation="2.5" result="blur" />
                          <feMerge>
                            <feMergeNode in="blur" />
                            <feMergeNode in="SourceGraphic" />
                          </feMerge>
                        </filter>
                        <filter id="adminChartSoft" x="-20%" y="-20%" width="140%" height="140%">
                          <feGaussianBlur stdDeviation="10" result="s" />
                          <feColorMatrix
                            in="s"
                            type="matrix"
                            values="0 0 0 0 0.18  0 0 0 0 0.80  0 0 0 0 0.44  0 0 0 0.20 0"
                            result="c"
                          />
                          <feMerge>
                            <feMergeNode in="c" />
                            <feMergeNode in="SourceGraphic" />
                          </feMerge>
                        </filter>
                      </defs>

                      {/* grid + y-axis labels */}
                      {ticks.map((i) => {
                        const y = top + (i * innerH) / gridLines;
                        const val = yTickValue(i);
                        return (
                          <g key={i}>
                            <line x1={left} y1={y} x2={left + innerW} y2={y} stroke="rgba(15, 23, 42, 0.045)" strokeWidth="1" />
                            <text x={left - 10} y={y + 4} textAnchor="end" fontSize="11" fill="rgba(107, 114, 128, 0.85)" fontWeight="800">
                              {formatCompact(val)}
                            </text>
                          </g>
                        );
                      })}

                      {/* baseline axis */}
                      <line x1={left} y1={top + innerH} x2={left + innerW} y2={top + innerH} stroke="rgba(15, 23, 42, 0.10)" strokeWidth="1" />

                      {/* area + line */}
                      <path d={area} fill="url(#adminChartFill)" />
                      <path d={line} fill="none" stroke="rgba(46,204,113,0.95)" strokeWidth="4.5" strokeLinecap="round" strokeLinejoin="round" filter="url(#adminChartSoft)" />

                      {/* points */}
                      {pts.map((p, i) => (
                        <g key={p.label + i}>
                          <circle
                            cx={p.x}
                            cy={p.y}
                            r={i === hi ? 6 : 4}
                            fill={i === hi ? '#ffffff' : 'rgba(46,204,113,0.92)'}
                            stroke="rgba(46,204,113,0.95)"
                            strokeWidth={i === hi ? 3 : 2.25}
                          />
                        </g>
                      ))}

                      {/* hover vertical line */}
                      {hp && (
                        <line
                          x1={hp.x}
                          y1={top}
                          x2={hp.x}
                          y2={top + innerH}
                          stroke="rgba(46,204,113,0.18)"
                          strokeWidth="2.5"
                        />
                      )}
                    </>
                  );
                })()}
              </svg>

              {hoverPoint && (
                <div
                  className="admin-chart-tooltip admin-chart-tooltip--follow"
                  role="status"
                  aria-live="polite"
                  style={
                    hoverAnchor
                      ? ({
                          left: `calc(${hoverAnchor.xPct}% + 10px)`,
                          top: `calc(${hoverAnchor.yPct}% - 12px)`,
                        } as any)
                      : undefined
                  }
                >
                  <div className="admin-chart-tooltip-label">{hoverPoint.label}</div>
                  <div className="admin-chart-tooltip-value">{formatVnd(hoverPoint.value)}</div>
                </div>
              )}
            </div>
            <div className="admin-chart-x">
              {(series.length ? series.map((p) => p.label) : chartLabels).map((l) => (
                <span key={l}>{l}</span>
              ))}
            </div>
          </div>
        </div>

          <div className="admin-panel">
          <div className="admin-panel-head">
            <div>
              <div className="admin-panel-title">Theo dõi tồn kho</div>
              <div className="admin-panel-sub muted">Cảnh báo sản phẩm sắp hết (tồn ≤ ngưỡng)</div>
            </div>
            <div className="admin-stock-controls">
              <span className="muted" style={{ fontWeight: 900 }}>Ngưỡng</span>
              <input
                className="admin-stock-input"
                type="number"
                min={0}
                max={9999}
                value={lowStockThreshold}
                onChange={(e) => setLowStockThreshold(Math.max(0, Math.min(9999, Number(e.target.value || 0))))}
              />
            </div>
          </div>

          <div className="admin-stock-list">
            {lowLoading && <div className="muted" style={{ padding: 12 }}>Đang tải tồn kho...</div>}
            {!lowLoading && lowStock.length === 0 && (
              <div className="admin-stock-empty">
                <div className="admin-stock-empty-ico">
                  <BadgeAlert size={18} aria-hidden />
                </div>
                <div>
                  <div style={{ fontWeight: 950 }}>Không có sản phẩm sắp hết</div>
                  <div className="muted">Tăng ngưỡng nếu bạn muốn xem rộng hơn.</div>
                </div>
              </div>
            )}

            {!lowLoading &&
              lowStock.map((p) => (
                <div key={p.productID} className="admin-stock-item">
                  <div className="admin-stock-thumb">
                    <img
                      src={resolveMediaUrl(p.thumbUrl) || IMG_FALLBACK}
                      alt=""
                      loading="lazy"
                      onError={(e) => {
                        (e.currentTarget as HTMLImageElement).src = IMG_FALLBACK;
                      }}
                    />
                  </div>
                  <div className="admin-stock-main">
                    <div className="admin-stock-name">{p.productName}</div>
                    <div className="admin-stock-sub muted">
                      Giá: {formatVnd(Number(p.discountPrice ?? p.price ?? 0))}{p.unit ? ` / ${p.unit}` : ''}
                    </div>
                    <div className="admin-stock-actions">
                      <input
                        className="admin-stock-input admin-stock-input--small"
                        type="number"
                        min={1}
                        max={999999}
                        placeholder="Nhập thêm"
                        value={importQty[p.productID] ?? ''}
                        onChange={(e) => {
                          const v = Math.max(0, Math.min(999999, Number(e.target.value || 0)));
                          setImportQty((m) => ({ ...m, [p.productID]: v }));
                        }}
                      />
                      <input
                        className="admin-stock-input admin-stock-input--note"
                        type="text"
                        placeholder="Ghi chú (tuỳ chọn)"
                        value={importNote[p.productID] ?? ''}
                        onChange={(e) => setImportNote((m) => ({ ...m, [p.productID]: e.target.value }))}
                      />
                      <button
                        type="button"
                        className="admin-stock-btn"
                        disabled={importing[p.productID] || !(importQty[p.productID] > 0)}
                        onClick={async () => {
                          const qty = importQty[p.productID] ?? 0;
                          if (!qty || qty <= 0) return;
                          setImporting((m) => ({ ...m, [p.productID]: true }));
                          try {
                            await apiService.adminImportStock(p.productID, { quantity: qty, note: importNote[p.productID] ?? '' });
                            setImportQty((m) => ({ ...m, [p.productID]: 0 }));
                            setImportNote((m) => ({ ...m, [p.productID]: '' }));
                            await refreshLowStock();
                            await refreshRecentImports();
                          } catch (e: any) {
                            alert(e?.message || 'Nhập kho thất bại');
                          } finally {
                            setImporting((m) => ({ ...m, [p.productID]: false }));
                          }
                        }}
                      >
                        {importing[p.productID] ? 'Đang nhập…' : 'Nhập'}
                      </button>
                    </div>
                  </div>
                  <div className="admin-stock-right">
                    <div className={`admin-stock-badge ${p.stockQuantity <= Math.max(1, Math.floor(lowStockThreshold * 0.3)) ? 'danger' : 'warn'}`}>
                      Còn {p.stockQuantity}
                    </div>
                    <div className="admin-stock-hint muted">
                      {p.stockQuantity === 0 ? 'Hết hàng' : p.stockQuantity <= Math.max(1, Math.floor(lowStockThreshold * 0.3)) ? 'Rất thấp' : 'Sắp hết'}
                    </div>
                  </div>
                </div>
              ))}
          </div>
        </div>

          <div className="admin-panel">
          <div className="admin-panel-head">
            <div>
              <div className="admin-panel-title">Vừa nhập hàng</div>
              <div className="admin-panel-sub muted">Các sản phẩm mới được cộng tồn kho gần đây</div>
            </div>
          </div>

          <div className="admin-stock-list">
            {importsLoading && <div className="muted" style={{ padding: 12 }}>Đang tải lịch sử nhập...</div>}
            {!importsLoading && recentImports.length === 0 && (
              <div className="admin-stock-empty">
                <div className="admin-stock-empty-ico">
                  <Package size={18} aria-hidden />
                </div>
                <div>
                  <div style={{ fontWeight: 950 }}>Chưa có lần nhập nào gần đây</div>
                  <div className="muted">Khi bạn bấm “Nhập” ở phần tồn kho, dữ liệu sẽ hiện ở đây.</div>
                </div>
              </div>
            )}
            {!importsLoading &&
              recentImports.map((x) => (
                <div key={x.logID} className="admin-stock-item admin-import-item">
                  <div className="admin-stock-thumb">
                    <img
                      src={resolveMediaUrl(x.thumbUrl) || IMG_FALLBACK}
                      alt=""
                      loading="lazy"
                      onError={(e) => {
                        (e.currentTarget as HTMLImageElement).src = IMG_FALLBACK;
                      }}
                    />
                  </div>
                  <div className="admin-stock-main">
                    <div className="admin-stock-name">{x.productName}</div>
                    <div className="admin-stock-sub muted">
                      Nhập thêm: <b>+{x.importedQuantity}</b>
                      {x.unit ? ` ${x.unit}` : ''} · Tồn mới: <b>{x.stockQuantity}</b>
                      {x.unit ? ` ${x.unit}` : ''}
                    </div>
                    {x.note ? <div className="muted" style={{ marginTop: 4 }}>{x.note}</div> : null}
                  </div>
                  <div className="admin-stock-right">
                    <div className="admin-stock-hint muted">{new Date(x.logDate).toLocaleString('vi-VN')}</div>
                  </div>
                </div>
              ))}
          </div>
        </div>
      </div>

        <div className="admin-dash-col">
          <div className="admin-panel">
            <div className="admin-panel-head">
              <div>
                <div className="admin-panel-title">Đơn hàng mới</div>
              </div>
              <Link to="/orders" className="admin-link">
                Xem tất cả
              </Link>
            </div>

            <div className="admin-orders">
              {loading && (
                <div className="muted" style={{ padding: 12 }}>
                  Đang tải dữ liệu...
                </div>
              )}
              {err && (
                <div className="muted" style={{ padding: 12 }}>
                  {err}
                </div>
              )}
              {!loading &&
                !err &&
                orders.map((o) => (
                  <div key={o.orderID} className="admin-order">
                    <div className="admin-order-img">
                      <img
                        src={resolveMediaUrl(o.thumbUrl) || IMG_FALLBACK}
                        alt=""
                        loading="lazy"
                        onError={(e) => {
                          (e.currentTarget as HTMLImageElement).src = IMG_FALLBACK;
                        }}
                      />
                    </div>
                    <div className="admin-order-main">
                      <div className="admin-order-name">{o.orderCode}</div>
                      <div className="admin-order-sub muted">Khách: {o.customerName}</div>
                    </div>
                    <div className="admin-order-right">
                      <div className="admin-order-amt">{formatVnd(o.totalAmount || 0)}</div>
                      {/* <div
                        className={`admin-order-status ${
                          (o.status || '').toLowerCase() === 'delivered' || (o.status || '').toLowerCase() === 'paid'
                            ? 'ok'
                            : (o.status || '').toLowerCase().includes('ship') || (o.status || '').toLowerCase().includes('deliver')
                              ? 'ship'
                              : 'pending'
                        }`}
                      >
                        {o.status}
                      </div> */}
                    </div>
                  </div>
                ))}
            </div>

            <div className="admin-footnote muted">
              <BadgePercent size={16} aria-hidden /> Gợi ý: dùng vouchers để tăng chuyển đổi.
            </div>
          </div>

          <div className="admin-panel">
            <div className="admin-panel-head">
              <div>
                <div className="admin-panel-title">Yêu cầu hoàn hàng / hủy</div>
                <div className="admin-panel-sub muted">4 yêu cầu mới nhất cần xử lý</div>
              </div>
              <Link to="/admin/orders" className="admin-link">
                Xem
              </Link>
            </div>

            <div className="admin-returns-list">
              {returnsLoading && <div className="muted" style={{ padding: 12 }}>Đang tải…</div>}
              {!returnsLoading && recentReturns.length === 0 && <div className="muted" style={{ padding: 12 }}>Chưa có yêu cầu cần xử lý.</div>}
              {!returnsLoading &&
                recentReturns.map((r) => (
                  <div key={r.returnRequestID} className="admin-return-item">
                    <div className="admin-return-top">
                      <div className="admin-return-code">{r.orderCode}</div>
                      <Link to={`/admin/orders/${r.orderToken || r.orderID}`} className="admin-return-action">
                        Xử lý
                      </Link>
                    </div>
                    <div className="admin-return-customer">Khách: <strong>{r.customerName}</strong></div>
                    <div className="admin-return-reason">
                      <span className="muted" style={{ fontWeight: 800 }}>
                        {(r.requestType || '').trim().toLowerCase() === 'cancelrefund' ? 'Hủy đơn — hoàn tiền' : 'Hoàn hàng'}:{' '}
                      </span>
                      “{(r.reason || '').trim() || ((r.requestType || '').trim().toLowerCase() === 'cancelrefund' ? 'Yêu cầu hoàn tiền do hủy đơn' : 'Yêu cầu hoàn hàng')}”
                    </div>
                    <div className="admin-return-time">{relativeTimeVi(r.createdAt)}</div>
                  </div>
                ))}
            </div>
          </div>

          <div className="admin-panel">
            <div className="admin-panel-head">
              <div>
                <div className="admin-panel-title">Reviews mới</div>
                <div className="admin-panel-sub muted">4 đánh giá mới nhất (chờ duyệt)</div>
              </div>
              <Link to="/admin/reviews" className="admin-link">
                Xem
              </Link>
            </div>

            <div className="admin-mini-list">
              {reviewsLoading && <div className="muted" style={{ padding: 12 }}>Đang tải…</div>}
              {!reviewsLoading && recentReviewRows.length === 0 && <div className="muted" style={{ padding: 12 }}>Chưa có review mới.</div>}
              {!reviewsLoading &&
                recentReviewRows.map((rv) => (
                  <div key={rv.reviewID} className="admin-mini-item">
                    <div className="admin-mini-ico" aria-hidden>
                      <span>★</span>
                    </div>
                    <div className="admin-mini-main">
                      <div className="admin-mini-title">{rv.userName}</div>
                      <div className="admin-mini-snippet">“{(rv.comment || '').trim() || `${rv.productName} · ${rv.rating}/5`}”</div>
                      <div className="admin-mini-time">{relativeTimeVi(rv.reviewDate)}</div>
                    </div>
                  </div>
                ))}
            </div>
          </div>

          <div className="admin-panel">
            <div className="admin-panel-head">
              <div>
                <div className="admin-panel-title">Gợi ý hành động</div>
                <div className="admin-panel-sub muted">Nhắc nhanh để không bị thiếu hàng</div>
              </div>
            </div>

            <div className="admin-stock-tips">
              <div className="admin-tip">
                <div className="admin-tip-title">Ưu tiên nhập hàng</div>
                <div className="muted">Các sản phẩm “Rất thấp / Hết hàng” nên được nhập trước để tránh mất doanh thu.</div>
              </div>
              <div className="admin-tip">
                <div className="admin-tip-title">Đẩy khuyến mãi có kiểm soát</div>
                <div className="muted">Không nên áp voucher mạnh cho sản phẩm đang sắp hết để tránh quá tải đơn.</div>
              </div>
              <div className="admin-tip">
                <div className="admin-tip-title">Theo dõi ngưỡng</div>
                <div className="muted">Chỉnh “Ngưỡng” theo từng giai đoạn (mùa cao điểm có thể tăng lên).</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

