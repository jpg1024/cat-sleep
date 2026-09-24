import json
from datetime import date

config = json.load(open(r'C:\Users\pc\Documents\CatSleep\workday_config.json', encoding='utf-8'))
cache = json.load(open(r'C:\Users\pc\Documents\CatSleep\year_workday_cache_2026.json', encoding='utf-8'))

# 模拟 WorkdayService.isWorkday() 逻辑
def is_workday(year, month, day):
    date_obj = date(year, month, day)
    date_key = f'{year}-{month:02d}-{day:02d}'
    
    # 1. 检查用户自定义日期
    if date_key in config['customDates']:
        custom_type = config['customDates'][date_key]['type']
        return custom_type == 'workday'
    
    # 2. 检查节假日缓存（内置数据）
    holidays_2026 = {
        '2026-10-01': 'holiday',
        '2026-10-02': 'holiday',
        '2026-10-03': 'holiday',
        '2026-10-04': 'holiday',
        '2026-10-05': 'holiday',
        '2026-10-06': 'holiday',
        '2026-10-07': 'holiday',
        '2026-10-10': 'workday',  # 调休
    }
    
    if date_key in holidays_2026:
        return holidays_2026[date_key] == 'workday'
    
    # 3. 默认：周一到周五是工作日
    return date_obj.weekday() < 5

# 测试10月20-25日
print('Testing is_workday for Oct 20-25:')
for day in range(20, 26):
    result = is_workday(2026, 10, day)
    weekday_name = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date(2026, 10, day).weekday()]
    in_cache = f'2026-10-{day:02d}' in cache['allWorkdays']
    print(f'  2026-10-{day:02d} ({weekday_name}): is_workday={result}, in_cache={in_cache}')
