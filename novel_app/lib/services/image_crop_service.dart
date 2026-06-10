import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as path;
import '../utils/format_utils.dart';
import 'logger_service.dart';

/// 图片裁剪服务
class ImageCropService {
  static const LogCategory _category = LogCategory.ui;
  static const List<String> _tags = ['image-crop'];

  /// 裁剪图片为头像
  ///
  /// [imageFile] 要裁剪的图片文件
  ///
  /// 返回裁剪后的文件，如果用户取消或裁剪失败则返回 null
  static Future<File?> cropImageForAvatar(File imageFile) async {
    try {
      LoggerService.instance.d('开始裁剪图片: ${imageFile.path}', category: _category, tags: _tags);

      // 检查文件是否存在
      if (!await imageFile.exists()) {
        LoggerService.instance.e('图片文件不存在: ${imageFile.path}', category: _category, tags: _tags);
        return null;
      }

      // 获取临时目录（未使用但保留用于扩展）
      // final tempDir = await getTemporaryDirectory();

      // 配置裁剪参数 - 直接进入裁剪模式，减少确认步骤
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1.0, ratioY: 1.0), // 强制方形裁剪
        maxWidth: 512,
        maxHeight: 512, // 头像最大尺寸
        compressQuality: 85, // 图片质量
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '框选头像范围',
            // image_cropper 走原生 Android UI，Flutter Theme 不可达，
            // 因此 toolbarColor 保持硬编码（与 Material Blue 500 一致）。
            toolbarColor: const Color(0xFF2196F3),
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black87,
            hideBottomControls: false,
            lockAspectRatio: true, // 锁定比例
            initAspectRatio: CropAspectRatioPreset.square, // 直接预设为方形
          ),
          IOSUiSettings(
            title: '框选头像范围',
            cancelButtonTitle: '取消',
            doneButtonTitle: '确定',
            aspectRatioLockEnabled: true, // 锁定比例
            resetAspectRatioEnabled: false, // 禁用重置比例
            rotateButtonsHidden: true, // 隐藏旋转按钮，简化界面
            rotateClockwiseButtonHidden: true,
          ),
        ],
      );

      if (croppedFile != null) {
        final croppedFileObj = File(croppedFile.path);
        final croppedFileSize = await croppedFileObj.length();
        LoggerService.instance.i('图片裁剪成功: ${croppedFile.path}, 文件大小: $croppedFileSize bytes', category: _category, tags: _tags);

        return croppedFileObj;
      } else {
        LoggerService.instance.i('用户取消裁剪操作', category: _category, tags: _tags);
        return null;
      }
    } catch (e) {
      LoggerService.instance.e('图片裁剪失败: $e', category: _category, tags: _tags);
      return null;
    }
  }

  /// 保存裁剪后的图片到指定目录
  ///
  /// [croppedFile] 裁剪后的图片文件
  /// [targetDir] 目标目录
  /// [filename] 目标文件名（不含扩展名）
  ///
  /// 返回保存后的文件路径
  static Future<String?> saveCroppedImage(
    File croppedFile,
    Directory targetDir,
    String filename,
  ) async {
    try {
      // 确保目标目录存在
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // 生成目标文件路径
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetFilename = '${filename}_${timestamp}_cropped.jpg';
      final targetPath = path.join(targetDir.path, targetFilename);

      // 复制文件
      await croppedFile.copy(targetPath);

      LoggerService.instance.i('裁剪图片保存成功: $targetPath', category: _category, tags: _tags);
      return targetPath;
    } catch (e) {
      LoggerService.instance.e('保存裁剪图片失败: $e', category: _category, tags: _tags);
      return null;
    }
  }

  /// 检查图片是否需要裁剪（用于头像）
  ///
  /// [imageFile] 要检查的图片文件
  ///
  /// 返回是否建议裁剪
  static Future<bool> shouldCropForAvatar(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        return false;
      }

      // 这里可以添加更复杂的逻辑来判断是否需要裁剪
      // 例如检查图片比例、尺寸等
      // 目前默认返回 true，建议用户进行裁剪

      return true;
    } catch (e) {
      LoggerService.instance.e('检查图片裁剪需求失败: $e', category: _category, tags: _tags);
      return false;
    }
  }

  /// 获取图片信息
  ///
  /// [imageFile] 图片文件
  ///
  /// 返回图片信息对象
  static Future<Map<String, dynamic>?> getImageInfo(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      final fileName = path.basename(imageFile.path);
      final lastModified = await imageFile.lastModified();

      return {
        'fileName': fileName,
        'filePath': imageFile.path,
        'fileSize': fileSize,
        'lastModified': lastModified,
        'fileSizeFormatted': FormatUtils.formatFileSize(fileSize),
      };
    } catch (e) {
      LoggerService.instance.e('获取图片信息失败: $e', category: _category, tags: _tags);
      return null;
    }
  }
}
