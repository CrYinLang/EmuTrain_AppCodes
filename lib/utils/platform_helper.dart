// lib/utils/platform_helper.dart
import 'package:flutter/foundation.dart';

/// 是否为 Web 平台
bool get isWeb => kIsWeb;

/// 是否为桌面/移动原生平台（可以访问文件系统）
bool get isNative => !kIsWeb;
