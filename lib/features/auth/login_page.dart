import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../state/app_scope.dart';
import '../../theme/app_semantic_colors.dart';
import '../../widgets/app_dialog.dart';

/// 统一身份认证登录页。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = AppScope.read(context);
    final message = await controller.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (message != null) {
      await AppDialog.show(
        context,
        title: '登录失败',
        message: message,
        destructive: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final controller = AppScope.of(context);

    return Scaffold(
      backgroundColor: semantic.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: semantic.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          size: 34, color: semantic.accent),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '南航课程表',
                      style: context.texts.headlineSmall?.copyWith(
                        color: semantic.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '统一身份认证登录',
                      style: context.texts.bodyMedium?.copyWith(
                        color: semantic.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _usernameController,
                      keyboardType: TextInputType.number,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '学号',
                        hintText: '请输入学号',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入学号' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: '密码',
                        hintText: '统一身份认证密码',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          color: semantic.textTertiary,
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '请输入密码' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: controller.busy ? null : _submit,
                      child: controller.busy
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: semantic.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(controller.status ?? '正在登录'),
                              ],
                            )
                          : const Text('登录'),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '凭据仅保存在本机，用于课程表自动更新与上课提醒；'
                      '课表数据来自学校教务系统，仅本地缓存。',
                      style: context.texts.bodySmall?.copyWith(
                        color: semantic.textTertiary,
                        height: 1.5,
                      ),
                    ),
                    if (controller.error != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        controller.error!,
                        style: context.texts.bodySmall?.copyWith(
                          color: semantic.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const _VersionLabel(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 登录页底部版本标识：便于确认实际安装的是哪一次构建。
class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final label = info == null ? '' : 'v${info.version} (${info.buildNumber})';
        if (label.isEmpty) return const SizedBox.shrink();
        return Center(
          child: Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: context.semantic.textTertiary,
              fontSize: 11,
            ),
          ),
        );
      },
    );
  }
}
