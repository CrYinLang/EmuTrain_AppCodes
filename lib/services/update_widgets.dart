// update_widgets.dart
// 更新相关的 UI 组件

import 'package:flutter/material.dart';

/// 更新检查对话框
class UpdateCheckDialog extends StatelessWidget {
  final String currentVersion;
  final String? latestVersion;
  final String? changelog;
  final bool isChecking;
  final bool hasUpdate;
  final VoidCallback onCheck;
  final VoidCallback onUpdate;

  const UpdateCheckDialog({
    super.key,
    required this.currentVersion,
    this.latestVersion,
    this.changelog,
    this.isChecking = false,
    this.hasUpdate = false,
    required this.onCheck,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('版本更新'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('当前版本：'),
                Text(
                  currentVersion,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (latestVersion != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('最新版本：'),
                  Text(
                    latestVersion!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasUpdate ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
            if (hasUpdate) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.new_releases, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '发现新版本！',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (changelog != null && changelog!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '更新内容:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    changelog!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!isChecking)
          TextButton(
            onPressed: onCheck,
            child: const Text('检查更新'),
          ),
        if (isChecking)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (hasUpdate)
          FilledButton(
            onPressed: onUpdate,
            child: const Text('立即更新'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 数据版本管理项
class DataVersionItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final String? version;
  final String? localVersion;
  final bool isLoading;
  final VoidCallback onUpdate;

  const DataVersionItem({
    super.key,
    required this.icon,
    required this.name,
    this.version,
    this.localVersion,
    this.isLoading = false,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUpdate = version != null && localVersion != null && version != localVersion;

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (localVersion != null)
            Text(
              '本地：$localVersion',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          if (version != null)
            Text(
              '远程：$version',
              style: TextStyle(
                fontSize: 12,
                color: hasUpdate ? Colors.green : theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : hasUpdate
              ? FilledButton.tonal(
                  onPressed: onUpdate,
                  child: const Text('更新'),
                )
              : const Icon(Icons.check_circle, color: Colors.green, size: 20),
      onTap: isLoading ? null : onUpdate,
    );
  }
}

/// 更新进度对话框
class UpdateProgressDialog extends StatelessWidget {
  final String message;
  final double? progress;

  const UpdateProgressDialog({
    super.key,
    required this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('更新中...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (progress != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              '${(progress! * 100).toInt()}%',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
      actions: [
        if (progress == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

/// 更新结果提示
class UpdateResultBanner extends StatelessWidget {
  final bool success;
  final String message;

  const UpdateResultBanner({
    super.key,
    required this.success,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: success ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
