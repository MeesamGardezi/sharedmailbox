import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyController = TextEditingController();
  
  // Focus nodes for keyboard navigation
  final _companyFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _companyController.dispose();
    _companyFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        // Sign Up
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final user = userCredential.user!;

        // Create Company
        final companyRef = await FirebaseFirestore.instance.collection('companies').add({
          'name': _companyController.text.trim(),
          'ownerId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create User Profile
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'companyId': companyRef.id,
          'role': 'owner',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 48, color: Color(0xFF6366F1)),
                  const SizedBox(height: 24),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Sign in to your account' : 'Start your company workspace',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14),
                      ),
                    ),

                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _companyController,
                      focusNode: _companyFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Company Name',
                        hintText: 'Acme Inc.',
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'you@company.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    validator: (value) => value == null || !value.contains('@') ? 'Invalid email' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: '••••••••',
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                    validator: (value) => value == null || value.length < 6 ? 'Min 6 chars' : null,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isLogin ? 'Sign In' : 'Create Account'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = null;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(_isLogin ? "Don't have an account? Create Company" : "Already have an account? Sign In"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
