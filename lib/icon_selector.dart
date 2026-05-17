// icon_selector.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/function/error.dart';

class IconSelectorDialog extends StatefulWidget {
  final String selectedIcon;
  final ValueChanged<String> onIconSelected;

  const IconSelectorDialog({
    super.key,
    required this.selectedIcon,
    required this.onIconSelected,
  });

  @override
  State<IconSelectorDialog> createState() => _IconSelectorDialogState();
}

class _IconSelectorDialogState extends State<IconSelectorDialog> {
  final List<String> _trainIcons = [];
  final List<String> _bureauIcons = [];
  bool _loading = true;
  String _selectedIcon = '';

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.selectedIcon;
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    _trainIcons.clear();
    _bureauIcons.clear();

    try {
      // 从 assets 清单中读取所有图标
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifest);

      // 过滤出 train 和 bureau 图标
      for (final asset in manifestMap.keys) {
        if (asset.startsWith('assets/icons/train/') && 
            (asset.endsWith('.png') || asset.endsWith('.jpg') || asset.endsWith('.jpeg'))) {
          _trainIcons.add(asset.replaceFirst('assets/icons/', ''));
        } else if (asset.startsWith('assets/icons/bureau/') && 
            (asset.endsWith('.png') || asset.endsWith('.jpg') || asset.endsWith('.jpeg'))) {
          _bureauIcons.add(asset.replaceFirst('assets/icons/', ''));
        }
      }
    } catch (e) {
      _trainIcons.addAll([]);
      _bureauIcons.addAll([]);
            await logError(
        from: 'Icon_Selector.getIcons',
        error: '获取线路图标失败: $e',
        level: 3,
      );
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择线路图标'),
      content: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              height: 500,
              child: Column(
                children: [
                  // 选项卡
                  DefaultTabController(
                    length: 2,
                    child: Expanded(
                      child: Column(
                        children: [
                          TabBar(
                            tabs: const [
                              Tab(text: '列车类型'),
                              Tab(text: '路局标识'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // 列车图标网格
                                _buildIconGrid(_trainIcons),
                                // 路局图标网格
                                _buildIconGrid(_bureauIcons),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onIconSelected(_selectedIcon);
            Navigator.pop(context);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildIconGrid(List<String> icons) {
    if (icons.isEmpty) {
      return const Center(
        child: Text('暂无图标', style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final iconPath = icons[index];
        final isSelected = _selectedIcon == iconPath;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = iconPath),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 显示图标
                Image.asset(
                  'assets/icons/$iconPath',
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.train, size: 40),
                ),
                const SizedBox(height: 4),
                // 显示文件名
                Text(
                  iconPath.split('/').last.split('.').first,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
