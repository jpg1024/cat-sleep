import json
from datetime import datetime

# 读取缓存文件
with open(r'C:\Users\pc\Documents\CatSleep\year_workday_cache_2026.json', 'r', encoding='utf-8') as f:
    cache = json.load(f)

print(f"年份: {cache['year']}")
print(f"工作日总数: {len(cache['allWorkdays'])}")
print(f"eve模式日期总数: {len(cache['eveOnlyDates'])}")

print("\n前10个工作日:")
for i, date in enumerate(cache['allWorkdays'][:10]):
    print(f"  {i+1}. {date}")

print("\n检查特定日期是否在缓存中:")
check_dates = ['2026-09-23', '2026-09-24', '2026-09-30', '2026-10-22', '2026-10-23']
for date_str in check_dates:
    in_all = date_str in cache['allWorkdays']
    in_eve = date_str in cache['eveOnlyDates']
    print(f"  {date_str}: allWorkdays={in_all}, eveOnlyDates={in_eve}")

# 检查9月和10月的所有工作日
print("\n9月的工作日:")
sept_dates = [d for d in cache['allWorkdays'] if d.startswith('2026-09')]
for d in sorted(sept_dates):
    print(f"  {d}")

print("\n10月的工作日:")
oct_dates = [d for d in cache['allWorkdays'] if d.startswith('2026-10')]
for d in sorted(oct_dates):
    print(f"  {d}")
