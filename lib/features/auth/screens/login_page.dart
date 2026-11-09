import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/core/constants/app_colors.dart';
import 'package:smart_factory_qc/core/theme/app_spacing.dart';
import 'package:smart_factory_qc/features/auth/providers/sign_in_controller.dart';
import 'package:smart_factory_qc/features/auth/widgets/login_text_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
    this.onSignedIn,
    this.onForgotPassword,
  });

  /// Called after a successful sign-in (e.g. navigate to the app shell).
  final VoidCallback? onSignedIn;
  final VoidCallback? onForgotPassword;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(signInControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your work email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password' : null;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(signInControllerProvider, (previous, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Sign in failed. Check your email, password, and network '
                'connection, then try again.',
              ),
            ),
          );
      } else if ((previous?.isLoading ?? false) && next is AsyncData<void>) {
        widget.onSignedIn?.call();
      }
    });

    final isLoading = ref.watch(signInControllerProvider).isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const _Header(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x3,
                  AppSpacing.x4,
                  AppSpacing.x3,
                  AppSpacing.x3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Hero(),
                    const SizedBox(height: AppSpacing.x4),
                    const SectionLabel('Sign in to Plant 01'),
                    const SizedBox(height: AppSpacing.x2),
                    _buildForm(isLoading),
                    const SizedBox(height: AppSpacing.x1),
                    _buildForgotPassword(isLoading),
                    const SizedBox(height: AppSpacing.x2),
                    _SignInButton(isLoading: isLoading, onPressed: _submit),
                    const SizedBox(height: AppSpacing.x3),
                    const _FooterNote(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isLoading) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Work email'),
            const SizedBox(height: AppSpacing.x1),
            LoginTextField(
              controller: _emailController,
              enabled: !isLoading,
              hint: 'name@company.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
              suffixIcon: const Padding(
                padding: EdgeInsets.all(AppSpacing.x2),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 24,
                  color: AppColors.slate600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            const FieldLabel('Password'),
            const SizedBox(height: AppSpacing.x1),
            LoginTextField(
              controller: _passwordController,
              enabled: !isLoading,
              hint: 'Enter your password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              validator: _validatePassword,
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.x6,
                  minHeight: AppSpacing.x6,
                ),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 24,
                  color: AppColors.slate600,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForgotPassword(bool isLoading) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: isLoading ? null : widget.onForgotPassword,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(AppSpacing.x6, AppSpacing.x6),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('Forgot password?'),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Page sections (private to this screen)
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x3,
        topInset + AppSpacing.x2,
        AppSpacing.x3,
        AppSpacing.x2,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Factory',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppColors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'QUALITY & INVENTORY',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
              color: AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconBox(icon: Icons.factory_outlined),
        SizedBox(height: AppSpacing.x3),
        Text(
          'Ready for your shift.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.5,
            color: AppColors.navy,
          ),
        ),
        SizedBox(height: AppSpacing.x2),
        Text(
          'Paperless inspections. Traceable materials. One connected shop floor.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppColors.slate600,
          ),
        ),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.x6,
      height: AppSpacing.x6,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Icon(icon, size: 24, color: AppColors.accent),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.x7,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.6),
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              )
            : const Icon(Icons.arrow_forward_rounded, size: 24),
        label: const Text('Sign in'),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Use your Northworks account. Need access? Contact your shift supervisor.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.5,
            color: AppColors.slate600,
          ),
        ),
        SizedBox(height: AppSpacing.x2),
        Text(
          'NORTHWORKS   /   SECURE SHOP-FLOOR ACCESS',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: AppColors.slate500,
          ),
        ),
      ],
    );
  }
}
