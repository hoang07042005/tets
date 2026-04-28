import { useState, useEffect } from 'react';
import { apiService } from '../../services/api';

export function AdminSystemPage() {
    const [isMaintenance, setIsMaintenance] = useState(false);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        const fetchStatus = async () => {
            try {
                // Thêm hàm lấy trạng thái bảo trì vào apiService.
                const res = await apiService.getAdminMaintenanceStatus();
                setIsMaintenance(res.isMaintenance);
            } catch (err) {
                console.error(err);
            } finally {
                setLoading(false);
            }
        };
        fetchStatus();
    }, []);

    const handleToggle = async () => {
        setSaving(true);
        try {
            const newState = !isMaintenance;
            const res = await apiService.toggleAdminMaintenance(newState);
            setIsMaintenance(res.isMaintenance);
            alert(`Đã ${newState ? 'bật' : 'tắt'} chế độ bảo trì thành công!`);
        } catch (err) {
            alert('Có lỗi xảy ra khi cập nhật trạng thái bảo trì.');
            console.error(err);
        } finally {
            setSaving(false);
        }
    };

    if (loading) {
        return <div className="admin-page-header"><h2>Đang tải...</h2></div>;
    }

    return (
        <div className="admin-fade-in">
            <header className="admin-page-header">
                <div>
                    <h1 className="admin-page-title">Hệ thống</h1>
                    <p className="admin-page-desc">Quản lý các cài đặt chung của hệ thống</p>
                </div>
            </header>

            <div className="admin-card" style={{ maxWidth: 600 }}>
                <h3 style={{ marginBottom: 15, fontSize: '1.25rem' }}>Bảo trì hệ thống</h3>
                <p style={{ color: '#4b5563', marginBottom: 20 }}>
                    Khi bật chế độ bảo trì, người dùng thường sẽ không thể truy cập website và sẽ nhìn thấy màn hình thông báo bảo trì.
                    Tài khoản Admin vẫn có thể truy cập bình thường.
                </p>

                <div style={{ display: 'flex', alignItems: 'center', gap: 15 }}>
                    <div style={{ 
                        padding: '10px 20px', 
                        borderRadius: 8, 
                        backgroundColor: isMaintenance ? '#fee2e2' : '#d1fae5',
                        color: isMaintenance ? '#b91c1c' : '#047857',
                        fontWeight: 600
                    }}>
                        Trạng thái: {isMaintenance ? 'ĐANG BẢO TRÌ' : 'HOẠT ĐỘNG BÌNH THƯỜNG'}
                    </div>

                    <button 
                        onClick={handleToggle} 
                        disabled={saving}
                        className={isMaintenance ? 'btn-secondary' : 'btn-danger'}
                    >
                        {saving ? 'Đang xử lý...' : isMaintenance ? 'Tắt bảo trì' : 'Bật bảo trì'}
                    </button>
                </div>
            </div>
        </div>
    );
}
