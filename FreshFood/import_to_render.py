import psycopg2
import sys

def import_sql():
    conn_string = "postgresql://freshfood_user:ccwF2DyoZWkCf6hOvYFXetmzrbSK4kj1@dpg-d7lis2ho3t8c73f6fll0-a.singapore-postgres.render.com/freshfood"
    sql_file_path = r"d:\tets\FreshFood\script_postgres.sql"

    print(f"Connecting to Render Database...")
    try:
        conn = psycopg2.connect(conn_string)
        conn.autocommit = True
        cur = conn.cursor()
        
        print(f"Opening SQL file...")
        with open(sql_file_path, 'r', encoding='utf-8') as f:
            # Đọc từng dòng để tránh lỗi bộ nhớ và lỗi cắt nhầm dấu chấm phẩy
            statements = f.readlines()

        print(f"Total commands: {len(statements)}")

        pending = statements
        for round in range(1, 6):
            print(f"\n--- ROUND {round} (Pending: {len(pending)}) ---")
            failed = []
            success = 0

            for i, stmt in enumerate(pending):
                stmt = stmt.strip()
                if not stmt: continue
                
                try:
                    cur.execute(stmt)
                    success += 1
                    if success % 1000 == 0:
                        print(f"Successfully imported {success} commands...")
                except Exception as e:
                    err = str(e).lower()
                    if "foreign key" in err or "violates" in err or "does not exist" in err:
                        failed.append(stmt)
                    else:
                        # Chỉ in lỗi nếu không phải là lỗi phụ thuộc
                        if "already exists" not in err:
                            print(f"Error: {e}")
                            print(f"Statement: {stmt[:100]}...")

            print(f"Round {round} result: Success {success}, Failed {len(failed)}")
            pending = failed
            if success == 0: break

        if not pending:
            print("\n✅ ALL DATA IMPORTED SUCCESSFULLY!")
        else:
            print(f"\n⚠️ Finished with {len(pending)} pending statements.")
        
        cur.close()
        conn.close()
    except Exception as e:
        print(f"❌ CONNECTION ERROR: {e}")

if __name__ == "__main__":
    import_sql()
