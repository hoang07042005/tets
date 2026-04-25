import os
import re

input_file = r'd:\tets\FreshFood\script.sql'
output_file = r'd:\tets\FreshFood\script_postgres.sql'

print("Reading original file...")
with open(input_file, 'r', encoding='utf-16') as f:
    sql_content = f.read()

# Xóa các lệnh đặc thù của SQL Server
sql_content = re.sub(r'SET IDENTITY_INSERT .*?;', '', sql_content, flags=re.IGNORECASE)
sql_content = re.sub(r'GO\n', '', sql_content, flags=re.IGNORECASE)
sql_content = sql_content.replace('[dbo].', '').replace('[', '"').replace(']', '"')
sql_content = sql_content.replace("N'", "'") # Bỏ tiền tố N của unicode
sql_content = sql_content.replace("CAST(NULL AS DateTime2)", "NULL")

print("Parsing character by character...")

statements = []
current_stmt = []
in_string = False

# Đọc từng ký tự để cắt chính xác các câu lệnh bằng dấu chấm phẩy
for char in sql_content:
    if char == "'":
        in_string = not in_string
        current_stmt.append(char)
    elif char == ';' and not in_string:
        current_stmt.append(char)
        stmt_str = ''.join(current_stmt).strip()
        if stmt_str.upper().startswith('INSERT INTO'):
            statements.append(stmt_str)
        current_stmt = []
    else:
        current_stmt.append(char)

# Thêm câu lệnh cuối nếu có
last_stmt = ''.join(current_stmt).strip()
if last_stmt.upper().startswith('INSERT INTO'):
    if not last_stmt.endswith(';'): last_stmt += ';'
    statements.append(last_stmt)

print(f"Found {len(statements)} valid INSERT statements.")

bool_cols = ['"IsPublished"', '"IsUrgent"', '"IsMainImage"', '"IsDeleted"', '"IsVerified"', '"IsDefault"', '"IsLocked"', '"IsActive"']

print("Converting Booleans and writing to file...")
with open(output_file, 'w', encoding='utf-8') as f:
    for stmt in statements:
        # Xóa ký tự xuống hàng để đưa về 1 dòng duy nhất (nhưng cẩn thận với chuỗi)
        # Tuy nhiên, để an toàn cho HTML, ta cứ giữ nguyên xuống dòng, 
        # vì import_to_render.py sẽ dùng cursor.execute toàn bộ câu lệnh
        
        match = re.match(r'INSERT INTO ("\w+") \((.*?)\) VALUES\s*\((.*)\);', stmt, flags=re.IGNORECASE | re.DOTALL)
        if match:
            table_name = match.group(1)
            columns_str = match.group(2)
            values_str = match.group(3)
            
            columns = [c.strip() for c in columns_str.split(',')]
            
            # Phân tích values bằng state machine để không cắt nhầm dấu phẩy trong chuỗi
            vals = []
            curr_val = []
            in_str = False
            
            for char in values_str:
                if char == "'":
                    in_str = not in_str
                    curr_val.append(char)
                elif char == ',' and not in_str:
                    vals.append(''.join(curr_val).strip())
                    curr_val = []
                else:
                    curr_val.append(char)
            if curr_val:
                vals.append(''.join(curr_val).strip())
            
            # Xử lý boolean
            if len(vals) == len(columns):
                for i, col in enumerate(columns):
                    if col in bool_cols:
                        if vals[i] == '0': vals[i] = 'FALSE'
                        elif vals[i] == '1': vals[i] = 'TRUE'
                
                final_values = ', '.join(vals)
                f.write(f'INSERT INTO {table_name} ({columns_str}) VALUES ({final_values});\n')
            else:
                f.write(stmt + '\n')
        else:
            f.write(stmt + '\n')

print("Done generating PostgreSQL script!")

