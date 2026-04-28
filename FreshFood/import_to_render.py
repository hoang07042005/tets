import psycopg2
import sys

def import_sql():
    conn_string = "postgresql://freshfood_user:ccwF2DyoZWkCf6hOvYFXetmzrbSK4kj1@dpg-d7lis2ho3t8c73f6fll0-a.singapore-postgres.render.com/freshfood"
    sql_file_path = r"d:\tets\FreshFood\script_postgres.sql"

    print("Connecting to Render Database...")
    try:
        conn = psycopg2.connect(conn_string)
        conn.autocommit = True
        cur = conn.cursor()
        
        print("Opening SQL file...")
        with open(sql_file_path, 'r', encoding='utf-8') as f:
            statements = f.readlines()

        print(f"Total commands: {len(statements)}")

        pending = statements
        error_log = {}  # track unique error types

        for round_num in range(1, 10):
            print(f"\n--- ROUND {round_num} (Pending: {len(pending)}) ---")
            failed = []
            success = 0

            for stmt in pending:
                stmt = stmt.strip()
                if not stmt:
                    continue
                
                try:
                    cur.execute(stmt)
                    success += 1
                except Exception as e:
                    err_msg = str(e)
                    err_lower = err_msg.lower()
                    if "foreign key" in err_lower or "violates foreign" in err_lower:
                        failed.append(stmt)
                    elif "already exists" in err_lower or "duplicate key" in err_lower:
                        # Skip duplicates silently
                        success += 1
                    else:
                        failed.append(stmt)
                        # Log unique errors
                        key = err_msg[:80]
                        if key not in error_log:
                            error_log[key] = (err_msg, stmt[:150])

            print(f"Round {round_num} result: Success {success}, Failed {len(failed)}")
            pending = failed
            if not pending:
                break
            if success == 0:
                print("\nNo more progress. Dumping unique errors:")
                for key, (err, stmt_preview) in list(error_log.items())[:20]:
                    print(f"\n  ERR: {err[:200]}")
                    print(f"  SQL: {stmt_preview}")
                break

        if not pending:
            print("\nALL DATA IMPORTED SUCCESSFULLY!")
        else:
            print(f"\nFinished with {len(pending)} pending statements.")
            print("\nSaving failed statements to failed_imports.sql...")
            with open(r"d:\tets\FreshFood\failed_imports.sql", "w", encoding="utf-8") as f:
                for stmt in pending:
                    f.write(stmt + "\n")
            print("Saved.")
        
        cur.close()
        conn.close()
    except Exception as e:
        print(f"CONNECTION ERROR: {e}")

if __name__ == "__main__":
    import_sql()
