import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'auth_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await context.read<AuthController>().register(
      _name.text,
      _email.text,
      _password.text,
    );
    if (success && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return AuthShell(
      title: 'أنشئ حسابك',
      subtitle: 'ابدأ التعلم في دقائق، واحفظ مسارك في مكان واحد.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.errorMessage != null)
              Container(
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
                        auth.errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFB33855),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => value == null || value.trim().length < 2
                  ? 'اكتب اسمًا من حرفين على الأقل'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) => value == null || !value.contains('@')
                  ? 'أدخل بريدًا إلكترونيًا صحيحًا'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                hintText: '8 أحرف على الأقل',
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
              validator: (value) => value == null || value.length < 8
                  ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              validator: (value) =>
                  value != _password.text ? 'كلمتا المرور غير متطابقتين' : null,
            ),
            const SizedBox(height: 22),
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
                  : const Icon(Icons.rocket_launch_rounded),
              label: Text(
                auth.isBusy ? 'جارٍ إنشاء الحساب...' : 'إنشاء الحساب',
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    'لديك حساب؟',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  TextButton(
                    onPressed: auth.isBusy ? null : () => context.go('/login'),
                    child: const Text('سجّل الدخول'),
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
