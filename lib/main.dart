import 'package:admin_app/home.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: unused_import
import 'login.dart'; // Import your login page
import 'firebase_options.dart';

void testFirebaseStorage() async {
  try {
    FirebaseStorage storage = FirebaseStorage.instance;
    print("Firebase Storage instance initialized: ${storage.app}");
  } catch (e) {
    print("Error initializing Firebase Storage: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully!");
    testFirebaseStorage(); // Add this test
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Admin App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AdminLoginPage(), // Set the login page as the initial page
    );
  }
}
