import re
import os

input_file = r'd:\tets\FreshFood\script_postgres.sql'
temp_file = r'd:\tets\FreshFood\script_postgres_v2.sql'

print("Standardizing SQL file...")

with open(input_file, 'r', encoding='utf-8') as f_in, \
     open(temp_file, 'w', encoding='utf-8') as f_out:
    
    for line in f_in:
        line = line.strip()
        if not line or not line.startswith('INSERT INTO'):
            if line: f_out.write(line + '\n')
            continue
        
        match = re.match(r'INSERT INTO (\w+) \((.*?)\) VALUES (.*)', line)
        if match:
            table_name = match.group(1)
            columns = match.group(2)
            values = match.group(3)
            
            if values.endswith(';'):
                values = values[:-1]
            
            quoted_columns = ', '.join([f'"{c.strip()}"' for c in columns.split(',')])
            new_line = f'INSERT INTO "{table_name}" ({quoted_columns}) VALUES {values};\n'
            f_out.write(new_line)
        else:
            f_out.write(line + ';\n')

if os.path.exists(temp_file):
    if os.path.exists(input_file): os.remove(input_file)
    os.rename(temp_file, input_file)
    print("Done standardizing.")
