import { useEffect, useMemo, useState } from 'react';
import { apiService, resolveMediaUrl } from '../../services/api';
import type { HomePageSettings } from '../../types';

function cloneSettings(x: HomePageSettings): HomePageSettings {
  return JSON.parse(JSON.stringify(x)) as HomePageSettings;
}

const EMPTY: HomePageSettings = {
  hero: {
    eyebrow: 'FRESH FROM THE FARM',
    title: 'Thực phẩm sạch cho',
    highlight: 'cuộc sống xanh',
    subtitle:
      'Mang tinh hoa của đất mẹ đến bàn ăn gia đình bạn. Chúng tôi cam kết 100% hữu cơ,\n              tươi mới và canh tác bền vững.',
    imageUrl: '',
    primaryCtaText: 'Shop Collections',
    primaryCtaHref: '/shop',
    secondaryCtaText: 'View Story',
    secondaryCtaHref: null,
    feature1Title: 'Giao hàng trong 2h',
    feature1Sub: 'Nhanh chóng & tiện lợi',
    feature2Title: 'Đảm bảo ATVSTP',
    feature2Sub: 'Kiểm duyệt nghiêm ngặt',
  },
  roots: {
    subheading: 'OUR ROOTS',
    title: '',
    paragraph1: '',
    paragraph2: '',
    imageUrl: '',
    stat1Value: '100%',
    stat1Label: 'Organic Certified',
    stat2Value: '24h',
    stat2Label: 'Farm to Door',
  },
  seasonal: {
    heading: 'Bộ sưu tập theo mùa',
    subheading: '',
    cards: [
      { title: 'The Spring Greens', imageUrl: '' },
      { title: 'Earthy Roots', imageUrl: '' },
      { title: 'Sun-Kissed Fruits', imageUrl: '' },
    ],
  },
};

