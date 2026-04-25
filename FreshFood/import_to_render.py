import psycopg2
import sys

def import_sql():
    # Thông tin kết nối Render
    conn_string = "postgresql://freshfood_user:ccwF2DyoZWkCf6hOvYFXetmzrbSK4kj1@dpg-d7lis2ho3t8c73f6fll0-a.singapore-postgres.render.com/freshfood"
    sql_file_path = r"d:\tets\FreshFood\script_postgres.sql"

    print(f"Đang kết nối tới database trên Render...")
    try:
        conn = psycopg2.connect(conn_string)
        cur = conn.cursor()
        
        print(f"Đang đọc file SQL: {sql_file_path}")
        with open(sql_file_path, 'r', encoding='utf-8') as f:
            sql_content = f.read()

        print("Đang nạp dữ liệu (việc này có thể mất vài phút)...")
        cur.execute(sql_content)
        
        conn.commit()
        print("✅ THÀNH CÔNG! Dữ liệu đã được nạp đầy đủ vào database trên Render.")
        
        cur.close()
        conn.close()
    except Exception as e:
        print(f"❌ LỖI: {e}")

if __name__ == "__main__":
    import_sql()
