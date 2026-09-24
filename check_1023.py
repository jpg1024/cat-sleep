import json

config = json.load(open(r'C:\Users\pc\Documents\CatSleep\workday_config.json', encoding='utf-8'))
print('2026-10-23 in customDates:', '2026-10-23' in config['customDates'])
if '2026-10-23' in config['customDates']:
    print('Config:', json.dumps(config['customDates']['2026-10-23'], ensure_ascii=False))

cache = json.load(open(r'C:\Users\pc\Documents\CatSleep\year_workday_cache_2026.json', encoding='utf-8'))
print('\n2026-10-23 in cache allWorkdays:', '2026-10-23' in cache['allWorkdays'])

# 检查10月所有日期
print('\nOctober dates analysis:')
for day in range(1, 32):
    date_str = f'2026-10-{day:02d}'
    in_custom = date_str in config['customDates']
    in_cache = date_str in cache['allWorkdays']
    
    if in_custom or (day >= 20 and day <= 25):  # 只显示20-25日附近
        custom_type = config['customDates'].get(date_str, {}).get('type', 'N/A')
        print(f'  {date_str}: custom={in_custom}({custom_type}), in_cache={in_cache}')
