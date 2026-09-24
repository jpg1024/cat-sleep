import 'package:cat_sleep/models/task_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScheduleMode 枚举', () {
    test('顺序为：从现在开始 / 工作日 / 指定时间', () {
      expect(
        ScheduleMode.values.map((e) => e.label).toList(),
        ['从现在开始', '工作日', '指定时间'],
      );
    });
  });

  group('TaskConfig 序列化', () {
    test('scheduleMode 按名称序列化，不受枚举重排影响', () {
      for (final mode in ScheduleMode.values) {
        final json = TaskConfig(scheduleMode: mode).toJson();
        expect(json['scheduleMode'], mode.name);
        expect(
          TaskConfig.fromJson(json).scheduleMode,
          mode,
          reason: '模式 $mode 序列化后应能原样读回',
        );
      }
    });

    test('兼容旧版按索引序列化的数据', () {
      // 旧索引：0=指定时间 1=倒计时 2=间隔(已移除) 3=工作日
      expect(TaskConfig.fromJson({'scheduleMode': 0}).scheduleMode,
          ScheduleMode.specificTime);
      expect(TaskConfig.fromJson({'scheduleMode': 1}).scheduleMode,
          ScheduleMode.countdown);
      expect(TaskConfig.fromJson({'scheduleMode': 2}).scheduleMode,
          ScheduleMode.countdown);
      expect(TaskConfig.fromJson({'scheduleMode': 3}).scheduleMode,
          ScheduleMode.workday);
    });

    test('默认调度方式为从现在开始', () {
      expect(TaskConfig().scheduleMode, ScheduleMode.countdown);
    });

    test('workdayEveOnly 序列化，旧配置缺省为 false', () {
      final json = TaskConfig(workdayEveOnly: true).toJson();
      expect(json['workdayEveOnly'], true);
      expect(TaskConfig.fromJson(json).workdayEveOnly, true);
      // 旧配置文件没有该字段时默认关闭
      expect(TaskConfig.fromJson({'scheduleMode': 'workday'}).workdayEveOnly,
          false);
    });
  });
}
