import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, String? userType});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final PageController _pageController = PageController(initialPage: 0);
  bool _showPassword = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  String? _phoneNumber;

  // Phone verification timer variables
  bool _isVerifyingPhone = false;
  bool _isResendAvailable = false;
  int _resendCooldown = 30;
  Timer? _resendTimer;

  // Email verification timer variables
  bool _isEmailResendAvailable = true;
  int _emailResendCooldown = 30;
  Timer? _emailResendTimer;

  final _inputDecorationTheme = InputDecorationTheme(
    border: const OutlineInputBorder(),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF00568D), width: 2.0),
    ),
    labelStyle: TextStyle(color: Colors.grey[600]),
    focusedErrorBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 2.0),
    ),
    errorBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 1.0),
    ),
  );

  // Password validation methods
  Widget _buildPasswordRequirements(String password) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Requirements:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildRequirementItem('At least 8 characters', password.length >= 8),
          _buildRequirementItem('One lowercase letter (a-z)', RegExp(r'[a-z]').hasMatch(password)),
          _buildRequirementItem('One uppercase letter (A-Z)', RegExp(r'[A-Z]').hasMatch(password)),
          _buildRequirementItem('One number (0-9)', RegExp(r'\d').hasMatch(password)),
          _buildRequirementItem('One special character (!@#\$%^&*_)', RegExp(r'[!@#$%^&*(),.?":{}|<>_]').hasMatch(password)),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String requirement, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                fontSize: 12,
                color: isMet ? Colors.green[700] : Colors.grey[600],
                decoration: isMet ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isPasswordValid(String password) {
    return password.length >= 8 &&
          RegExp(r'[a-z]').hasMatch(password) &&
          RegExp(r'[A-Z]').hasMatch(password) &&
          RegExp(r'\d').hasMatch(password) &&
          RegExp(r'[!@#$%^&*(),.?":{}|<>_]').hasMatch(password);
  }

Future<void> _signUpWithEmail() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text;
  final confirm = _confirmPasswordController.text;

  if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
    }
    return;
  }

  if (!isValidEmail(email)) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
    }
    return;
  }

  if (!_isPasswordValid(password)) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please meet all password requirements')),
      );
    }
    return;
  }

  if (password != confirm) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
    }
    return;
  }

  try {
    // Check if this email already has sign-in methods
    final providers = await _auth.fetchSignInMethodsForEmail(email);
    if (providers.isNotEmpty) {
      if (providers.contains('google.com')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An account exists for this email using Google Sign-In. Please sign in with Google.')),
          );
        }
        return;
      }

      if (providers.contains('password')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An account already exists for this email. Please sign in instead.')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An account already exists for this email. Please use the correct sign-in method.')),
        );
      }
      return;
    }

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF00568D))),
      );
    }

    // Create account
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.email?.split('@').first ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': user.emailVerified,
      }, SetOptions(merge: true));
    }

    // Send verification email
    await _auth.currentUser?.sendEmailVerification();

    if (mounted) {
      Navigator.pop(context); // remove loading
      // NOTE: Timer is NO LONGER STARTED HERE. It starts inside the dialog.
      _showEmailVerificationDialog();
    }
  } on FirebaseAuthException catch (e) {
    String message;
    if (e.code == 'weak-password') {
      message = 'The password provided is too weak.';
    } else if (e.code == 'email-already-in-use') {
      message = 'An account already exists for that email. Please sign in.';
    } else if (e.code == 'invalid-email') {
      message = 'The email address is not valid.';
    } else {
      message = 'Sign-up failed: ${e.message ?? e.code}';
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  } catch (e) {
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    }
  }
}

