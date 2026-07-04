// route_store_widgets.dart
// 路线商店页面的组件

import 'package:flutter/material.dart';

/// 路线商店项卡片
class RouteStoreItemCard extends StatelessWidget {
  final String name;
  final String author;
  final String icon;
  final bool isInstalled;
  final bool isInstalling;
  final VoidCallback onInstall;
  final VoidCallback onViewDetail;

  const RouteStoreItemCard({
    super.key,
    required this.name,
    required this.author,
    required this.icon,
    this.isInstalled = false,
    this.isInstalling = false,
    required this.onInstall,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onViewDetail,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.map, color: theme.colorScheme.primary, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '作者：$author',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isInstalled) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text(
                              '已安装',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isInstalling)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isInstalled)
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: onViewDetail,
                )
              else
                FilledButton.icon(
                  onPressed: onInstall,
                  icon: const Icon(Icons.download),
                  label: const Text('安装'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 批量操作工具栏
class RouteStoreBulkActionBar extends StatelessWidget {
  final int checkedCount;
  final VoidCallback onInstallChecked;
  final VoidCallback onClearChecked;

  const RouteStoreBulkActionBar({
    super.key,
    required this.checkedCount,
    required this.onInstallChecked,
    required this.onClearChecked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '已选 $checkedCount 项',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(
            onPressed: onClearChecked,
            child: const Text('取消选择'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: checkedCount > 0 ? onInstallChecked : null,
            icon: const Icon(Icons.download),
            label: const Text('批量安装'),
          ),
        ],
      ),
    );
  }
}

/// 加载状态指示器
class RouteStoreLoadingIndicator extends StatelessWidget {
  final String message;

  const RouteStoreLoadingIndicator({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 错误状态显示
class RouteStoreErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const RouteStoreErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
