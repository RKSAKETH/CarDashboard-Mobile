
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithGoogle();
      // Navigation is handled by auth wrapper
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_isLogin && !_agreedToTerms) {
      _showError(AppLocalizations.of(context)!.pleaseAgreeTerms);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await AuthService().signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await AuthService().registerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _usernameController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Image
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1542282088-fe8426682b8f?q=80&w=1000&auto=format&fit=crop',
                    ),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0),
                ),
              ),
              
              const SizedBox(height: 32),
              
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isLogin) ...[
                      _buildLabel(l10n.username),
                      _buildTextField(
                        controller: _usernameController,
                        hintText: l10n.createUsername,
                        icon: Icons.person_outline,
                        validator: (value) => 
                          value!.isEmpty ? l10n.enterUsername : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    _buildLabel(l10n.emailAddress),
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'user@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return l10n.enterEmail;
                        if (!value.contains('@')) return l10n.enterValidEmail;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildLabel(l10n.password),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: '••••••••',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      isPassword: true,
                      onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                      validator: (value) {
                        if (value == null || value.isEmpty) return l10n.enterPassword;
                        if (value.length < 6) return l10n.passwordTooShort;
                        return null;
                      },
                    ),
                    
                    if (!_isLogin) ...[
                      const SizedBox(height: 16),
                      _buildLabel(l10n.confirmPassword),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        isPassword: true,
                        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (value) {
                          if (value != _passwordController.text) return l10n.passwordsDoNotMatch;
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              activeColor: const Color(0xFF00FF00),
                              checkColor: Colors.black,
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.agreeTerms,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF00FF00)))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isLogin ? l10n.login : l10n.signUp,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: Colors.grey.withOpacity(0.3))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n.orContinueWith,
                            style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 12),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: Colors.grey.withOpacity(0.3))),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         _buildSocialButton(
                          label: l10n.google,
                          iconUrl: 'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                          onPressed: _handleGoogleSignIn,
                        ),
                      ],
                    ),
                  ],
                ),
                
              const SizedBox(height: 24),
              
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isLogin = !_isLogin;
                    _formKey.currentState?.reset();
                    _emailController.clear();
                    _passwordController.clear();
                    _confirmPasswordController.clear();
                    _usernameController.clear();
                    _agreedToTerms = false;
                  }),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                      children: [
                        TextSpan(text: _isLogin ? "${l10n.dontHaveAccount} " : "${l10n.alreadyHaveAccount} "),
                        TextSpan(
                          text: _isLogin ? l10n.signUp : l10n.login,
                          style: const TextStyle(
                            color: Color(0xFF00FF00),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          errorStyle: const TextStyle(height: 0, color: Colors.transparent), // Hide default error text
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required String iconUrl,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              iconUrl,
              height: 24,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.login, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
