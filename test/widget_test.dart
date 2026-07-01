// 首页冒烟测试：验证应用可正常启动并渲染工具箱首页。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sdm/main.dart';
import 'package:sdm/utils/app_prefs.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
  });

  testWidgets('首页正常渲染工具卡片', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // 标题与首屏可见的核心工具应出现在首页（网格为懒加载，仅校验可见项）。
    expect(find.text('SDM 工具箱'), findsWidgets);
    expect(find.text('PDF 转图片'), findsOneWidget);
    expect(find.text('批量打印'), findsOneWidget);
  });
}
