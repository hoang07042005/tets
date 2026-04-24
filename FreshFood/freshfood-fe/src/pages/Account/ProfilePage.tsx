import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { API_ORIGIN } from '../../services/api';
import { useNavigate, Link } from 'react-router-dom';
import { LogOut, User as UserIcon, Mail, Shield, KeyRound, Save, MapPin, Plus, Pencil, Trash2, Star } from 'lucide-react';
import { apiService } from '../../services/api';
import type { UserAddress } from '../../types';

export const ProfilePage = () => {
  const { user, isAuthenticated, logout, login } = useAuth();
  const navigate = useNavigate();
  const avatarInputRef = useRef<HTMLInputElement | null>(null);
  const [savingProfile, setSavingProfile] = useState(false);
  const [savingPwd, setSavingPwd] = useState(false);
  const [pwdModalOpen, setPwdModalOpen] = useState(false);
  const [profileMsg, setProfileMsg] = useState<string | null>(null);
  const [pwdMsg, setPwdMsg] = useState<string | null>(null);

  const [fullName, setFullName] = useState(user?.fullName || '');
  const [phone, setPhone] = useState(user?.phone || '');
  const [address, setAddress] = useState(user?.address || '');
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string>('');

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [addrList, setAddrList] = useState<UserAddress[]>([]);
  const [addrLoading, setAddrLoading] = useState(false);
  const [addrBusy, setAddrBusy] = useState(false);
  const [addrMsg, setAddrMsg] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<number | 'new' | null>(null);
  const [addrDraft, setAddrDraft] = useState({
    label: '',
    recipientName: '',
    phone: '',
    addressLine: '',
    isDefault: false,
  });

  const userId = user?.userID;
  const loadAddresses = useCallback(async () => {
    if (userId == null) return;
    setAddrLoading(true);
    setAddrMsg(null);
    try {
      const list = await apiService.getUserAddresses(userId);
      setAddrList(list);
    } catch (e) {
      setAddrMsg(e instanceof Error ? e.message : 'Không tải được sổ địa chỉ');
    } finally {
      setAddrLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    if (isAuthenticated && userId != null) void loadAddresses();
  }, [isAuthenticated, userId, loadAddresses]);

  const avatarUrl = useMemo(() => {
    if (!user?.avatarUrl) return '';
    if (/^https?:\/\//i.test(user.avatarUrl)) return user.avatarUrl;
    if (user.avatarUrl.startsWith('/')) return `${API_ORIGIN}${user.avatarUrl}`;
    return `${API_ORIGIN}/${user.avatarUrl}`;
  }, [user?.avatarUrl]);

  const previewUrl = avatarPreview || avatarUrl;
  const memberSince = useMemo(() => {
    const raw: any = user as any;
    const t = raw?.createdAt ?? raw?.CreatedAt ?? raw?.created_at ?? null;
    if (!t) return '';
    const d = new Date(t);
    return Number.isFinite(d.getTime()) ? d.toLocaleDateString('en-US', { month: 'short', year: 'numeric' }) : '';
  }, [user]);

  const nameParts = useMemo(() => {
    const s = (fullName || '').trim().replace(/\s+/g, ' ');
    if (!s) return { first: '', last: '' };
    const parts = s.split(' ');
    if (parts.length === 1) return { first: parts[0], last: '' };
    return { first: parts[0], last: parts.slice(1).join(' ') };
  }, [fullName]);

  const setFirstName = (first: string) => {
    const l = nameParts.last;
    const next = `${first}`.trim();
    setFullName(l ? `${next} ${l}`.trim() : next);
  };

  const setLastName = (last: string) => {
    const f = nameParts.first;
    const next = `${last}`.trim();
    setFullName(f ? `${f} ${next}`.trim() : next);
  };

  const discardChanges = () => {
    setProfileMsg(null);
    setPwdMsg(null);
    setAddrMsg(null);
    setFullName(user?.fullName || '');
    setPhone(user?.phone || '');
    setAddress(user?.address || '');
    if (avatarPreview) URL.revokeObjectURL(avatarPreview);
    setAvatarFile(null);
    setAvatarPreview('');
  };

  const submitPasswordChange = async () => {
    setPwdMsg(null);
    if (!currentPassword || !newPassword) {
      setPwdMsg('Vui lòng nhập đầy đủ mật khẩu.');
      return;
    }
    if (newPassword.length < 6) {
      setPwdMsg('Mật khẩu mới phải từ 6 ký tự.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setPwdMsg('Xác nhận mật khẩu không khớp.');
      return;
    }
    setSavingPwd(true);
    try {
      await apiService.changePassword({ userID: user!.userID, currentPassword, newPassword });
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setPwdMsg('Đổi mật khẩu thành công.');
      setPwdModalOpen(false);
    } catch (e) {
      setPwdMsg(e instanceof Error ? e.message : 'Đổi mật khẩu thất bại.');
    } finally {
      setSavingPwd(false);
    }
  };

  useEffect(() => {
    if (!pwdModalOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPwdModalOpen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [pwdModalOpen]);

  if (!isAuthenticated || !user) {
    return (
      <div className="empty-state" style={{padding: '5rem 2rem', textAlign: 'center'}}>
        <h2>Bạn chưa đăng nhập</h2>
        <p>Vui lòng đăng nhập để xem hồ sơ.</p>
        <Link to="/login" className="btn-primary" style={{display: 'inline-block', marginTop: '1.5rem', textDecoration: 'none'}}>
          Đăng nhập
        </Link>
      </div>
    );
  }

  return (
    <div className="profile-page profile-page--v2">
      <div className="container">
        <div className="profile-v2-grid">
          <aside className="profile-v2-left">
            <section className="profile-v2-card profile-v2-usercard">
              <div
                className="profile-v2-avatar"
                onClick={() => avatarInputRef.current?.click()}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    avatarInputRef.current?.click();
                  }
                }}
                role="button"
                tabIndex={0}
                aria-label="Chọn ảnh đại diện"
                title="Bấm để chọn ảnh đại diện"
              >
                {previewUrl ? <img src={previewUrl} alt={user.fullName} /> : (user.fullName?.[0] || 'U').toUpperCase()}
              </div>
              <div className="profile-v2-name">{user.fullName}</div>
              {memberSince ? <div className="profile-v2-sub muted">Member since {memberSince}</div> : null}
              <div className="profile-v2-userlines">
                {/* <div className="profile-v2-line muted">
                  <Mail size={16} />
                  <span>{user.email}</span>
                </div> */}
                {/* <div className="profile-v2-line muted">
                  <Shield size={16} />
                  <span>{user.role}</span>
                </div> */}
              </div>

              <input
                ref={avatarInputRef}
                className="avatar-file-input"
                type="file"
                accept="image/png,image/jpeg,image/webp"
                onChange={(e) => {
                  const f = e.target.files?.[0] || null;
                  setAvatarFile(f);
                  setProfileMsg(null);
                  if (avatarPreview) URL.revokeObjectURL(avatarPreview);
                  setAvatarPreview(f ? URL.createObjectURL(f) : '');
                }}
              />

              <div className="profile-v2-avatar-uploader">
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => avatarInputRef.current?.click()}
                  style={{ height: 40, padding: '0 0.95rem', fontWeight: 900 }}
                >
                  Chọn ảnh
                </button>
                <div className="profile-v2-avatar-meta">
                  <div className="profile-v2-avatar-fn">{avatarFile ? avatarFile.name : 'Chưa chọn ảnh mới'}</div>
                  <div className="muted" style={{ fontWeight: 700, fontSize: '0.85rem' }}>
                    JPG/PNG/WebP · tối đa 3MB
                  </div>
                </div>
              </div>

            </section>

            <section className="profile-v2-card profile-v2-reward">
              <div className="profile-v2-reward-badge">
                <KeyRound size={16} />
                <span>BẢO MẬT</span>
              </div>
              <div className="profile-v2-reward-title">ĐỔI MẬT KHẨU</div>
              <div className="profile-v2-reward-copy muted">
                Cập nhật mật khẩu để tăng cường bảo mật cho tài khoản của bạn.
              </div>
              <button
                type="button"
                className="profile-v2-reward-btn"
                onClick={() => {
                  setPwdMsg(null);
                  setPwdModalOpen(true);
                }}
              >
                Đổi mật khẩu
              </button>
            </section>

            <button
              type="button"
              className="btn-login profile-v2-logout-btn profile-v2-logout-btn--desktop"
              onClick={() => {
                logout();
                navigate('/');
              }}
              style={{
                marginTop: '1rem',
                width: '100%',
                justifyContent: 'center',
                gap: '0.5rem',
                textDecoration: 'none',
              }}
            >
              <LogOut size={18} /> Đăng xuất
            </button>
          </aside>

          <main className="profile-v2-right">
            <section className="profile-v2-card profile-v2-formcard">
              <div className="profile-v2-form-head">
                <h2>Thông tin liên hệ</h2>
                {profileMsg ? <div className="profile-msg">{profileMsg}</div> : null}
              </div>

              <div className="profile-v2-form">
                <div className="profile-v2-field">
                  <div className="profile-v2-label">First Name</div>
                  <input value={nameParts.first} onChange={(e) => setFirstName(e.target.value)} placeholder="First name" />
                </div>
                <div className="profile-v2-field">
                  <div className="profile-v2-label">Last Name</div>
                  <input value={nameParts.last} onChange={(e) => setLastName(e.target.value)} placeholder="Last name" />
                </div>
                <div className="profile-v2-field profile-v2-field--full">
                  <div className="profile-v2-label">Email Address</div>
                  <input value={user.email || ''} disabled />
                </div>
                <div className="profile-v2-field profile-v2-field--full">
                  <div className="profile-v2-label">Phone Number</div>
                  <input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="Phone number" />
                </div>
              </div>

              <div className="profile-v2-footer" style={{ justifyContent: 'flex-end' }}>
                <button
                  type="button"
                  className="profile-v2-savebtn"
                  disabled={savingProfile}
                  onClick={async () => {
                    setProfileMsg(null);
                    if (!fullName.trim()) {
                      setProfileMsg('Vui lòng nhập họ và tên.');
                      return;
                    }
                    setSavingProfile(true);
                    try {
                      const alsoUploadAvatar = !!avatarFile;
                      if (avatarFile) {
                        await apiService.uploadAvatar(user.userID, avatarFile);
                      }
                      await apiService.updateProfile(user.userID, {
                        fullName: fullName.trim(),
                        phone: phone?.trim() || undefined,
                        address: address?.trim() || undefined,
                      });
                      const fresh = await apiService.getAccountUser(user.userID);
                      login(fresh);
                      if (avatarPreview) URL.revokeObjectURL(avatarPreview);
                      setAvatarFile(null);
                      setAvatarPreview('');
                      setProfileMsg(alsoUploadAvatar ? 'Đã lưu thông tin và avatar.' : 'Đã lưu thông tin tài khoản.');
                    } catch (e) {
                      setProfileMsg(e instanceof Error ? e.message : 'Cập nhật thất bại.');
                    } finally {
                      setSavingProfile(false);
                    }
                  }}
                >
                  {savingProfile ? 'Đang lưu...' : 'Lưu thông tin liên lạc'}
                </button>
              </div>

              <div className="profile-v2-divider" />

              <div className="profile-v2-section-row">
                <h3 className="profile-v2-section-title" style={{ margin: 0 }}>Sổ địa chỉ giao hàng</h3>
                {editingId == null ? (
                  <button
                    type="button"
                    className="btn-primary"
                    style={{ height: 44, padding: '0 1.1rem', borderRadius: 14, fontWeight: 950 }}
                    disabled={addrBusy}
                    onClick={() => {
                      if (!user) return;
                      setAddrMsg(null);
                      setEditingId('new');
                      setAddrDraft({
                        label: '',
                        recipientName: user.fullName || '',
                        phone: user.phone || '',
                        addressLine: user.address || '',
                        isDefault: addrList.length === 0,
                      });
                    }}
                  >
                    <Plus size={18} /> 
                  </button>
                ) : null}
              </div>
              <p className="muted" style={{ margin: '-0.35rem 0 0.9rem', fontSize: '0.9rem', lineHeight: 1.5 }}>
                Lưu nhiều địa chỉ, đặt mặc định — khi thanh toán bạn có thể chọn nhanh địa chỉ đã lưu.
              </p>
              {addrMsg && <div className="profile-msg">{addrMsg}</div>}

              {addrLoading ? (
                <p className="muted" style={{ margin: 0 }}>Đang tải...</p>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.65rem' }}>
                  {addrList.map((a) => (
                    <div
                      key={a.userAddressID}
                      style={{
                        display: 'flex',
                        flexWrap: 'wrap',
                        gap: '0.65rem',
                        alignItems: 'flex-start',
                        justifyContent: 'space-between',
                        padding: '0.75rem 0.85rem',
                        borderRadius: 14,
                        border: '1px solid rgba(15, 23, 42, 0.08)',
                        background: '#fafafa',
                      }}
                    >
                      <div style={{ flex: '1 1 220px', minWidth: 0 }}>
                        <div style={{ fontWeight: 950, color: '#111827' }}>
                          {(a.label || 'Địa chỉ').trim()}
                          {a.isDefault ? (
                            <span style={{ marginLeft: '0.35rem', color: 'var(--primary-dark)', fontSize: '0.82rem' }}>
                              · Mặc định
                            </span>
                          ) : null}
                        </div>
                        <div style={{ fontSize: '0.9rem', color: '#4b5563', marginTop: '0.25rem', lineHeight: 1.45 }}>
                          {a.recipientName}
                          {a.phone ? ` · ${a.phone}` : ''}
                        </div>
                        <div style={{ fontSize: '0.88rem', color: '#6b7280', marginTop: '0.2rem' }}>{a.addressLine}</div>
                      </div>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem' }}>
                        {!a.isDefault ? (
                          <button
                            type="button"
                            className="btn-secondary"
                            style={{ height: 38, padding: '0 0.75rem', fontSize: '0.85rem', fontWeight: 800 }}
                            disabled={addrBusy}
                            onClick={async () => {
                              if (!user) return;
                              setAddrBusy(true);
                              setAddrMsg(null);
                              try {
                                await apiService.setDefaultUserAddress(a.userAddressID, user.userID);
                                await loadAddresses();
                              } catch (e) {
                                setAddrMsg(e instanceof Error ? e.message : 'Thao tác thất bại');
                              } finally {
                                setAddrBusy(false);
                              }
                            }}
                          >
                            <Star size={15} style={{ marginRight: 4 }} /> Mặc định
                          </button>
                        ) : null}
                        <button
                          type="button"
                          className="btn-secondary"
                          style={{ height: 38, padding: '0 0.75rem', fontSize: '0.85rem', fontWeight: 800 }}
                          disabled={addrBusy}
                          onClick={() => {
                            setAddrMsg(null);
                            setEditingId(a.userAddressID);
                            setAddrDraft({
                              label: a.label || '',
                              recipientName: a.recipientName,
                              phone: a.phone || '',
                              addressLine: a.addressLine,
                              isDefault: a.isDefault,
                            });
                          }}
                        >
                          <Pencil size={15} style={{ marginRight: 4 }} /> Sửa
                        </button>
                        <button
                          type="button"
                          className="btn-secondary"
                          style={{ height: 38, padding: '0 0.75rem', fontSize: '0.85rem', fontWeight: 800, color: '#b91c1c' }}
                          disabled={addrBusy}
                          onClick={async () => {
                            if (!user || !confirm('Xóa địa chỉ này?')) return;
                            setAddrBusy(true);
                            setAddrMsg(null);
                            try {
                              await apiService.deleteUserAddress(a.userAddressID, user.userID);
                              if (editingId === a.userAddressID) setEditingId(null);
                              await loadAddresses();
                            } catch (e) {
                              setAddrMsg(e instanceof Error ? e.message : 'Xóa thất bại');
                            } finally {
                              setAddrBusy(false);
                            }
                          }}
                        >
                          <Trash2 size={15} style={{ marginRight: 4 }} /> Xóa
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {editingId != null ? (
                <div style={{ marginTop: '1rem', paddingTop: '1rem', borderTop: '1px solid rgba(15,23,42,0.08)' }}>
                  <div className="form-grid">
                    <label className="field">
                      <span>Nhãn (tùy chọn)</span>
                      <input
                        value={addrDraft.label}
                        onChange={(e) => setAddrDraft((d) => ({ ...d, label: e.target.value }))}
                        placeholder="Nhà, Công ty..."
                      />
                    </label>
                    <label className="field">
                      <span>Người nhận</span>
                      <input
                        value={addrDraft.recipientName}
                        onChange={(e) => setAddrDraft((d) => ({ ...d, recipientName: e.target.value }))}
                        placeholder="Họ và tên"
                      />
                    </label>
                    <label className="field">
                      <span>Số điện thoại</span>
                      <input
                        value={addrDraft.phone}
                        onChange={(e) => setAddrDraft((d) => ({ ...d, phone: e.target.value }))}
                        placeholder="VD: 09xxxxxxxx"
                      />
                    </label>
                    <label className="field full">
                      <span>Địa chỉ chi tiết</span>
                      <input
                        value={addrDraft.addressLine}
                        onChange={(e) => setAddrDraft((d) => ({ ...d, addressLine: e.target.value }))}
                        placeholder="Số nhà, đường, phường..."
                      />
                    </label>
                    <label className="field full" style={{ flexDirection: 'row', alignItems: 'center', gap: '0.5rem' }}>
                      <input
                        type="checkbox"
                        checked={addrDraft.isDefault}
                        onChange={(e) => setAddrDraft((d) => ({ ...d, isDefault: e.target.checked }))}
                      />
                      <span>Đặt làm địa chỉ mặc định</span>
                    </label>
                  </div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginTop: '0.75rem' }}>
                    <button
                      type="button"
                      className="btn-primary profile-save"
                      style={{ marginTop: 0, flex: '1 1 160px' }}
                      disabled={addrBusy}
                      onClick={async () => {
                        if (!user) return;
                        const name = addrDraft.recipientName.trim();
                        const line = addrDraft.addressLine.trim();
                        if (!name || !line) {
                          setAddrMsg('Vui lòng nhập người nhận và địa chỉ chi tiết.');
                          return;
                        }
                        setAddrBusy(true);
                        setAddrMsg(null);
                        try {
                          if (editingId === 'new') {
                            await apiService.createUserAddress(user.userID, {
                              recipientName: name,
                              phone: addrDraft.phone.trim() || undefined,
                              addressLine: line,
                              label: addrDraft.label.trim() || undefined,
                              isDefault: addrDraft.isDefault,
                            });
                          } else if (typeof editingId === 'number') {
                            await apiService.updateUserAddress(editingId, user.userID, {
                              recipientName: name,
                              phone: addrDraft.phone.trim() || undefined,
                              addressLine: line,
                              label: addrDraft.label.trim() || undefined,
                              isDefault: addrDraft.isDefault,
                            });
                          }
                          await loadAddresses();
                          const fresh = await apiService.getAccountUser(user.userID);
                          login(fresh);
                          setEditingId(null);
                        } catch (e) {
                          setAddrMsg(e instanceof Error ? e.message : 'Lưu thất bại');
                        } finally {
                          setAddrBusy(false);
                        }
                      }}
                    >
                      <Save size={18} /> {addrBusy ? 'Đang lưu...' : 'Lưu địa chỉ'}
                    </button>
                    <button
                      type="button"
                      className="btn-secondary profile-save"
                      style={{ marginTop: 0, flex: '0 0 auto', width: 'auto', minWidth: 120 }}
                      disabled={addrBusy}
                      onClick={() => {
                        setEditingId(null);
                        setAddrMsg(null);
                      }}
                    >
                      Hủy
                    </button>
                  </div>
                </div>
              ) : null}

              {/* Sổ địa chỉ giao hàng tự lưu riêng theo từng thao tác */}
            </section>

            {pwdModalOpen ? (
              <div
                className="profile-modal-overlay"
                role="dialog"
                aria-modal="true"
                aria-label="Đổi mật khẩu"
                onMouseDown={(e) => {
                  if (e.target === e.currentTarget) setPwdModalOpen(false);
                }}
              >
                <div className="profile-modal">
                  <div className="profile-modal__head">
                    <div className="profile-modal__title">Đổi mật khẩu</div>
                    <button type="button" className="profile-modal__close" onClick={() => setPwdModalOpen(false)} aria-label="Đóng">
                      ×
                    </button>
                  </div>
                  {pwdMsg && <div className="profile-msg">{pwdMsg}</div>}
                  <div className="form-grid">
                    <label className="field full">
                      <span>Mật khẩu hiện tại</span>
                      <input
                        type="password"
                        value={currentPassword}
                        onChange={(e) => setCurrentPassword(e.target.value)}
                        placeholder="Nhập mật khẩu hiện tại"
                      />
                    </label>
                    <label className="field">
                      <span>Mật khẩu mới</span>
                      <input
                        type="password"
                        value={newPassword}
                        onChange={(e) => setNewPassword(e.target.value)}
                        placeholder="Tối thiểu 6 ký tự"
                      />
                    </label>
                    <label className="field">
                      <span>Xác nhận mật khẩu mới</span>
                      <input
                        type="password"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        placeholder="Nhập lại mật khẩu mới"
                      />
                    </label>
                  </div>
                  <div className="profile-modal__actions">
                    <button type="button" className="btn-secondary" onClick={() => setPwdModalOpen(false)} disabled={savingPwd}>
                      Hủy
                    </button>
                    <button type="button" className="btn-primary" onClick={submitPasswordChange} disabled={savingPwd}>
                      <Save size={18} /> {savingPwd ? 'Đang đổi...' : 'Lưu'}
                    </button>
                  </div>
                </div>
              </div>
            ) : null}
          </main>

          {/* Mobile: place logout at very bottom */}
          <button
            type="button"
            className="btn-login profile-v2-logout-btn profile-v2-logout-btn--mobile"
            onClick={() => {
              logout();
              navigate('/');
            }}
            style={{
              width: '100%',
              justifyContent: 'center',
              gap: '0.5rem',
              textDecoration: 'none',
            }}
          >
            <LogOut size={18} /> Đăng xuất
          </button>
        </div>
      </div>
    </div>
  );
};

