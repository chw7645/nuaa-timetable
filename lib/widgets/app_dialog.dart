import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_semantic_colors.dart';

/// 全应用弹窗的唯一入口。
///
/// 业务代码禁止直接调用 `showDialog`：只要所有弹窗都走这里，
/// 深色模式下就不会出现"文字颜色写死、背景随主题变化"的错配。
class AppDialog {
  AppDialog._();

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '知道了',
    bool destructive = false,
  }) async {
    final semantic = context.semantic;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.semantic.dialogBackground,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: ctx.texts.titleMedium?.copyWith(
            color: ctx.semantic.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: ctx.texts.bodyMedium?.copyWith(
            color: ctx.semantic.textSecondary,
            fontSize: 15,
            height: 1.55,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? semantic.danger : ctx.semantic.accent,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 返回 `true` 表示用户确认。
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '确定',
    String cancelText = '取消',
    bool destructive = false,
  }) async {
    final semantic = context.semantic;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.semantic.dialogBackground,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: ctx.texts.titleMedium?.copyWith(
            color: ctx.semantic.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: ctx.texts.bodyMedium?.copyWith(
            color: ctx.semantic.textSecondary,
            fontSize: 15,
            height: 1.55,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: ctx.semantic.textSecondary,
            ),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor:
                  destructive ? semantic.danger : ctx.semantic.accent,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
