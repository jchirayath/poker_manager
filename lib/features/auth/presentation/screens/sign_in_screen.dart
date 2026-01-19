import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../common/widgets/app_drawer.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final controller = ref.read(authControllerProvider);
    final result = await controller.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    result.when(
      success: (user) {
        context.go(RouteConstants.home);
      },
      failure: (message, exception) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      drawer: const AppDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Hamburger menu button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: colorScheme.onSurface,
                        ),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        tooltip: 'Menu',
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo and App Name
                          _buildHeader(colorScheme),
                          const SizedBox(height: 16),

                          // App Description
                          _buildDescription(theme, colorScheme),
                          const SizedBox(height: 32),

                          // Login Card
                          _buildLoginCard(theme, colorScheme),
                          const SizedBox(height: 24),

                          // Sign Up Link
                          _buildSignUpLink(colorScheme),
                          const SizedBox(height: 32),

                          // Version
                          if (_appVersion.isNotEmpty)
                            Text(
                              _appVersion,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          SizedBox(height: size.height * 0.02),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      children: [
        // Logo with shadow effect
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SvgPicture.asset(
            'assets/images/img_app_logo.svg',
            width: 80,
            height: 80,
          ),
        ),
        const SizedBox(height: 24),
        // App Name
        Text(
          AppConstants.appNameWithBeta,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppConstants.appTagline,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Icon(
          //   Icons.casino_outlined,
          //   size: 28,
          //   color: colorScheme.secondary,
          // ),
          const SizedBox(height: 8),
          Text(
            'Organize poker nights with friends, track buy-ins, manage groups, and settle up effortlessly.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildFeatureChip(Icons.games, 'Games', colorScheme),
              _buildFeatureChip(Icons.group, 'Groups', colorScheme),
              _buildFeatureChip(Icons.trending_up, 'Stats', colorScheme),
              _buildFeatureChip(Icons.payments, 'Settle', colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, ColorScheme colorScheme) {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: colorScheme.primary),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 4,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome Back',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to access your groups and games',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: InputValidators.validateEmail,
              ),
              const SizedBox(height: 16),
              // Password Field
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outlined, color: colorScheme.primary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signIn(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(RouteConstants.forgotPassword),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Sign In Button
              FilledButton(
                onPressed: _isLoading ? null : _signIn,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink(ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Register to track your groups, games, and stats across devices',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onTertiaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go(RouteConstants.signUp),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text.rich(
            TextSpan(
              text: "Don't have an account? ",
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              children: [
                TextSpan(
                  text: 'Sign Up',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
