// ui/function/icon_selector.dart
import 'package:flutter/material.dart';

const List<String> _kTrainIcons = [
  'train/CJ6.png',
  'train/CR200J.png',
  'train/CR200JC.png',
  'train/CR220J.png',
  'train/CR300AF.png',
  'train/CR300BF.png',
  'train/CR400AF-J.png',
  'train/CR400AF-SZE.png',
  'train/CR400AF.png',
  'train/CR400BF-0031.png',
  'train/CR400BF-C-5162.png',
  'train/CR400BF-C.png',
  'train/CR400BF-G-0051.png',
  'train/CR400BF-J-0001.png',
  'train/CR400BF-J-0003.png',
  'train/CR400BF-S.png',
  'train/CR400BF-Z-0524.png',
  'train/CR400BF-Z.png',
  'train/CR400BF.png',
  'train/CR450AF.png',
  'train/CR450BF.png',
  'train/CRH1A-A.png',
  'train/CRH1A.png',
  'train/CRH1E.png',
  'train/CRH2A-2460.png',
  'train/CRH2A.png',
  'train/CRH2BE.png',
  'train/CRH2C.png',
  'train/CRH2E-NG.png',
  'train/CRH2J.png',
  'train/CRH380A.png',
  'train/CRH380AD.png',
  'train/CRH380AJ.png',
  'train/CRH380AM.png',
  'train/CRH380B.png',
  'train/CRH380BJ-A.png',
  'train/CRH380BJ.png',
  'train/CRH380CL.png',
  'train/CRH380D.png',
  'train/CRH3A-A-GKCJ.png',
  'train/CRH3A-A-ZKCJ.png',
  'train/CRH3A-YC.png',
  'train/CRH3A.png',
  'train/CRH3C.png',
  'train/CRH5A.png',
  'train/CRH5E.png',
  'train/CRH5G.png',
  'train/CRH5J.png',
  'train/CRH6-2.png',
  'train/CRH6A.png',
  'train/CRH6F.png',
];

const List<String> _kBureauIcons = [
  'bureau/上海铁路局.png',
  'bureau/乌鲁木齐铁路局.png',
  'bureau/兰州铁路局.png',
  'bureau/北京铁路局.png',
  'bureau/南宁铁路局.png',
  'bureau/南昌铁路局.png',
  'bureau/呼和浩特铁路局.png',
  'bureau/哈尔滨铁路局.png',
  'bureau/国铁集团.png',
  'bureau/太原铁路局.png',
  'bureau/广东城际.png',
  'bureau/广州铁路局.png',
  'bureau/成都铁路局.png',
  'bureau/昆明铁路局.png',
  'bureau/武汉铁路局.png',
  'bureau/沈阳铁路局.png',
  'bureau/济南铁路局.png',
  'bureau/西安铁路局.png',
  'bureau/郑州铁路局.png',
  'bureau/铁科院.png',
  'bureau/青藏铁路局.png',
  'bureau/香港铁路有限公司.png',
];

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
  String _selectedIcon = '';

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.selectedIcon;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('选择线路图标'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: DefaultTabController(
          length: 2,
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
                    _buildIconGrid(_kTrainIcons, cs),
                    _buildIconGrid(_kBureauIcons, cs),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildIconGrid(List<String> icons, ColorScheme cs) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: icons.length + 1,
      itemBuilder: (context, index) {
        // index 0 = 默认（无图标）
        if (index == 0) {
          final isSelected = _selectedIcon.isEmpty;
          return GestureDetector(
            onTap: () => setState(() => _selectedIcon = ''),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? cs.primary : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route,
                    size: 40,
                    color: isSelected ? cs.primary : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '默认',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        final iconPath = icons[index - 1];
        final isSelected = _selectedIcon == iconPath;
        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = iconPath),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? cs.primary : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icon/$iconPath',
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
