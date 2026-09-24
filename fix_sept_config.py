import json

# 读取配置
config_path = r'C:\Users\pc\Documents\CatSleep\workday_config.json'
with open(config_path, 'r', encoding='utf-8') as f:
    config = json.load(f)

print('Before fix:')
print(f'  addedWorkdays: {config.get("addedWorkdays", [])}')
print(f'  customDates keys with 09-2: {[k for k in config["customDates"].keys() if "09-2" in k or "9-2" in k]}')

# 删除9月23日和9月24日
dates_to_remove = ['2026-09-23', '2026-09-24']
for date_key in dates_to_remove:
    # 从 addedWorkdays 移除
    if date_key in config.get('addedWorkdays', []):
        config['addedWorkdays'].remove(date_key)
    
    # 从 removedWorkdays 移除
    if date_key in config.get('removedWorkdays', []):
        config['removedWorkdays'].remove(date_key)
    
    # 从 customDates 移除
    if date_key in config.get('customDates', {}):
        del config['customDates'][date_key]

# 保存配置
with open(config_path, 'w', encoding='utf-8') as f:
    json.dump(config, f, ensure_ascii=False, indent=2)

print('\nAfter fix:')
print(f'  addedWorkdays: {config.get("addedWorkdays", [])}')
print(f'  customDates keys with 09-2: {[k for k in config["customDates"].keys() if "09-2" in k or "9-2" in k]}')
print('\n配置文件已更新！')
