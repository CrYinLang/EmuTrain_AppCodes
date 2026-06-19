// widgets/icon_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_settings.dart';
import '../gallery/gallery_page.dart';
import '../widgets/error.dart';

class IconUtils {
  /// 返回路局图标文件名（无扩展名），空字符串返回 null
  static String? getBureauIconFileName(String bureau) {
    if (bureau.isEmpty) return null;
    return bureau; // assets/icon/bureau/<bureau>.png
  }
}

// ==================== 车次图标 Widget ====================
class TrainIconWidget extends StatelessWidget {
  final String model;
  final String number;
  final double size;
  final bool showIcon;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const TrainIconWidget({
    super.key,
    required this.model,
    required this.number,
    this.size = 32,
    this.showIcon = true,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (!settings.showTrainIcons || !showIcon) {
      return SizedBox(width: size, height: size);
    }

    final iconModel = TrainInfo.getTrainIconModel(model, number);
    final cleanName = _removePngExtension(iconModel);
    final assetPath = 'assets/icon/train/$cleanName.png';

    return FutureBuilder<bool>(
      future: _checkAssetExists(assetPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return snapshot.data == true
              ? _buildImageAsset(assetPath)
              : _buildFallbackIcon();
        }
        return _buildLoadingIndicator();
      },
    );
  }

  Future<bool> _checkAssetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (e) {
      logError(from: 'icon_widgets/_checkAssetExists', error: e.toString());
      return false;
    }
  }

  String _removePngExtension(String fileName) {
    if (fileName.toLowerCase().endsWith('.png')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  Widget _buildImageAsset(String assetPath) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor,
      ),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor ?? Colors.grey[200],
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.train, size: size * 0.4, color: Colors.grey[600]),
          if (size > 40)
            Text(
              model,
              style: TextStyle(
                fontSize: size * 0.2,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: backgroundColor ?? Colors.grey[200],
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      ),
    );
  }
}

// ==================== 路局图标 Widget ====================
class BureauIconWidget extends StatelessWidget {
  final String bureau;
  final double size;
  final bool showIcon;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const BureauIconWidget({
    super.key,
    required this.bureau,
    this.size = 32,
    this.showIcon = true,
    this.backgroundColor,
    this.borderRadius,
  });

  Future<bool> _checkImageExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (e) {
      logError(from: 'icon_widgets/_checkImageExists', error: e.toString());
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (!settings.showBureauIcons || !showIcon || bureau.isEmpty) {
      return SizedBox(width: size, height: size);
    }

    final fileName = IconUtils.getBureauIconFileName(bureau);
    if (fileName == null) return SizedBox(width: size, height: size);

    final iconPath = 'assets/icon/bureau/$fileName.png';

    return FutureBuilder<bool>(
      future: _checkImageExists(iconPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == true) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
                color: backgroundColor ?? Colors.transparent,
              ),
              child: Image.asset(
                iconPath,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallbackIcon(),
              ),
            );
          } else {
            return _buildFallbackIcon();
          }
        }
        return _buildLoadingIndicator();
      },
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: Colors.grey[200],
      ),
      child: Icon(
        Icons.account_balance,
        size: size * 0.6,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 8),
        color: Colors.grey[200],
      ),
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
