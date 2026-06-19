import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/particle_background.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoginMode = true;

  // Form Fields Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // 6-digit PIN controllers and focus nodes
  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());

  String _errorMessage = '';
  String _successMessage = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _errorMessage = '';
      _successMessage = '';
      _phoneController.clear();
      _nameController.clear();
      for (var controller in _pinControllers) {
        controller.clear();
      }
    });
  }

  String _getPinValue() {
    return _pinControllers.map((c) => c.text).join();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _errorMessage = '';
      _successMessage = '';
    });

    final phone = _phoneController.text.trim();
    final pin = _getPinValue();

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Phone number is required');
      return;
    }

    if (pin.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of your password');
      return;
    }

    try {
      if (_isLoginMode) {
        await ref.read(authProvider.notifier).login(phone, pin);
        if (mounted) {
          context.go('/');
        }
      } else {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          setState(() => _errorMessage = 'Name is required');
          return;
        }

        await ref.read(authProvider.notifier).register(name, phone, pin);
        setState(() {
          _successMessage = 'Account created! Switching to login...';
        });
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) {
            _switchMode();
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: Stack(
        children: [
          // Particle Background
          const ParticleBackground(),

          // Ambient Glow in bottom-right corner
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkorioColors.primary.withOpacity(0.06),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: SkorioColors.primary.withOpacity(0.06)),
              ),
            ),
          ),

          // Main Screen Scrollable Body
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Logo & Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/skorio-logo.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.sports_soccer,
                                    color: SkorioColors.primary, size: 48),
                          ),
                        ),
                        const SizedBox(width: 12),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'SKO',
                                style: SkorioTextStyles.headlineLg.copyWith(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              TextSpan(
                                text: 'RIO',
                                style: SkorioTextStyles.headlineLg.copyWith(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: SkorioColors.primary,
                                  letterSpacing: -1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Authentication GlassCard Container
                    GlassCard(
                      borderRadius: 20,
                      padding: EdgeInsets.zero,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tab Selector (Login / Register)
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white10,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _TabButton(
                                    label: 'Login',
                                    icon: Icons.login_rounded,
                                    isActive: _isLoginMode,
                                    onTap: () {
                                      if (!_isLoginMode) _switchMode();
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: _TabButton(
                                    label: 'Register',
                                    icon: Icons.person_add_rounded,
                                    isActive: !_isLoginMode,
                                    onTap: () {
                                      if (_isLoginMode) _switchMode();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Page titles matching Next.js App
                                Text(
                                  _isLoginMode
                                      ? "Who's winning tonight?"
                                      : "Join the Game!",
                                  style: SkorioTextStyles.headlineMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isLoginMode
                                      ? "Enter your credentials to join the match center."
                                      : "Create your account and start predicting matches.",
                                  style: SkorioTextStyles.bodyMd.copyWith(
                                    color: SkorioColors.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // REGISTER MODE: Name Field
                                if (!_isLoginMode) ...[
                                  _InputLabel(label: "Full Name"),
                                  const SizedBox(height: 8),
                                  _CustomTextField(
                                    controller: _nameController,
                                    hintText: "Enter your name",
                                    keyboardType: TextInputType.name,
                                    enabled: !isLoading,
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // Phone Input Field
                                _InputLabel(label: "Phone Number"),
                                const SizedBox(height: 8),
                                _CustomTextField(
                                  controller: _phoneController,
                                  hintText: "Enter your phone number",
                                  keyboardType: TextInputType.phone,
                                  enabled: !isLoading,
                                ),
                                const SizedBox(height: 18),

                                // 6-Digit PIN Fields
                                _InputLabel(label: "6-Digit Password"),
                                if (!_isLoginMode) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Choose 6 digits you'll remember",
                                    style: SkorioTextStyles.labelSm.copyWith(
                                      color: SkorioColors.outline,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),

                                // 6 PIN Fields Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    return SizedBox(
                                      width: 42,
                                      height: 48,
                                      child: _PinDigitBox(
                                        controller: _pinControllers[index],
                                        focusNode: _pinFocusNodes[index],
                                        onChanged: (value) {
                                          if (value.isNotEmpty && index < 5) {
                                            _pinFocusNodes[index + 1].requestFocus();
                                          }
                                        },
                                        onBackspace: () {
                                          if (index > 0) {
                                            _pinControllers[index - 1].clear();
                                            _pinFocusNodes[index - 1].requestFocus();
                                          }
                                        },
                                        enabled: !isLoading,
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 24),

                                // Error Notification display
                                if (_errorMessage.isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      border: Border.all(
                                          color: Colors.red.withOpacity(0.2)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _errorMessage,
                                      style: SkorioTextStyles.bodyMd.copyWith(
                                        color: Colors.redAccent[100],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Success Notification display
                                if (_successMessage.isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: SkorioColors.secondary.withOpacity(0.08),
                                      border: Border.all(
                                          color: SkorioColors.secondary.withOpacity(0.2)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _successMessage,
                                      style: SkorioTextStyles.bodyMd.copyWith(
                                        color: SkorioColors.secondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Gradient Action Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          SkorioColors.primaryContainer,
                                          SkorioColors.primary,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: SkorioColors.primary.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : _handleSubmit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: isLoading
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(Colors.white),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  _isLoginMode
                                                      ? 'Authenticating...'
                                                      : 'Creating Account...',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              _isLoginMode
                                                  ? 'Login'
                                                  : 'Create Account',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Form Footer Links
                                Container(
                                  padding: const EdgeInsets.only(top: 16),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.white10,
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          // Forgot Password logic placeholder
                                        },
                                        child: Text(
                                          'Forgot Password?',
                                          style: SkorioTextStyles.labelMd.copyWith(
                                            color: SkorioColors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _switchMode,
                                        child: Text(
                                          _isLoginMode
                                              ? 'New Player? Register'
                                              : 'Have Account? Login',
                                          style: SkorioTextStyles.labelMd.copyWith(
                                            color: SkorioColors.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Privacy Terms Agreement Footer
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: SkorioTextStyles.labelSm.copyWith(
                          color: SkorioColors.outline,
                          fontSize: 11,
                        ),
                        children: [
                          const TextSpan(
                              text: 'By continuing, you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: SkorioColors.onSurfaceVariant,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? SkorioColors.primary.withOpacity(0.04) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? SkorioColors.primary : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? SkorioColors.primary : SkorioColors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: SkorioTextStyles.labelMd.copyWith(
                color: isActive ? SkorioColors.primary : SkorioColors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String label;
  const _InputLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        label,
        style: SkorioTextStyles.labelMd.copyWith(
          color: SkorioColors.onSurfaceVariant,
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final bool enabled;

  const _CustomTextField({
    required this.controller,
    required this.hintText,
    required this.keyboardType,
    required this.enabled,
  });

  @override
  State<_CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<_CustomTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B20), // surface-container-low
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isFocused
              ? SkorioColors.primary
              : SkorioColors.outlineVariant,
          width: 1.0,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: SkorioColors.primary.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        enabled: widget.enabled,
        style: SkorioTextStyles.bodyMd.copyWith(
          color: Colors.white,
          fontSize: 14.0,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: SkorioColors.outline.withOpacity(0.5),
            fontSize: 14.0,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _PinDigitBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  final bool enabled;

  const _PinDigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
    required this.enabled,
  });

  @override
  State<_PinDigitBox> createState() => _PinDigitBoxState();
}

class _PinDigitBoxState extends State<_PinDigitBox> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() {
        _isFocused = widget.focusNode.hasFocus;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(), // Dummy focus node for intercepting backspace events
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (widget.controller.text.isEmpty) {
            widget.onBackspace();
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B20), // surface-container-low
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isFocused
                ? SkorioColors.primary
                : SkorioColors.outlineVariant,
            width: 1.0,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.number,
          enabled: widget.enabled,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: SkorioTextStyles.headlineMd.copyWith(
            color: SkorioColors.primary,
            fontWeight: FontWeight.bold,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: (val) {
            // Keep only the last typed digit
            if (val.length > 1) {
              widget.controller.text = val.substring(val.length - 1);
              widget.controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: widget.controller.text.length));
            }
            widget.onChanged(widget.controller.text);
          },
        ),
      ),
    );
  }
}
