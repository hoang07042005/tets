import { AdminBlogPostForm } from './AdminBlogPostForm';

export const AdminBlogPostCreatePage = () => {
  return (
    <div className="blog-admin">
      <div className="blog-admin-kicker">Admin content</div>
      <div className="admin-header">
        <div>
          <h1 className="blog-admin-title">Thêm bài viết</h1>
          <p className="blog-admin-sub muted">Tạo bài viết mới cho blog.</p>
        </div>
      </div>
      <AdminBlogPostForm mode="create" />
    </div>
  );
};

