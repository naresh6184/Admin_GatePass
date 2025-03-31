// ignore_for_file: use_build_context_synchronously

import 'package:admin_app/forgotpassword.dart';
import 'package:admin_app/home.dart';
import 'package:admin_app/editprofile.dart'; // Import Edit Profile page
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  AdminLoginPageState createState() => AdminLoginPageState();
}

class AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = '';
  bool showPassword = false;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');

    if (savedEmail != null && savedPassword != null) {
      emailController.text = savedEmail;
      passwordController.text = savedPassword;
      rememberMe = true;
      await _login(autoLogin: true); // Attempt auto-login
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('saved_email', email);
      await prefs.setString('saved_password', password);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
    }
  }

  Future<void> _login({bool autoLogin = false}) async {
    try {
      // Log in using email and password
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
          email: emailController.text, password: passwordController.text);

      User? user = userCredential.user;

      if (user == null) {
        setState(() => errorMessage = 'User not found');
        return;
      }

      // Save credentials if Remember Me is checked
      if (!autoLogin) {
        await _saveCredentials(emailController.text, passwordController.text);
      }

      // Check ActivePermission and completeProfile from the database
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      if (adminDoc.exists) {
        bool adminPermission = adminDoc['adminPermission'] ?? false;
        bool completeProfile = adminDoc['profileCompletionStatus'] ?? false;

        if (!adminPermission) {
          setState(() =>
          errorMessage = 'You are not Fully Authorized to Login');
          return;
        }

        // Navigate based on completeProfile status
        setState(() => errorMessage = '');
        if (!completeProfile) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminEditProfilePage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminHomePage()),
          );
        }
      } else {
        setState(() => errorMessage = 'Admin not found in the database.');
      }
    } catch (e) {
      if (!autoLogin) {
        setState(() => errorMessage = 'Login failed: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => errorMessage = ''),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Admin Login'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color.fromARGB(255, 86, 8, 164), // Purple title color
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 80), // Added spacing for symmetry
                _buildTextField('Email', emailController,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _buildPasswordField(
                  'Password',
                  passwordController,
                  showPassword,
                      (value) {
                    setState(() => showPassword = value);
                  },
                ),
                const SizedBox(height: 20),
                if (errorMessage.isNotEmpty)
                  _buildMessage(errorMessage, Colors.red),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      onChanged: (value) {
                        setState(() {
                          rememberMe = value ?? false;
                        });
                      },
                    ),
                    const Text(
                      'Remember Me',
                      style: TextStyle(color: Color.fromARGB(255, 90, 12, 157)),
                    ),
                    const Spacer(), // Push 'Forgot Password?' to the right
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Color.fromARGB(255, 73, 39, 118)),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _login(),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String labelText, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: const TextStyle(color: Color.fromARGB(255, 11, 11, 11)),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
      String labelText,
      TextEditingController controller,
      bool showPassword,
      void Function(bool) onToggle,
      ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: TextField(
          controller: controller,
          obscureText: !showPassword,
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                showPassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => onToggle(!showPassword),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(String message, Color color) {
    return Text(
      message,
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}
