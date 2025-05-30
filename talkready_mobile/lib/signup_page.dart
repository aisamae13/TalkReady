import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:talkready_mobile/welcome_page.dart';
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

  bool _isVerifyingPhone = false;
  bool _isResendAvailable = false;
  int _resendCooldown = 30;
  Timer? _resendTimer;

  final _inputDecorationTheme = InputDecorationTheme(
    border: const OutlineInputBorder(),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF00568D), width: 2.0),
    ),
    labelStyle: TextStyle(color: Colors.grey[600]),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 2.0),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 1.0),
    ),
  );

  Future<void> _signUpWithEmail() async {
    try {
      if (_emailController.text.isEmpty ||
          _passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF00568D))),
      );

      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await _auth.currentUser?.sendEmailVerification();

      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.'),
            duration: Duration(seconds: 5),
          ),
        );
      }

      await _checkEmailVerification(_auth.currentUser);
      // After email verification, move to phone verification
      if (mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = 'Sign-up failed: $e';
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }

  Future<void> _checkEmailVerification(User? user) async {
    if (user == null) return;

    bool isVerified = false;
    int attempts = 0;
    const maxAttempts = 30;

    while (!isVerified && attempts < maxAttempts && mounted) {
      await user?.reload();
      user = _auth.currentUser;
      isVerified = user?.emailVerified ?? false;

      if (isVerified) {
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
      attempts++;
    }

    if (!isVerified && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email before continuing. Check your spam folder.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
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
    super.dispose();
  }

  Future<void> _verifyPhoneNumber() async {
    if (!RegExp(r'^\d{10}$').hasMatch(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isVerifyingPhone = false;
            _startResendCooldown();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code sent via SMS.')),
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying phone number: $e')),
      );
    }
  }

  Future<void> _confirmVerificationCode(String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: smsCode);
      await _auth.currentUser?.linkWithCredential(credential);
      await _savePhoneToFirestore();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chooseUserType');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verification code or phone already linked.')),
      );
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
                      ),
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