import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'profile_gate.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authState,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Could not read sign-in status. Restart and retry.'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return LoginScreen(auth: _auth);
        }

        return ProfileGate(
          key: ValueKey(user.uid),
          user: user,
          auth: _auth,
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_registering) {
        await widget.auth.register(
          email: _email.text,
          password: _password.text,
        );
      } else {
        await widget.auth.signIn(
          email: _email.text,
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = switch (error.code) {
          'email-already-in-use' => 'That email already has an account.',
          'invalid-email' => 'Enter a valid email address.',
          'weak-password' => 'Choose a stronger password.',
          'invalid-credential' ||
          'wrong-password' ||
          'user-not-found' => 'Check your email and password.',
          'network-request-failed' => 'Check your internet and try again.',
          _ => 'Could not complete the request. Try again.',
        };
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = _registering ? 'Create account' : 'Sign in';

    return Scaffold(
      appBar: AppBar(title: Text(action)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _email,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (value) {
                final email = value?.trim() ?? '';
                final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!pattern.hasMatch(email)) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (value) {
                if ((value ?? '').length < 6) {
                  return 'Enter at least 6 characters.';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Please wait...' : action),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _registering = !_registering;
                        _error = null;
                      });
                    },
              child: Text(
                _registering ? 'Back to sign in' : 'Create an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}