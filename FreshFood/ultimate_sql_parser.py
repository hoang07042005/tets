import os
import re

input_file = r'd:\tets\FreshFood\script.sql'
output_file = r'd:\tets\FreshFood\script_postgres.sql'

print("Reading original file (UTF-16)...")
with open(input_file, 'r', encoding='utf-16') as f:
    sql_content = f.read()

# 1. Chuẩn hóa sơ bộ
sql_content = sql_content.replace("N'", "'")
sql_content = sql_content.replace('[dbo].', '').replace('[', '"').replace(']', '"')

# 2. Xóa các lệnh SQL Server không hợp lệ với PostgreSQL
sql_content = re.sub(r'SET IDENTITY_INSERT\s+.*?\s+(?:ON|OFF)\s*', '', sql_content, flags=re.IGNORECASE)
sql_content = re.sub(r'\bGO\b\s*', '', sql_content, flags=re.IGNORECASE)

# 3. Chuyển CAST(... AS DateTime2?) -> chuỗi ISO
sql_content = re.sub(r"CAST\('([^']+)'\s+AS\s+DateTime2?\)", r"'\1'", sql_content, flags=re.IGNORECASE)

# 4. Chuyển CAST(... AS Decimal(...)) -> giữ lại giá trị số thôi
sql_content = re.sub(r"CAST\(([0-9.\-]+)\s+AS\s+Decimal\([^)]+\)\)", r"\1", sql_content, flags=re.IGNORECASE)

# 5. Danh sách cột boolean (bao gồm IsGuestAccount)
bool_cols = {
    '"IsPublished"', '"IsUrgent"', '"IsMainImage"', '"IsDeleted"',
    '"IsVerified"', '"IsDefault"', '"IsLocked"', '"IsActive"',
    '"IsGuestAccount"'
}

def find_closing_paren(text, start):
    """Tìm vị trí đóng ngoặc ) tương ứng, bỏ qua nội dung trong chuỗi."""
    depth = 1
    in_str = False
    i = start
    while i < len(text) and depth > 0:
        c = text[i]
        if c == "'":
            if i + 1 < len(text) and text[i+1] == "'":
                i += 2  # Skip escaped quote ''
                continue
            else:
                in_str = not in_str
        elif not in_str:
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
        i += 1
    return i - 1  # position of closing ')'

def split_values_safe(v_str):
    """Tách VALUES một cách an toàn, giữ nguyên chuỗi."""
    vals = []
    curr = []
    in_s = False
    p_d = 0
    i = 0
    while i < len(v_str):
        c = v_str[i]
        if c == "'":
            if i + 1 < len(v_str) and v_str[i+1] == "'":
                curr.append("''")
                i += 2
                continue
            else:
                in_s = not in_s
                curr.append(c)
        elif not in_s:
            if c == '(':
                p_d += 1
                curr.append(c)
            elif c == ')':
                p_d -= 1
                curr.append(c)
            elif c == ',' and p_d == 0:
                vals.append(''.join(curr).strip())
                curr = []
                i += 1
                continue
            else:
                curr.append(c)
        else:
            # Escape literal newlines inside strings -> \n (backslash-n)
            # so each INSERT stays on a single line
            if c == '\n':
                curr.append('\\n')
            elif c == '\r':
                pass  # skip carriage return
            else:
                curr.append(c)
        i += 1
    if curr:
        vals.append(''.join(curr).strip())
    return vals

print("Extracting INSERT statements...")
count = 0
with open(output_file, 'w', encoding='utf-8') as out:
    pattern = re.compile(
        r'INSERT\s+(?:INTO\s+)?("(?:\w+)")\s*\(([^)]*?)\)\s*VALUES\s*\(',
        re.IGNORECASE
    )

    pos = 0
    while pos < len(sql_content):
        m = pattern.search(sql_content, pos)
        if not m:
            break

        table_name = m.group(1)
        cols_str = m.group(2)
        vals_start = m.end()  # right after the '('

        # Tìm ngoặc đóng của VALUES(
        vals_end = find_closing_paren(sql_content, vals_start)
        vals_raw = sql_content[vals_start:vals_end]

        pos = vals_end + 1

        # Parse cột
        cols = [c.strip() for c in cols_str.split(',')]

        # Parse giá trị
        vals = split_values_safe(vals_raw)

        if len(cols) == len(vals):
            new_vals = []
            for col, val in zip(cols, vals):
                if col in bool_cols:
                    v = val.strip()
                    if v == '1':
                        new_vals.append('TRUE')
                    elif v == '0':
                        new_vals.append('FALSE')
                    else:
                        new_vals.append(val)
                else:
                    new_vals.append(val)
            out.write(f'INSERT INTO {table_name} ({cols_str}) VALUES ({", ".join(new_vals)});\n')
        else:
            # Fallback: escape newlines manually
            safe_raw = vals_raw.replace('\r\n', '\\n').replace('\n', '\\n').replace('\r', '')
            out.write(f'INSERT INTO {table_name} ({cols_str}) VALUES ({safe_raw});\n')

        count += 1

print(f"Done! Extracted {count} statements.")

# Xác minh
with open(output_file, 'r', encoding='utf-8') as f:
    content = f.read()
    multiline = [i+1 for i, line in enumerate(content.splitlines()) if not line.startswith('INSERT') and line.strip()]
    if multiline:
        print(f"WARNING: Found {len(multiline)} non-INSERT lines (possible multiline issue) at: {multiline[:5]}")
    else:
        print("OK: All lines are single-line INSERT statements.")
    if "''freshfood" in content:
        print("WARNING: Double quote issue STILL present!")
    else:
        print("OK: No double quote issues detected.")
