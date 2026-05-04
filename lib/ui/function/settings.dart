// lib/ui/settings.dart  —  EmuTrain
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../functions.dart';
import '../../update.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // ---------- Tab 控制器 ----------
  late TabController _tabController;

  // ---------- 旅途 tab 状态 ----------
  bool _showTrainImage = true;
  bool _showRealTrainMap = true;
  bool _showAutoUpdate = true;
  String _defaultHomePage = '旅途';

  static const String _trainImageKey = 'show_train_image';
  static const String _realTrainMapKey = 'show_real_train_map';
  static const String _defaultHomePageKey = 'default_home_page';
  static const String _showAutoUpdateKey = 'show_auto_update';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showTrainImage = prefs.getBool(_trainImageKey) ?? true;
      _showRealTrainMap = prefs.getBool(_realTrainMapKey) ?? true;
      _showAutoUpdate = prefs.getBool(_showAutoUpdateKey) ?? true;
      _defaultHomePage = prefs.getString(_defaultHomePageKey) ?? '旅途';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  // ==================== 通用 UI 构建 ====================

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Theme
                      .of(context)
                      .colorScheme
                      .primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Theme
                        .of(context)
                        .colorScheme
                        .onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) =>
      SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme
                .of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
          ),
        ),
        secondary: Icon(icon, color: Theme
            .of(context)
            .colorScheme
            .primary),
        value: value,
        onChanged: onChanged,
      );

  Widget _buildTile({
    IconData? icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null
          ? Icon(icon, color: theme.colorScheme.primary, size: 24)
          : null,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      )
          : null,
      trailing:
      trailing ??
          (trailingIcon != null
              ? Icon(
            trailingIcon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          )
              : null),
      onTap: onTap,
    );
  }

  // ==================== 数据源选择行（复用样式） ====================

  Widget _buildDataSourceRow<T>({
    required T currentValue,
    required T optionA,
    required String titleA,
    required String descA,
    required IconData iconA,
    required T optionB,
    required String titleB,
    required String descB,
    required IconData iconB,
    required void Function(T) onSelect,
  }) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _buildSourceChip(
              isSelected: currentValue == optionA,
              title: titleA,
              description: descA,
              icon: iconA,
              onTap: () => onSelect(optionA),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSourceChip(
              isSelected: currentValue == optionB,
              title: titleB,
              description: descB,
              icon: iconB,
              onTap: () => onSelect(optionB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip({
    required bool isSelected,
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final primary = Theme
        .of(context)
        .colorScheme
        .primary;
    final onSurface = Theme
        .of(context)
        .colorScheme
        .onSurface;
    final surface = Theme
        .of(context)
        .colorScheme
        .surfaceContainerHighest;

    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.10)
              : surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? primary : onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected ? primary : onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? primary.withValues(alpha: 0.8)
                    : onSurface.withValues(alpha: 0.55),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Icon(Icons.check_circle_rounded, size: 14, color: primary),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== 旅途 Tab ====================

  void showDeveloperDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          Dialog(
            backgroundColor: Theme
                .of(context)
                .colorScheme
                .surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme
                            .of(
                          context,
                        )
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/CrYinLang.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              color: Theme
                                  .of(
                                context,
                              )
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: Theme
                                    .of(context)
                                    .colorScheme
                                    .primary,
                              ),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '开发者',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme
                          .of(context)
                          .colorScheme
                          .onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cr.YinLang',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme
                          .of(
                        context,
                      )
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EmuTrain',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme
                          .of(
                        context,
                      )
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '欢迎关注我的社交账号获取更多信息',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme
                          .of(
                        context,
                      )
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              launchSocialLink(
                                context,
                                'https://github.com/CrYinLang',
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.code, size: 20),
                          label: const Text('GitHub'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              launchSocialLink(
                                context,
                                'https://www.douyin.com/user/MS4wLjABAAAA-bZxFhm96BhUle209c1gQ5HskPw4y-olT2PwOYevJ6fSkkHmIV23EuGfjaq1xHCx',
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000000),
                            foregroundColor: const Color(0xFF00FF9D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.video_library, size: 20),
                          label: const Text('抖音'),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              launchSocialLink(
                                context,
                                'https://gitee.com/CrYinLang',
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.code, size: 20),
                          label: const Text('Gitee'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              launchSocialLink(
                                context,
                                'https://qm.qq.com/q/AJ71AadV5K',
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000000),
                            foregroundColor: const Color(0xFF0099FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.group, size: 20),
                          label: const Text('QQ群'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme
                            .of(context)
                            .colorScheme
                            .onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('关闭'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTravelTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 主题设置 → 跳转独立页面
        Tool.buildSection(
          context: context,
          icon: Icons.color_lens,
          title: '主题设置',
          children: [
            ListTile(
              leading: Icon(
                Icons.palette,
                color: Theme
                    .of(context)
                    .colorScheme
                    .primary,
              ),
              title: const Text(
                '个性化主题',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                '深色模式、跟随系统、自定义颜色',
                style: TextStyle(fontSize: 12),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Theme
                    .of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
              onTap: () =>
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ThemeSettingsScreen(),
                    ),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSection(
          icon: Icons.home,
          title: '主页设置',
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.home_work,
                        size: 20,
                        color: Theme
                            .of(context)
                            .colorScheme
                            .primary,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '默认主页',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Theme
                                  .of(context)
                                  .colorScheme
                                  .onSurface,
                            ),
                          ),
                          Text(
                            '设置应用启动时显示的首页',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme
                                  .of(
                                context,
                              )
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  DropdownButton<String>(
                    value: _defaultHomePage,
                    items: ['旅途', '搜索']
                        .map(
                          (v) =>
                          DropdownMenuItem(
                            value: v,
                            child: Text(
                              v,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                    )
                        .toList(),
                    onChanged: (v) async {
                      if (v != null) {
                        setState(() => _defaultHomePage = v);
                        await _saveSetting(_defaultHomePageKey, v);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        // 应用信息
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.info,
          title: '应用信息',
          children: [
            _buildTile(
              title: '应用版本 (点击检测更新)',
              subtitle: '${Vars.version} | ${Vars.build} | ${Vars.lastUpdate}',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () => UpdateUI.showAppUpdateFlow(context),
            ),
            const Divider(height: 1),
            _buildTile(
              title: '开发者',
              subtitle: 'Cr.YinLang',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () => showDeveloperDialog(context),
            ),
          ],
        ),

        // 应用设置
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.storage,
          title: '应用设置',
          children: [
            _buildTile(
              icon: Icons.system_update_alt,
              title: '数据版本管理',
              subtitle: '车站 / 动车组 / 普速 / 机车 数据更新',
              trailingIcon: Icons.arrow_forward_ios,
              onTap: () =>
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DataVersionScreen(),
                    ),
                  ),
            ),
            const Divider(height: 1),
            Tool.buildSwitch(
              context: context,
              title: '自动检测更新',
              subtitle: '在有更新时自动弹出',
              icon: Icons.browser_updated_sharp,
              value: _showAutoUpdate,
              onChanged: (v) async {
                setState(() => _showAutoUpdate = v);
                await _saveSetting(_showAutoUpdateKey, v);
              },
            ),
          ],
        ),
      ],
    );
  }

  // ==================== 查询 Tab ====================

  Widget _buildSearchTab(AppSettings settings) {
    final onSurface = Theme
        .of(context)
        .colorScheme
        .onSurface;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 图标显示 + 站点数据源，合并为一个卡片 ──
        _buildSection(
          icon: Icons.photo_library,
          title: '图标显示设置 (查询)',
          children: [
            _buildSwitch(
              title: '显示动车组图标',
              subtitle: '在查询结果中显示动车组图标',
              icon: Icons.image,
              value: settings.showTrainIcons,
              onChanged: settings.toggleTrainIcons,
            ),
            const Divider(height: 1),
            _buildSwitch(
              title: '显示路局图标',
              subtitle: '在查询结果中显示路局图标',
              icon: Icons.account_balance,
              value: settings.showBureauIcons,
              onChanged: settings.toggleBureauIcons,
            ),
            const Divider(height: 1),
            // ── 站点数据源选择，融入本区域 ──
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4, left: 4),
              child: Text(
                '站点数据源',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
            _buildDataSourceRow<TrainStationDataSource>(
              currentValue: settings.dataStationSource,
              optionA: TrainStationDataSource.moeFactory,
              titleA: 'MoeFactory',
              descA: '有里程查看',
              iconA: Icons.cloud_upload,
              optionB: TrainStationDataSource.ctrip,
              titleB: '某大厂数据源',
              descB: '没有里程查看',
              iconB: Icons.factory,
              onSelect: settings.setStationDataSource,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 数据源设置
        _buildSection(
          icon: Icons.storage,
          title: '数据源设置 (查询)',
          children: [
            // 车次数据源
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                '车次数据源',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Tool.buildTrainDataSourceCard(
                      context: context,
                      settings: settings,
                      source: TrainDataSource.railRe,
                      title: 'Rail.re',
                      description: '第三方数据源',
                      icon: Icons.cloud_upload,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Tool.buildTrainDataSourceCard(
                      context: context,
                      settings: settings,
                      source: TrainDataSource.official12306,
                      title: '12306',
                      description: '官方数据源',
                      icon: Icons.train,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                settings.dataSourceDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 车号数据源
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                '车号数据源',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            _buildDataSourceRow<TrainEmuDataSource>(
              currentValue: settings.dataEmuSource,
              optionA: TrainEmuDataSource.railRe,
              titleA: 'Rail.re',
              descA: '第三方数据源',
              iconA: Icons.cloud_upload,
              optionB: TrainEmuDataSource.moeFactory,
              titleB: 'MoeFactory',
              descB: '第三方数据源',
              iconB: Icons.factory,
              onSelect: settings.setEmuDataSource,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                settings.dataEmuSourceDescription,
                style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),

        // 列车显示设置
        Tool.buildSection(
          context: context,
          icon: Icons.train,
          title: '列车显示设置 (旅途)',
          children: [
            Tool.buildSwitch(
              context: context,
              title: '显示列车图片',
              subtitle: '在旅途详情中显示列车图片',
              icon: Icons.photo_camera,
              value: _showTrainImage,
              onChanged: (v) async {
                setState(() => _showTrainImage = v);
                await _saveSetting(_trainImageKey, v);
              },
            ),
            const Divider(height: 1),
            Tool.buildSwitch(
              context: context,
              title: '显示相似走向图',
              subtitle: '显示更相似列车走行走向图（网络）',
              icon: Icons.map,
              value: _showRealTrainMap,
              onChanged: (v) async {
                setState(() => _showRealTrainMap = v);
                await _saveSetting(_realTrainMapKey, v);
              },
            ),
          ],
        ),
      ],
    );
  }

  // ==================== 根 build ====================

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: '通用设置'),
            Tab(icon: Icon(Icons.directions_railway), text: '功能设置'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildTravelTab(), _buildSearchTab(settings)],
          ),
        ),
      ],
    );
  }
}

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新界面')),
      body: Container(),
    );
  }
}

// ==================== 主题设置页面 ====================

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  // 预设颜色选项
  static const List<({Color color, String label})> _presetColors = [
    (color: Color(0xFF2196F3), label: '银狼蓝'),
    (color: Color(0xFF4CAF50), label: '麻酱绿'),
    (color: Color(0xFFF44336), label: '红色'),
    (color: Color(0xFF9C27B0), label: '紫色'),
    (color: Color(0xFFFF9800), label: '橙色'),
    (color: Color(0xFF00BCD4), label: '青色'),
    (color: Color(0xFFE91E63), label: '粉色'),
    (color: Color(0xFF795548), label: '棕色'),
    (color: Color(0xFF607D8B), label: '蓝灰'),
    (color: Color(0xFF009688), label: '翠绿'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('主题设置')),
      body: Consumer<AppSettings>(
        builder: (context, settings, _) {
          final cs = Theme
              .of(context)
              .colorScheme;
          final followSystem = settings.followSystem;
          final isDark = settings.themeMode == ThemeMode.dark;
          final usingMonet = settings.seedColor == null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 系统主题 ──
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.brightness_auto,
                            color: cs.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '系统主题',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      title: const Text(
                        '跟随系统主题',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '自动跟随手机深色/浅色模式',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      secondary: Icon(
                        Icons.phone_android,
                        color: cs.primary,
                      ),
                      value: followSystem,
                      onChanged: settings.toggleFollowSystem,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text(
                        '深色模式',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        followSystem
                            ? '跟随系统时不可手动设置'
                            : '手动切换深色/浅色',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      secondary: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: followSystem
                            ? cs.onSurface.withValues(alpha: 0.35)
                            : cs.primary,
                      ),
                      value: isDark,
                      // 跟随系统时禁用
                      onChanged: followSystem ? null : settings.toggleTheme,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 主题颜色 ──
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Row(
                        children: [
                          Icon(Icons.palette, color: cs.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '主题颜色',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 莫奈取色按钮
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6750A4),
                              Color(0xFF4FC3F7),
                              Color(0xFF81C784),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: usingMonet
                              ? Border.all(color: cs.primary, width: 2)
                              : null,
                        ),
                        child: usingMonet
                            ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        )
                            : null,
                      ),
                      title: const Text(
                        '莫奈取色（跟随壁纸）',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '自动从系统壁纸提取颜色，需Android 12+',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: usingMonet
                          ? Icon(
                        Icons.check_circle,
                        color: cs.primary,
                        size: 20,
                      )
                          : null,
                      onTap: () => settings.setSeedColor(null),
                    ),

                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // 预设颜色网格
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text(
                        '预设颜色',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _presetColors.map((entry) {
                          final isSelected = !usingMonet &&
                              settings.seedColor?.toARGB32() ==
                                  entry.color.toARGB32();
                          return GestureDetector(
                            onTap: () => settings.setSeedColor(entry.color),
                            child: Tooltip(
                              message: entry.label,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: entry.color,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected
                                      ? Border.all(
                                    color: cs.onSurface,
                                    width: 2.5,
                                  )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: entry.color.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: isSelected
                                    ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '颜色设置将在下次重启后完全生效',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== 数据版本管理页面 ====================

class DataVersionScreen extends StatefulWidget {
  const DataVersionScreen({super.key});

  @override
  State<DataVersionScreen> createState() => _DataVersionScreenState();
}

class _DataVersionScreenState extends State<DataVersionScreen> {
  static const String _autoSilentUpdateKey = 'auto_silent_update_data';
  bool _autoSilentUpdate = true;

  @override
  void initState() {
    super.initState();
    _loadAutoSilentUpdate();
  }

  Future<void> _loadAutoSilentUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSilentUpdate = prefs.getBool(_autoSilentUpdateKey) ?? true;
    });
  }

  Future<void> _saveAutoSilentUpdate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSilentUpdateKey, value);
    setState(() => _autoSilentUpdate = value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme
        .of(context)
        .colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('数据版本管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -------- 数据管理操作卡片 --------
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, color: cs.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '数据管理',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                // 开关：自动静默更新数据
                SwitchListTile(
                  secondary: Icon(
                    Icons.sync_rounded,
                    color: cs.primary,
                    size: 22,
                  ),
                  title: const Text(
                    '自动静默更新数据',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '每次打开应用时自动在后台检测并更新所有数据',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  value: _autoSilentUpdate,
                  onChanged: _saveAutoSilentUpdate,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // 一键更新所有数据
                _DataVersionTile(
                  title: '一键更新所有数据',
                  version: null,
                  icon: Icons.cloud_sync_rounded,
                  trailingWidget: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  subtitle: '检测并更新所有数据至最新版本',
                  onTap: () => UpdateUI.showUpdateAllDataFlow(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // -------- 本地数据版本卡片 --------
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        color: cs.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '本地数据版本',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                _DataVersionTile(
                  title: '车站数据',
                  version: 'V${Vars.stationBuild}',
                  icon: Icons.location_city,
                  onTap: () => UpdateUI.showStationUpdateFlow(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _DataVersionTile(
                  title: '动车组配属数据',
                  version: 'V${Vars.trainBuild}',
                  icon: Icons.directions_railway,
                  onTap: () => UpdateUI.showTrainUpdateFlow(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _DataVersionTile(
                  title: '普速客车配属数据',
                  version: 'V${Vars.coachTrainBuild}',
                  icon: Icons.train,
                  onTap: () => UpdateUI.showCoachTrainUpdateFlow(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _DataVersionTile(
                  title: '机车配属数据',
                  version: 'V${Vars.locoBuild}',
                  icon: Icons.electric_bolt,
                  onTap: () => UpdateUI.showLocoUpdateFlow(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '点击各条目可单独检查并更新对应数据',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataVersionTile extends StatelessWidget {
  final String title;
  final String? version;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailingWidget;

  const _DataVersionTile({
    required this.title,
    required this.version,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme
        .of(context)
        .colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(
        subtitle!,
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
      )
          : null,
      trailing: trailingWidget ??
          (version != null
              ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  version!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
            ],
          )
              : null),
      onTap: onTap,
    );
  }
}
