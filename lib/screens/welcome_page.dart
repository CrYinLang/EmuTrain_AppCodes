import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeGate extends StatefulWidget {
  final Widget child;

  const WelcomeGate({super.key, required this.child});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  static const _acceptedKey = 'welcome_user_agreement_accepted_v1';

  bool _loading = true;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _loadAcceptedState();
  }

  Future<void> _loadAcceptedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _accepted = prefs.getBool(_acceptedKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _completeWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_acceptedKey, true);
    if (!mounted) return;
    setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_accepted) return widget.child;

    return WelcomePage(onAccepted: _completeWelcome);
  }
}

class WelcomePage extends StatefulWidget {
  final Future<void> Function() onAccepted;

  const WelcomePage({super.key, required this.onAccepted});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _agreementAccepted = false;
  bool _submitting = false;

  Future<void> _showWelcomeDialog() async {
    setState(() => _submitting = true);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('欢迎使用 EmuTrain'),
        content: const Text('感谢使用 EmuTrain，点击确定进入软件。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    await widget.onAccepted();
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              shrinkWrap: true,
              children: [
                Center(
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 88,
                    height: 88,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.train, size: 80, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '欢迎使用 EmuTrain',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '在开始之前，请阅读并同意用户协议。EmuTrain 会使用网络数据、远程版本信息和本地存储来提供查询、更新与旅途记录功能。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                _AgreementPanel(colorScheme: colorScheme),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _agreementAccepted,
                  onChanged: _submitting
                      ? null
                      : (value) {
                          setState(() => _agreementAccepted = value ?? false);
                        },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('我已阅读并同意用户协议'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _agreementAccepted && !_submitting
                      ? _showWelcomeDialog
                      : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('同意并继续'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgreementPanel extends StatelessWidget {
  final ColorScheme colorScheme;

  const _AgreementPanel({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: const SingleChildScrollView(
        child: Text(
          '用户协议摘要\n\n'
          '1. EmuTrain 不是 12306 官方应用，也不是铁路部门官方工具，查询结果仅供参考。\n\n'
          '2. 应用会访问网络，用于车次、车号、车站大屏、版本检查、公告获取和数据更新等功能。\n\n'
          '3. 应用会在本机保存旅途记录、设置项、数据版本和用户协议确认状态。\n\n'
          '4. GPS 速度计需要定位权限，相关数据仅用于速度、距离和轨迹记录功能。\n\n'
          '5. EmuTrain 系列软件配有云控系统，包括远程指令和远程信息推送功能。如介意，请不要继续使用。\n\n'
          '6. 涉及实际出行时，请以 12306、车站公告和现场信息为准。',
          style: TextStyle(height: 1.45),
        ),
      ),
    );
  }
}