export function AdminHomePageSettingsPage() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uploadingKey, setUploadingKey] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [data, setData] = useState<HomePageSettings>(cloneSettings(EMPTY));
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setErr(null);
      try {
        const existing = await apiService.getAdminHomePageSettings();
        const fallback = await apiService.getHomePageSettings();
        const base = existing || fallback || EMPTY;
        if (cancelled) return;
        setData(cloneSettings(base));
        setDirty(false);
      } catch (e) {
        if (!cancelled) setErr(e instanceof Error ? e.message : 'Không tải được thiết lập trang chủ.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const previewHeroImg = useMemo(() => resolveMediaUrl(data.hero.imageUrl || ''), [data.hero.imageUrl]);
  const previewRootsImg = useMemo(() => resolveMediaUrl(data.roots.imageUrl || ''), [data.roots.imageUrl]);

  const setHero = (k: keyof HomePageSettings['hero'], v: string) => {
    setData((x) => ({ ...x, hero: { ...x.hero, [k]: v } }));
    setDirty(true);
  };
  const setRoots = (k: keyof HomePageSettings['roots'], v: string) => {
    setData((x) => ({ ...x, roots: { ...x.roots, [k]: v } }));
    setDirty(true);
  };
  const setSeasonal = (k: keyof HomePageSettings['seasonal'], v: string) => {
    setData((x) => ({ ...x, seasonal: { ...x.seasonal, [k]: v } }));
    setDirty(true);
  };
  const setCard = (idx: number, k: 'title' | 'imageUrl', v: string) => {
    setData((x) => {
      const cards = (x.seasonal.cards || []).slice(0, 3);
      while (cards.length < 3) cards.push({ title: '', imageUrl: '' });
      cards[idx] = { ...cards[idx], [k]: v };
      return { ...x, seasonal: { ...x.seasonal, cards } };
    });
    setDirty(true);
  };

  const onSave = async () => {
    setSaving(true);
    setErr(null);
    try {
      const ok = await apiService.adminUpdateHomePageSettings({
        ...data,
        seasonal: {
          ...data.seasonal,
          cards: (data.seasonal.cards || []).slice(0, 3),
        },
      });
      if (!ok) throw new Error('Lưu thất bại.');
      setDirty(false);
      window.alert('Đã lưu thiết lập trang chủ.');
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Lưu thất bại.');
    } finally {
      setSaving(false);
    }
  };

  const uploadTo = async (key: string, file: File, onUrl: (url: string) => void) => {
    setUploadingKey(key);
    setErr(null);
    try {
      const res = await apiService.adminUploadHomeImage(file);
      if (!res?.imageUrl) throw new Error('Upload thất bại.');
      onUrl(res.imageUrl);
      setDirty(true);
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Upload ảnh thất bại.');
    } finally {
      setUploadingKey(null);
    }
  };

  return (
    <div className="prod-admin">
      <div className="prod-admin-kicker">Admin CMS</div>
      <header className="prod-admin-head">
        <div>
          <h1 className="prod-admin-title">Thiết lập trang chủ</h1>
          <p className="prod-admin-sub muted">Chỉnh sửa 3 section tĩnh: Hero, Our Roots, Seasonal Collections.</p>
        </div>
        <button type="button" className="prod-admin-btn-primary" onClick={onSave} disabled={saving || loading || !dirty}>
          {saving ? 'Đang lưu…' : 'Lưu thay đổi'}
        </button>
      </header>

      {err && <div className="prod-admin-err">{err}</div>}

      {loading ? (
        <div className="prod-admin-td-muted">Đang tải…</div>
      ) : (
        <div className="prod-edit-grid" style={{ gridTemplateColumns: '1fr', gap: '1rem' }}>
          <section className="prod-card">
            <div className="prod-card-title">Hero</div>
            <div className="prod-card-body prod-two-col">
              <div>
                <label className="prod-admin-label">Eyebrow</label>
                <input className="prod-admin-input" value={data.hero.eyebrow} onChange={(e) => setHero('eyebrow', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Ảnh (URL)</label>
                <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                  <input
                    className="prod-admin-input"
                    value={data.hero.imageUrl}
                    onChange={(e) => setHero('imageUrl', e.target.value)}
                    style={{ flex: 1 }}
                  />
                  <label className="prod-admin-btn-ghost" style={{ cursor: 'pointer', whiteSpace: 'nowrap' }}>
                    {uploadingKey === 'hero' ? 'Đang upload…' : 'Upload'}
                    <input
                      type="file"
                      accept="image/*"
                      hidden
                      disabled={uploadingKey != null}
                      onChange={(e) => {
                        const f = e.target.files?.[0];
                        e.target.value = '';
                        if (!f) return;
                        uploadTo('hero', f, (url) => setHero('imageUrl', url));
                      }}
                    />
                  </label>
                </div>
              </div>
              <div>
                <label className="prod-admin-label">Title</label>
                <input className="prod-admin-input" value={data.hero.title} onChange={(e) => setHero('title', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Highlight</label>
                <input className="prod-admin-input" value={data.hero.highlight} onChange={(e) => setHero('highlight', e.target.value)} />
              </div>
              <div className="prod-span-2" style={{ gridColumn: '1 / -1' }}>
                <label className="prod-admin-label">Subtitle</label>
                <textarea className="prod-admin-input prod-admin-textarea" rows={3} value={data.hero.subtitle} onChange={(e) => setHero('subtitle', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">CTA 1 text</label>
                <input className="prod-admin-input" value={data.hero.primaryCtaText} onChange={(e) => setHero('primaryCtaText', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">CTA 1 link</label>
                <input className="prod-admin-input" value={data.hero.primaryCtaHref} onChange={(e) => setHero('primaryCtaHref', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">CTA 2 text</label>
                <input className="prod-admin-input" value={data.hero.secondaryCtaText} onChange={(e) => setHero('secondaryCtaText', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">CTA 2 link (để trống = button)</label>
                <input
                  className="prod-admin-input"
                  value={data.hero.secondaryCtaHref || ''}
                  onChange={(e) => setHero('secondaryCtaHref', e.target.value)}
                />
              </div>
              <div>
                <label className="prod-admin-label">Feature 1 title</label>
                <input className="prod-admin-input" value={data.hero.feature1Title} onChange={(e) => setHero('feature1Title', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Feature 1 sub</label>
                <input className="prod-admin-input" value={data.hero.feature1Sub} onChange={(e) => setHero('feature1Sub', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Feature 2 title</label>
                <input className="prod-admin-input" value={data.hero.feature2Title} onChange={(e) => setHero('feature2Title', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Feature 2 sub</label>
                <input className="prod-admin-input" value={data.hero.feature2Sub} onChange={(e) => setHero('feature2Sub', e.target.value)} />
              </div>

              {data.hero.imageUrl && (
                <div className="prod-span-2" style={{ gridColumn: '1 / -1' }}>
                  <label className="prod-admin-label">Preview ảnh</label>
                  <img src={previewHeroImg} alt="" style={{ width: '100%', maxWidth: 520, borderRadius: 16, border: '1px solid rgba(15,23,42,0.06)' }} />
                </div>
              )}
            </div>
          </section>

          <section className="prod-card">
            <div className="prod-card-title">Our Roots</div>
            <div className="prod-card-body prod-two-col">
              <div>
                <label className="prod-admin-label">Subheading</label>
                <input className="prod-admin-input" value={data.roots.subheading} onChange={(e) => setRoots('subheading', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Ảnh (URL)</label>
                <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                  <input
                    className="prod-admin-input"
                    value={data.roots.imageUrl}
                    onChange={(e) => setRoots('imageUrl', e.target.value)}
                    style={{ flex: 1 }}
                  />
                  <label className="prod-admin-btn-ghost" style={{ cursor: 'pointer', whiteSpace: 'nowrap' }}>
                    {uploadingKey === 'roots' ? 'Đang upload…' : 'Upload'}
                    <input
                      type="file"
                      accept="image/*"
                      hidden
                      disabled={uploadingKey != null}
                      onChange={(e) => {
                        const f = e.target.files?.[0];
                        e.target.value = '';
                        if (!f) return;
                        uploadTo('roots', f, (url) => setRoots('imageUrl', url));
                      }}
                    />
                  </label>
                </div>
              </div>
              <div className="prod-span-2" style={{ gridColumn: '1 / -1' }}>
                <label className="prod-admin-label">Title</label>
                <input className="prod-admin-input" value={data.roots.title} onChange={(e) => setRoots('title', e.target.value)} />
              </div>
              <div className="prod-span-2" style={{ gridColumn: '1 / -1' }}>
                <label className="prod-admin-label">Paragraph 1</label>
                <textarea className="prod-admin-input prod-admin-textarea" rows={3} value={data.roots.paragraph1} onChange={(e) => setRoots('paragraph1', e.target.value)} />
              </div>
              <div className="prod-span-2" style={{ gridColumn: '1 / -1' }}>
                <label className="prod-admin-label">Paragraph 2</label>
                <textarea className="prod-admin-input prod-admin-textarea" rows={3} value={data.roots.paragraph2} onChange={(e) => setRoots('paragraph2', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Stat 1 value</label>
                <input className="prod-admin-input" value={data.roots.stat1Value} onChange={(e) => setRoots('stat1Value', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Stat 1 label</label>
                <input className="prod-admin-input" value={data.roots.stat1Label} onChange={(e) => setRoots('stat1Label', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Stat 2 value</label>
                <input className="prod-admin-input" value={data.roots.stat2Value} onChange={(e) => setRoots('stat2Value', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Stat 2 label</label>
                <input className="prod-admin-input" value={data.roots.stat2Label} onChange={(e) => setRoots('stat2Label', e.target.value)} />
              </div>

              {data.roots.imageUrl && (
                <div className="prod-span-2" style={{ gridColumn: '1 / -1' }}>
                  <label className="prod-admin-label">Preview ảnh</label>
                  <img src={previewRootsImg} alt="" style={{ width: '100%', maxWidth: 520, borderRadius: 16, border: '1px solid rgba(15,23,42,0.06)' }} />
                </div>
              )}
            </div>
          </section>

          <section className="prod-card">
            <div className="prod-card-title">Seasonal Collections</div>
            <div className="prod-card-body prod-two-col">
              <div>
                <label className="prod-admin-label">Heading</label>
                <input className="prod-admin-input" value={data.seasonal.heading} onChange={(e) => setSeasonal('heading', e.target.value)} />
              </div>
              <div>
                <label className="prod-admin-label">Subheading</label>
                <input className="prod-admin-input" value={data.seasonal.subheading} onChange={(e) => setSeasonal('subheading', e.target.value)} />
              </div>

              {[0, 1, 2].map((idx) => (
                <div key={idx} className="prod-span-2" style={{ gridColumn: '1 / -1', borderTop: idx === 0 ? 'none' : '1px solid rgba(15,23,42,0.06)', paddingTop: idx === 0 ? 0 : '1rem' }}>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                    <div>
                      <label className="prod-admin-label">Card {idx + 1} title</label>
                      <input
                        className="prod-admin-input"
                        value={data.seasonal.cards?.[idx]?.title || ''}
                        onChange={(e) => setCard(idx, 'title', e.target.value)}
                      />
                    </div>
                    <div>
                      <label className="prod-admin-label">Card {idx + 1} image (URL)</label>
                      <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                        <input
                          className="prod-admin-input"
                          value={data.seasonal.cards?.[idx]?.imageUrl || ''}
                          onChange={(e) => setCard(idx, 'imageUrl', e.target.value)}
                          style={{ flex: 1 }}
                        />
                        <label className="prod-admin-btn-ghost" style={{ cursor: 'pointer', whiteSpace: 'nowrap' }}>
                          {uploadingKey === `seasonal-${idx}` ? 'Đang upload…' : 'Upload'}
                          <input
                            type="file"
                            accept="image/*"
                            hidden
                            disabled={uploadingKey != null}
                            onChange={(e) => {
                              const f = e.target.files?.[0];
                              e.target.value = '';
                              if (!f) return;
                              uploadTo(`seasonal-${idx}`, f, (url) => setCard(idx, 'imageUrl', url));
                            }}
                          />
                        </label>
                      </div>
                    </div>
                  </div>
                  {!!(data.seasonal.cards?.[idx]?.imageUrl || '').trim() && (
                    <div style={{ marginTop: '0.75rem' }}>
                      <label className="prod-admin-label">Preview ảnh</label>
                      <img
                        src={resolveMediaUrl(data.seasonal.cards?.[idx]?.imageUrl || '')}
                        alt=""
                        style={{ width: '100%', maxWidth: 520, borderRadius: 16, border: '1px solid rgba(15,23,42,0.06)' }}
                      />
                    </div>
                  )}
                </div>
              ))}
            </div>
          </section>
        </div>
      )}
    </div>
  );
}

