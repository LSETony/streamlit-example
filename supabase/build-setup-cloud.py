#!/usr/bin/env python3
"""Собирает supabase/setup-cloud.sql: все миграции по порядку, демо-зал «Атлет» (seed.sql) и публичные демо (demo.sql)."""
import glob, os
root = os.path.dirname(os.path.abspath(__file__))
os.chdir(os.path.dirname(root))
files = sorted(glob.glob("supabase/migrations/*.sql")) + ["supabase/seed.sql", "supabase/demo.sql"]
out = ("-- core. — полная установка базы для Supabase Cloud: вставьте весь файл в SQL Editor и нажмите Run.\n"
       "-- Собрано скриптом supabase/build-setup-cloud.py из supabase/migrations/*.sql, supabase/seed.sql и supabase/demo.sql.\n\n")
for i, f in enumerate(files):
    out += f"-- ===== {f}\n" + open(f, encoding="utf-8").read()
    if i < len(files) - 1 and not out.endswith("\n\n"):
        out += "\n"
open("supabase/setup-cloud.sql", "w", encoding="utf-8").write(out)
print("supabase/setup-cloud.sql:", len(files), "files")