// Fixed email verification dialog logic
void _showEmailVerificationDialog() {
  // Always reset the timer state before showing the dialog for a clean start
  setState(() {
    _isEmailResendAvailable = false;
    _emailResendCooldown = 30;
  });

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) { // <-- capture the dialog's state setter

        // CRITICAL FIX: Use a PostFrameCallback to start the timer
        // immediately after the dialog is built, using its StateSetter.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Check if a timer is already active to prevent creating a new one on every rebuild
          if (_emailResendTimer == null || !_emailResendTimer!.isActive) {
             _startEmailResendCooldown(setDialogState);
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text(
            'Verify Your Email',
            style: TextStyle(color: Color(0xFF00568D), fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.email_outlined,
                size: 64,
                color: Color(0xFF00568D),
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a verification email to:',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                _emailController.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please check your email (including spam folder) and click the verification link, then tap "I\'ve Verified" below.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isEmailResendAvailable
                  ? () async {
                      // Resend verification email
                      try {
                        await _auth.currentUser?.sendEmailVerification();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Verification email sent again!')),
                          );
                        }
                        // Start cooldown again, passing the dialog's setDialogState!
                        _startEmailResendCooldown(setDialogState);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to resend email. Please try again.')),
                          );
                        }
                      }
                    }
                  : null,
              child: Text(
                _isEmailResendAvailable
                    ? 'Resend Email'
                    : 'Resend in ${_emailResendCooldown}s', // <-- This updates on timer tick
                style: TextStyle(
                  color: _isEmailResendAvailable
                      ? const Color(0xFF00568D)
                      : Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Show loading
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );
                }

                // Force refresh user multiple times
                await _auth.currentUser?.reload();
                await Future.delayed(const Duration(milliseconds: 500));
                await _auth.currentUser?.reload();
                await Future.delayed(const Duration(milliseconds: 500));
                await _auth.currentUser?.reload();

                final user = _auth.currentUser;
                if (mounted) {
                   Navigator.pop(context); // Remove loading
                }


                if (user?.emailVerified == true) {
                  // Email verified, update Firestore and continue
                  await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                    'emailVerified': true,
                  });

                  if (mounted) {
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email verified successfully!')),
                    );

                    // Move to phone verification
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                } else {
                  // Email not verified yet
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email not verified yet. Please check your email and click the verification link first.'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00568D),
                foregroundColor: Colors.white,
              ),
              child: const Text('I\'ve Verified'),
            ),
          ],
        );
      },
    ),
  ).then((_) {
    // Optional: Cancel the timer if the user closes the dialog manually
    _emailResendTimer?.cancel();
    _emailResendTimer = null; // Clear the timer reference
  });
}

