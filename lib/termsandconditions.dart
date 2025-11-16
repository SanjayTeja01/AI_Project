import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  bool _accepted = false;
  bool _showError = false;

  Future<bool> _onWillPop() async {
    if (!_accepted) {
      setState(() {
        _showError = true;
      });
      // Hide error after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showError = false;
          });
        }
      });
      return false; // Prevent going back
    }
    return true; // Allow going back
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Terms and Conditions'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_accepted) {
                Navigator.pop(context);
              } else {
                setState(() {
                  _showError = true;
                });
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      _showError = false;
                    });
                  }
                });
              }
            },
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Terms and Conditions',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.now().year}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '1. Acceptance of Terms',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'By downloading, installing, or using the Campus Guard application ("App"), you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the App.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '2. Purpose of the App',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Campus Guard is a safety application designed to help users in emergency situations by sending SOS alerts to trusted contacts. The App provides features including emergency alerts, location sharing, and safety assistance through an AI chatbot.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '3. Emergency Services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'While Campus Guard is designed to assist in emergencies, it does not replace professional emergency services. In life-threatening situations, please contact your local emergency services immediately. The App is a supplementary tool and should not be solely relied upon in critical situations.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '4. Location Services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The App requires access to your location services to function properly. Your location is only shared when you actively trigger an SOS alert and is sent to your designated emergency contacts. We do not track or store your location data without your explicit action.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '5. User Responsibilities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• You are responsible for maintaining the accuracy of your emergency contacts.\n'
                    '• You must ensure your device has location services enabled for the App to function.\n'
                    '• You agree not to misuse the SOS feature for non-emergency situations.\n'
                    '• You are responsible for keeping your account credentials secure.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '6. Privacy and Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We respect your privacy. Your personal information, emergency contacts, and location data are stored securely and are only used for the purpose of providing emergency assistance. We do not sell or share your data with third parties except as necessary for emergency services.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '7. Limitation of Liability',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Campus Guard is provided "as is" without warranties of any kind. We are not liable for any damages arising from the use or inability to use the App, including but not limited to delays in emergency response, technical failures, or data loss.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '8. Availability and Updates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We reserve the right to modify, suspend, or discontinue the App at any time. We may release updates to improve functionality, security, or features. Users are encouraged to keep the App updated to the latest version.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '9. Account Termination',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You may delete your account at any time. We reserve the right to suspend or terminate accounts that violate these terms or misuse the App. Upon termination, your data will be deleted in accordance with our privacy policy.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '10. Changes to Terms',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We may update these Terms and Conditions from time to time. Users will be notified of significant changes. Continued use of the App after changes constitutes acceptance of the new terms.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Contact Us',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If you have any questions about these Terms and Conditions, please contact us through the App support channels.',
                    style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 100), // Space for checkbox
                ],
              ),
            ),
            // Checkbox at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _accepted,
                      onChanged: (value) {
                        setState(() {
                          _accepted = value ?? false;
                          _showError = false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        'I accept the Terms and Conditions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _accepted ? FontWeight.normal : FontWeight.w500,
                          color: _accepted ? Colors.grey[700] : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Error popup from bottom
            if (_showError)
              Positioned(
                bottom: 80,
                left: 16,
                right: 16,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Please accept the Terms and Conditions to continue',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
