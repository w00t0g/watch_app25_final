import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screen for login and register
class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});
  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  // controllers for user input
  final _email = TextEditingController();
  final _pass = TextEditingController();

  // error message (shown in UI if something fails)
  String _error = '';

  // try login with FirebaseAuth
  Future<void> _login() async {
    setState(() => _error = '');
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
    } on FirebaseAuthException catch (e) {
      // show error in state
      setState(() => _error = e.message ?? e.code);
    }
  }

  // try register with FirebaseAuth
  Future<void> _register() async {
    setState(() => _error = '');
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
    } on FirebaseAuthException catch (e) {
      // show error in state
      setState(() => _error = e.message ?? e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login / Registrieren')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // email input
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'E-Mail'),
            keyboardType: TextInputType.emailAddress,
          ),

          // password input
          TextField(
            controller: _pass,
            decoration: const InputDecoration(labelText: 'Passwort'),
            obscureText: true,
          ),

          const SizedBox(height: 12),

          // error message if login/register fails
          if (_error.isNotEmpty)
            Text(_error, style: const TextStyle(color: Colors.red)),

          const SizedBox(height: 12),

          // buttons: login + register
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: _login,
                child: const Text('Login'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _register,
                child: const Text('Registrieren'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
