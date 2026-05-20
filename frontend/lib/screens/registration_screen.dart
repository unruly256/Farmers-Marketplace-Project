import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'farmer_dashboard.dart';
import 'buyer_dashboard.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ninController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _selectedRole = 'farmer';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ninController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Passwords do not match.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final response = await ApiService.register(
      _nameController.text.trim(),
      _phoneController.text.trim(),
      "Kampala, Central Region",
      _selectedRole,
      _passwordController.text.trim(),
      _confirmPasswordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['status'] == 'success') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', _selectedRole);
      await prefs.setString('userName', _nameController.text.trim());
      await prefs.setString('userPhone', _phoneController.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Registration successful!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

      if (_selectedRole == 'farmer') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const FarmerDashboard()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const BuyerDashboard()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Registration failed.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  Widget _buildRoleTile({
    required String roleValue,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedRole == roleValue;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = roleValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      color.withOpacity(isDark ? 0.26 : 0.18),
                      color.withOpacity(isDark ? 0.12 : 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected
                ? null
                : (isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.white.withOpacity(0.92)),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06)),
              width: isSelected ? 1.6 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? color.withOpacity(0.16)
                    : (isDark
                        ? Colors.black.withOpacity(0.18)
                        : Colors.black.withOpacity(0.04)),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111B15),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? color
                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isConfirmPassword = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF161616);
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600;
    final fillColor = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.025);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);
    final accent =
        _selectedRole == 'farmer' ? Colors.green.shade700 : Colors.orange.shade600;

    bool obscure = false;
    if (isPassword) obscure = _obscurePassword;
    if (isConfirmPassword) obscure = _obscureConfirmPassword;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        obscureText: (isPassword || isConfirmPassword) ? obscure : false,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: hintColor),
          labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: accent),
          suffixIcon: (isPassword || isConfirmPassword)
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      if (isPassword) {
                        _obscurePassword = !_obscurePassword;
                      }
                      if (isConfirmPassword) {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      }
                    });
                  },
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: hintColor,
                  ),
                )
              : null,
          filled: true,
          fillColor: fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: borderColor, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: accent, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.red.shade400,
              width: 1.2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.red.shade600,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F8F6);
    final cardColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.86);
    final textColor = isDark ? Colors.white : const Color(0xFF111B15);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final accent =
        _selectedRole == 'farmer' ? Colors.green.shade700 : Colors.orange.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -30,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade700.withOpacity(0.12),
                ),
              ),
            ),
            Positioned(
              top: 140,
              right: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade600.withOpacity(0.10),
                ),
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.04),
                    ),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.85),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.eco_rounded,
                          color: accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create your SAMS Market account',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Join as a farmer or buyer',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose your role, create your account, and start trading fresh produce with confidence.',
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildRoleTile(
                        roleValue: 'farmer',
                        title: 'Farmer',
                        subtitle: 'Sell produce directly to buyers.',
                        icon: Icons.agriculture_rounded,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 12),
                      _buildRoleTile(
                        roleValue: 'buyer',
                        title: 'Buyer',
                        subtitle: 'Purchase fresh produce in bulk.',
                        icon: Icons.shopping_basket_rounded,
                        color: Colors.orange.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.white.withOpacity(0.9),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.28)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Account details',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedRole == 'farmer'
                                    ? 'Tell us about your farmer identity and secure your selling account.'
                                    : 'Set up your buyer account and start sourcing produce seamlessly.',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12.8,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 22),
                              _buildTextField(
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                icon: Icons.person_outline_rounded,
                                controller: _nameController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Full name is required';
                                  }
                                  return null;
                                },
                              ),
                              _buildTextField(
                                label: 'Email Address',
                                hint: 'Enter your email address',
                                icon: Icons.email_outlined,
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Email address is required';
                                  }
                                  return null;
                                },
                              ),
                              _buildTextField(
                                label: 'Phone Number',
                                hint: 'Enter your phone number',
                                icon: Icons.phone_outlined,
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Phone number is required';
                                  }
                                  return null;
                                },
                              ),
                              if (_selectedRole == 'farmer')
                                _buildTextField(
                                  label: 'National ID Number',
                                  hint: 'Enter your NIN',
                                  icon: Icons.badge_outlined,
                                  controller: _ninController,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'National ID Number is required';
                                    }
                                    return null;
                                  },
                                ),
                              _buildTextField(
                                label: 'Password',
                                hint: 'Create a strong password',
                                icon: Icons.lock_outline_rounded,
                                controller: _passwordController,
                                isPassword: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (value.length < 4) {
                                    return 'Password is too short';
                                  }
                                  return null;
                                },
                              ),
                              _buildTextField(
                                label: 'Confirm Password',
                                hint: 'Re-enter your password',
                                icon: Icons.lock_person_outlined,
                                controller: _confirmPasswordController,
                                isConfirmPassword: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _handleRegistration,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.6,
                                          ),
                                        )
                                      : Text(
                                          _selectedRole == 'farmer'
                                              ? 'Register as Farmer'
                                              : 'Register as Buyer',
                                          style: const TextStyle(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 13.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: accent,
                              fontSize: 13.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}