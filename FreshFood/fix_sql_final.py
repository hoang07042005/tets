import re
import os

input_file = r'd:\tets\FreshFood\script_postgres.sql'
temp_file = r'd:\tets\FreshFood\script_postgres_v3.sql'

print("Big fix for SQL file (Booleans and Multi-line)...")

# Danh sách các cột kiểu Boolean cần chuyển đổi 0/1 sang FALSE/TRUE
bool_cols = ['IsPublished', 'IsUrgent', 'IsMainImage', 'IsDeleted', 'IsVerified', 'IsDefault', 'IsLocked', 'IsActive']

with open(input_file, 'r', encoding='utf-8') as f_in:
    content = f_in.read()

# 1. Nối các dòng bị ngắt (tìm các đoạn INSERT không kết thúc bằng ;)
# Chúng ta sẽ dùng regex để tìm toàn bộ cụm INSERT ... ; kể cả khi nó nằm trên nhiều dòng
statements = re.findall(r'INSERT INTO.*?;', content, re.DOTALL)

with open(temp_file, 'w', encoding='utf-8') as f_out:
    for stmt in statements:
        # Xóa các ký tự xuống hàng thừa trong câu lệnh để đưa về 1 dòng
        stmt = re.sub(r'\s+', ' ', stmt).strip()
        
        # 2. Xử lý tên bảng và cột (Đảm bảo có ngoặc kép)
        match = re.match(r'INSERT INTO (\w+) \((.*?)\) VALUES (.*);', stmt)
        if match:
            table_name = match.group(1)
            columns_str = match.group(2)
            values_str = match.group(3)
            
            columns = [c.strip().replace('"', '') for c in columns_str.split(',')]
            # Tách values - Lưu ý: tách theo dấu phẩy nhưng né dấu phẩy trong nháy đơn
            # Đây là phần khó nhất, ta dùng mẹo đơn giản hơn là replace trực tiếp dựa trên tên cột
            
            # Đổi 0 -> FALSE, 1 -> TRUE cho các cột boolean
            val_list = []
            # Tách các giá trị bằng regex thông minh (né dấu phẩy trong chuỗi)
            vals = re.findall(r"'(?:''|[^'])*'|[^,]+", values_str)
            vals = [v.strip() for v in vals]
            
            if len(vals) == len(columns):
                for col, val in zip(columns, vals):
                    if col in bool_cols:
                        if val == '0': val = 'FALSE'
                        elif val == '1': val = 'TRUE'
                    val_list.append(val)
                
                quoted_cols = ', '.join([f'"{c}"' for c in columns])
                final_values = ', '.join(val_list)
                f_out.write(f'INSERT INTO "{table_name}" ({quoted_cols}) VALUES ({final_values});\n')
            else:
                # Nếu không khớp số lượng cột (do lỗi parse), giữ nguyên nhưng thêm ngoặc kép bảng
                f_out.write(f'INSERT INTO "{table_name}" ({columns_str}) VALUES {values_str};\n')
        else:
            f_out.write(stmt + '\n')

if os.path.exists(temp_file):
    if os.path.exists(input_file): os.remove(input_file)
    os.rename(temp_file, input_file)
    print("Done! SQL file is now PostgreSQL-compatible.")
