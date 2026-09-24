import json
from datetime import date

# 读取当前配置
config = json.load(open(r'C:\Users\pc\Documents\CatSleep\workday_config.json', encoding='utf-8'))

print('Current workday_config.json:')
print(f'  addedWorkdays: {config.get("addedWorkdays", [])}')
print(f'  removedWorkdays: {config.get("removedWorkdays", [])}')
print(f'  customDates count: {len(config.get("customDates", {}))}')

# 检查10月23日是否在removedWorkdays中
print(f'\n2026-10-23 in removedWorkdays: {"2026-10-23" in config.get("removedWorkdays", [])}')
print(f'2026-10-23 in addedWorkdays: {"2026-10-23" in config.get("addedWorkdays", [])}')
print(f'2026-10-23 in customDates: {"2026-10-23" in config.get("customDates", {})}')

# 检查旧版覆盖逻辑
print('\nChecking legacy override logic:')
if 'removedWorkdays' in config and '2026-10-23' in config['removedWorkdays']:
    print('  -> 10/23 is in removedWorkdays, should NOT be a workday!')
