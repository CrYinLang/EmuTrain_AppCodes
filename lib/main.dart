// lib/main.dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_settings.dart';
import 'config/app_vars.dart';
import 'config/functions.dart';
import 'providers/journey_provider.dart';
import 'screens/emu_search_page.dart';
import 'screens/function/settings.dart';
import 'screens/function/tool_screen.dart';
import 'screens/travel_screen.dart';
import 'screens/welcome_page.dart';
import 'services/speed_service.dart';
import 'services/update.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Vars.initStationBuild();
  await Vars.initTrainBuild();
  await Vars.initCoachTrainBuild();
  await Vars.initLocoBuild();
  await Vars.initMirrorSource();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()..loadSettings()),
        ChangeNotifierProvider(create: (_) => SpeedService()),
      ],
      child: const EmuTrainApp(),
    ),
  );
}

// ==================== App 根组件 ====================
class EmuTrainApp extends StatelessWidget {
  const EmuTrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            // 优先用用户选择的颜色；没有则用莫奈壁纸色；再没有就用默认蓝色
            ColorScheme lightScheme;
            ColorScheme darkScheme;

            if (settings.seedColor != null) {
              lightScheme = ColorScheme.fromSeed(
                seedColor: settings.seedColor!,
                brightness: Brightness.light,
              );
              darkScheme = ColorScheme.fromSeed(
                seedColor: settings.seedColor!,
                brightness: Brightness.dark,
              );
            } else if (lightDynamic != null && darkDynamic != null) {
              lightScheme = lightDynamic.harmonized();
              darkScheme = darkDynamic.harmonized();
            } else {
              lightScheme = ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              );
              darkScheme = ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              );
            }

            return ChangeNotifierProvider(
              create: (_) => JourneyProvider(),
              child: MaterialApp(
                title: 'EmuTrain',
                themeMode: settings.themeMode,
                theme: ThemeData(
                  colorScheme: lightScheme,
                  useMaterial3: true,
                  brightness: Brightness.light,
                ),
                darkTheme: ThemeData(
                  colorScheme: darkScheme,
                  useMaterial3: true,
                  brightness: Brightness.dark,
                ),
                home: const WelcomeGate(child: MainScreen()),
                debugShowCheckedModeBanner: false,
              ),
            );
          },
        );
      },
    );
  }
}

// ==================== 主屏幕（导航） ====================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDefaultHomePage();
    _handleUpdate();
  }

  Future<void> _loadDefaultHomePage() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultPage = prefs.getString('default_home_page') ?? '旅途';
    setState(() {
      _currentIndex = defaultPage == '旅途' ? 0 : 1;
    });
  }

  Future<bool> _getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  Future<void> _handleUpdate() async {
    bool update = await _getSetting('showAutoUpdate');
    final versionInfo = await Vars.fetchVersionCommand();

    if (versionInfo == null) return;

    // 检查是否需要强制更新
    final minVersion = versionInfo['minVersion']?.toString() ?? '';
    final currentBuild = Vars.build;
    final message = versionInfo['message']?.toString() ?? '';
    final describe = Vars.getUpdateDescription(versionInfo);
    final version = versionInfo['Version']?.toString() ?? '';
    final qq = versionInfo['qq']?.toString() ?? '';

    // 先检查强制更新
    if (minVersion.isNotEmpty &&
        int.tryParse(minVersion) != null &&
        int.tryParse(currentBuild) != null) {
      if (int.parse(minVersion) > int.parse(currentBuild) && mounted) {
        // 显示强制更新对话框
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showForceUpdateDialog(context, describe, version, qq);
        });
        return; // 直接返回，不继续检查其他更新
      }
    }

    // 如果不是强制更新，检查是否有新版本
    if (update) {
      final remoteBuild = versionInfo['Build']?.toString() ?? '';
      if (remoteBuild.isNotEmpty &&
          int.tryParse(remoteBuild) != null &&
          int.tryParse(currentBuild) != null) {
        if (int.parse(remoteBuild) > int.parse(currentBuild) && mounted) {
          UpdateUI.showAppUpdateFlow(context);
        }
      }
    }

    // 如果有公告消息，显示公告
    if (message.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAnnouncementDialog(context, message);
      });
    }

    // 静默更新所有本地数据库（如果用户开启了自动静默更新）
    final autoSilentUpdate = await _getSetting('auto_silent_update_data');
    if (autoSilentUpdate) {
      UpdateService.silentUpdateAllData();
    }
  }

  void _showForceUpdateDialog(
    BuildContext context,
    String message,
    String version,
    String qq,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false, // 不可关闭
      builder: (BuildContext ctx) {
        return PopScope(
          canPop: false, // 禁用返回键
          child: AlertDialog(
            title: const Text('版本过低'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前版本过低，请更新到最新版本后再使用。在更新之前，您无法使用任何功能\n请您更新到最新版本${Vars.version}→$version',
                ),
                const SizedBox(height: 12),
                const Text(
                  '更新说明：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(message),
                const SizedBox(height: 4),
                const Text(
                  '下载链接：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(qq),
                const SizedBox(height: 4),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  launchSocialLink(context, qq);
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );
  }

  // 公告对话框
  void _showAnnouncementDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return PopScope(
          child: AlertDialog(
            title: const Text('调度命令'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(message)],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );
  }

  String get _currentPageTitle {
    switch (_currentIndex) {
      case 0:
        return '行程';
      case 1:
        return '搜索';
      case 2:
        return '其他';
      case 3:
        return '设置';
      default:
        return 'EmuTrain';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        return Scaffold(
          appBar: _currentIndex != 1
              ? AppBar(title: Text(_currentPageTitle), centerTitle: true)
              : null,
          body: _buildCurrentPage(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '旅行'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: '搜索'),
              BottomNavigationBarItem(icon: Icon(Icons.build), label: '其他'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const TravelScreen();
      case 1:
        return const SearchPage();
      case 2:
        return const ToolScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const TravelScreen();
    }
  }
}

// ==================== 图标工具类 ====================
