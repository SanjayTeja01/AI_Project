import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campus_gaurd_final/l10n/app_localizations.dart';
import 'package:campus_gaurd_final/app_bar_language_selector.dart';
import 'package:campus_gaurd_final/language_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _username = '';
  String _email = '';
  String _mobileNumber = '';
  bool _isLoading = true;
  bool _isEditing = false;
  final _usernameController = TextEditingController();
  final _mobileNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _username = doc.data()?['username'] ?? user.displayName ?? 'User';
          _email = user.email ?? '';
          _mobileNumber = doc.data()?['mobileNumber'] ?? '';
          _usernameController.text = _username;
          _mobileNumberController.text = _mobileNumber;
          _isLoading = false;
        });
      } else {
        // Create user document if it doesn't exist
        await _firestore.collection('users').doc(user.uid).set({
          'username': user.displayName ?? 'User',
          'email': user.email ?? '',
          'mobileNumber': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        setState(() {
          _username = user.displayName ?? 'User';
          _email = user.email ?? '';
          _mobileNumber = '';
          _usernameController.text = _username;
          _mobileNumberController.text = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _email = user.email ?? '';
          _username = user.displayName ?? 'User';
          _mobileNumber = '';
          _usernameController.text = _username;
          _mobileNumberController.text = '';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'username': _usernameController.text.trim(),
        'mobileNumber': _mobileNumberController.text.trim(),
      });
      setState(() {
        _username = _usernameController.text.trim();
        _mobileNumber = _mobileNumberController.text.trim();
        _isEditing = false;
      });
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.profileUpdated ?? 'Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.profileUpdateFailed ?? 'Failed to update profile')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = LanguageProvider();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          AppBarLanguageSelector(languageProvider: languageProvider),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.purple[300],
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.purple[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.username,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              if (!_isEditing)
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = true;
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _isEditing
                              ? TextField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check),
                                          onPressed: _saveProfile,
                                          color: Colors.green,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            setState(() {
                                              _isEditing = false;
                                              _usernameController.text = _username;
                                              _mobileNumberController.text = _mobileNumber;
                                            });
                                          },
                                          color: Colors.red,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Text(
                                  _username,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _email,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.mobileNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isEditing
                              ? TextField(
                                  controller: _mobileNumberController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    hintText: l10n.mobileNumber,
                                  ),
                                )
                              : Text(
                                  _mobileNumber.isEmpty ? 'Not set' : _mobileNumber,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: _mobileNumber.isEmpty ? Colors.grey : Colors.black,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
