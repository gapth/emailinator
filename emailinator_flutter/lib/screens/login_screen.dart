import 'package:flutter/material.dart';
import 'package:emailinator_flutter/widgets/submit_on_enter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  final _debounced = DebouncedSubmit();

  void _attemptSubmit() {
    FocusScope.of(context).unfocus();
    _debounced.attempt(_signIn, isLoading: _loading);
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
      });
      try {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (response.user != null && mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An unexpected error occurred.')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    _attemptSubmit();
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SubmitOnEnter(
                  enabled: !_loading,
                  onSubmit: _attemptSubmit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _loading ? null : _attemptSubmit,
                          child: const Text('Sign In'),
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/change-password'),
                  child: const Text('Change Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
