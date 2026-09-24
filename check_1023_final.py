import json

config = json.load(open(r'C:\Users\pc\Documents\CatSleep\workday_config.json', encoding='utf-8'))

print('Checking 2026-10-23:')
print(f'  In customDates: {"2026-10-23" in config["customDates"]}')
if '2026-10-23' in config['customDates']:
    print(f'  Config: {json.dumps(config["customDates"]["2026-10-23"], ensure_ascii=False)}')

# 检查所有10月的自定义日期
print('\nAll October custom dates:')
for key in sorted(config['customDates'].keys()):
    if key.startswith('2026-10'):
        print(f'  {key}: {config["customDates"][key]}')