// Method for email resend cooldown to correctly update dialog state
void _startEmailResendCooldown([StateSetter? setDialogState]) {
  // Determine which setState function to use (dialog's or main widget's)
  final updateState = setDialogState ?? setState;

  // 1. Initialize the cooldown state
  updateState(() {
    _isEmailResendAvailable = false;
    _emailResendCooldown = 30; // Start at 30
  });

  _emailResendTimer?.cancel(); // Cancel any existing timer
  _emailResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_emailResendCooldown > 0) {
      // 2. Decrement and update state every second using the correct StateSetter
      updateState(() {
        _emailResendCooldown--;
      });
    } else {
      // 3. Reset state when cooldown is over
      // Always update main widget state
      setState(() {
        _isEmailResendAvailable = true;
      });
      // If inside dialog, update dialog state too
      if (setDialogState != null) {
         setDialogState(() {
             _isEmailResendAvailable = true;
         });
      }
      timer.cancel();
      _emailResendTimer = null; // Clear the timer reference
    }
  });
}

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    _pageController.dispose();
    _resendTimer?.cancel();
    _emailResendTimer?.cancel(); // Cancel email timer too
    super.dispose();
  }

  Future<void> _verifyPhoneNumber() async {
    if (!RegExp(r'^\d{10}$').hasMatch(_phoneController.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
        );
      }
      return;
    }
    setState(() {
      _isVerifyingPhone = true;
      _isResendAvailable = false;
      _resendCooldown = 30;
    });
    _phoneNumber = '+63${_phoneController.text}';
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.currentUser?.linkWithCredential(credential);
          await _savePhoneToFirestore();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/chooseUserType');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          String message;
          if (e.code == 'invalid-phone-number') {
            message = 'The phone number is invalid. Please check and try again.';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many requests. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded. Please try again later.';
          } else {
            message = 'Phone verification failed: ${e.message}';
          }
          setState(() {
            _isVerifyingPhone = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isVerifyingPhone = false;
            _startResendCooldown();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification code sent via SMS.')),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
            _isVerifyingPhone = false;
            _isResendAvailable = true;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isVerifyingPhone = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying phone number: $e')),
        );
      }
    }
  }

  Future<void> _confirmVerificationCode(String smsCode) async {
    try {
      // First check if phone number is already used by another account
      final existingUser = await _checkPhoneNumberExists(_phoneNumber!);
      if (existingUser != null && existingUser != _auth.currentUser?.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This phone number is already registered to another account.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: smsCode);
      await _auth.currentUser?.linkWithCredential(credential);
      await _savePhoneToFirestore();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chooseUserType');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'credential-already-in-use') {
        message = 'This phone number is already linked to another account.';
      } else if (e.code == 'invalid-verification-code') {
        message = 'Invalid verification code. Please try again.';
      } else {
        message = 'Phone verification failed: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid verification code or phone already linked.')),
        );
      }
    }
  }

  // Method to check if phone number already exists in Firestore
  Future<String?> _checkPhoneNumberExists(String phoneNumber) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('onboarding.phone', isEqualTo: phoneNumber)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id; // Return the UID of existing user
      }
      return null; // Phone number not found
    } catch (e) {
      // ignore: avoid_print
      print('Error checking phone number: $e');
      return null;
    }
  }

  Future<void> _savePhoneToFirestore() async {
    final user = _auth.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'onboarding': {
          'phone': _phoneNumber,
        },
      }, SetOptions(merge: true));
    }
  }

  void _startResendCooldown() {
    setState(() {
      _isResendAvailable = false;
      _resendCooldown = 30;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        setState(() {
          _isResendAvailable = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: _inputDecorationTheme,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Sign Up'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Slide 1: Email/Password Registration
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Step 1: Email Registration',
                        style: TextStyle(fontSize: 24, color: Color(0xFF00568D)),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {}); // Rebuild to update requirement indicators
                        },
                      ),
                      // Show password requirements when user starts typing
                      if (_passwordController.text.isNotEmpty)
                        _buildPasswordRequirements(_passwordController.text),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          suffixIcon: IconButton(
                            icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (_emailController.text.isEmpty ||
                              _passwordController.text.isEmpty ||
                              _confirmPasswordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill in all fields')),
                            );
                            return;
                          }
                          if (!isValidEmail(_emailController.text.trim())) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid email')),
                            );
                            return;
                          }
                          _signUpWithEmail();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        child: const Text('Register Email', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
              // Slide 2: Phone Verification
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Step 2: Verify Phone Number',
                        style: TextStyle(fontSize: 24, color: Color(0xFF00568D)),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixText: '+63 ',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isVerifyingPhone
                            ? null
                            : () {
                                if (_phoneController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter your phone number')),
                                  );
                                  return;
                                }
                                _verifyPhoneNumber();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        child: _isVerifyingPhone
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Send Verification Code', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _smsCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Verification Code',
                        ),
                        keyboardType: TextInputType.number,
                        onFieldSubmitted: (code) {
                          if (code.isNotEmpty) {
                            _confirmVerificationCode(code);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a code')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          final smsCode = _smsCodeController.text.trim();
                          if (smsCode.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a code')),
                            );
                            return;
                          }
                          _confirmVerificationCode(smsCode);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00568D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        child: const Text('Confirm Phone Verification', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isResendAvailable
                            ? () {
                                _verifyPhoneNumber();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isResendAvailable ? const Color(0xFF00568D) : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        child: Text(_isResendAvailable ? 'Resend Code' : 'Resend in $_resendCooldown s'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        child: const Text('Back', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isValidEmail(String email) {
    return RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$').hasMatch(email);
  }
}