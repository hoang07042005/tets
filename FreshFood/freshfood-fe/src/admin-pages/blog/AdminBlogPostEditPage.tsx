import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { apiService } from '../../services/api';
import type { BlogPost } from '../../types';
import { AdminBlogPostForm } from './AdminBlogPostForm';

export const AdminBlogPostEditPage = () => {
  const { id } = useParams();
  const idOrToken = String(id || '').trim();
  const numericId = Number(idOrToken);
  const hasNumericId =
    Number.isFinite(numericId) && numericId > 0 && String(Math.trunc(numericId)) === idOrToken;
  const blogPostId = hasNumericId ? numericId : null;
  const blogPostToken = !hasNumericId && idOrToken ? idOrToken : null;
  const [loading, setLoading] = useState(true);
  const [post, setPost] = useState<BlogPost | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      if ((!blogPostId || blogPostId <= 0) && !blogPostToken) {
        setError('ID không hợp lệ');
        setLoading(false);
        return;
      }
      setLoading(true);
      setError(null);
      try {
        const p = blogPostId
          ? await apiService.getAdminBlogPost(blogPostId)
          : await apiService.getAdminBlogPostByToken(String(blogPostToken || '').trim());
        if (!alive) return;
        setPost(p);
        if (!p) setError('Không tìm thấy bài viết');
      } catch (e: any) {
        if (!alive) return;
        setError(e?.message || 'Không tải được bài viết');
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [blogPostId, blogPostToken]);

  return (
    <div className="blog-admin">
      <div className="blog-admin-kicker">Admin content</div>
      <div className="admin-header">
        <div>
          <h1 className="blog-admin-title">Sửa bài viết</h1>
          <p className="blog-admin-sub muted">Cập nhật nội dung và trạng thái hiển thị.</p>
        </div>
      </div>

      {loading ? (
        <div className="admin-card">
          <div className="admin-card-body">
            <div className="admin-empty">Đang tải…</div>
          </div>
        </div>
      ) : error ? (
        <div className="admin-card">
          <div className="admin-card-body">
            <div className="admin-alert admin-alert--danger">{error}</div>
          </div>
        </div>
      ) : (
        <AdminBlogPostForm mode="edit" blogPostId={post?.blogPostID ?? blogPostId ?? 0} initial={post} />
      )}
    </div>
  );
};

