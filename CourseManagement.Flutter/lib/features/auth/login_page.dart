import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'auth_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({this.returnPath, super.key});

  final String? returnPath;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final success = await auth.login(_email.text, _password.text);
    if (success && mounted) context.go(widget.returnPath ?? '/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return AuthShell(
      title: 'مرحبًا بعودتك',
      subtitle: 'سجّل دخولك وتابع رحلتك التعليمية من حيث توقفت.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.errorMessage != null)
              _ErrorBanner(message: auth.errorMessage!),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'أدخل البريد الإلكتروني';
                }
                if (!value.contains('@')) return 'تحقق من البريد الإلكتروني';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              enableSuggestions: false,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'أدخل كلمة المرور' : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: auth.isBusy ? null : _submit,
              icon: auth.isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_back_rounded),
              label: Text(auth.isBusy ? 'جارٍ التحقق...' : 'تسجيل الدخول'),
            ),
            const SizedBox(height: 20),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    'ليس لديك حساب؟',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  TextButton(
                    onPressed: auth.isBusy
                        ? null
                        : () => context.go(
                            Uri(
                              path: '/register',
                              queryParameters: {
                                if (widget.returnPath != null)
                                  'return': widget.returnPath!,
                              },
                            ).toString(),
                          ),
                    child: const Text('أنشئ حسابك'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2F5),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: const Color(0xFFFFDCE5)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.danger,
          size: 19,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Color(0xFFB33855),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
