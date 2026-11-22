import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'board_screen.dart';
import 'board_service.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.user,
    required this.auth,
  });

  final User user;
  final AuthService auth;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  final _board = BoardService();
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  late Future<Map<String, dynamic>?> _profile;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = _board.loadUserRecord(widget.user.uid);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _reloadProfile() {
    setState(() {
      _profile = _board.loadUserRecord(widget.user.uid);
    });
  }

  Future<void> _saveProfile() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _board.saveUserRecord(
        widget.user,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        role: 'member',
      );

      if (!mounted) return;
      _reloadProfile();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'permission-denied'
            ? 'Firestore denied the profile save. Check the profile rules.'
            : 'Your account is signed in. Try saving your profile again.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.auth.signOut();
    } on FirebaseAuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Try again.')),
      );
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter a name.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load your profile.'),
                  TextButton(
                    onPressed: _reloadProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final profile = snapshot.data;
          if (profile != null &&
              profile['uid'] == widget.user.uid &&
              profile['firstName'] is String &&
              profile['lastName'] is String &&
              profile['role'] is String &&
              profile['registrationDateTime'] != null) {
            return BoardScreen(
              board: _board,
              uid: widget.user.uid,
              authorName: '${profile['firstName']} ${profile['lastName']}',
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Complete profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                TextFormField(
                  controller: _firstName,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: _validateName,
                ),
                TextFormField(
                  controller: _lastName,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
                if (_error != null) Text(_error!),
                FilledButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: Text(_saving ? 'Saving...' : 'Save profile'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}