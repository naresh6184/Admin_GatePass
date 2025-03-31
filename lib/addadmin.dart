import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddAdminPage extends StatefulWidget {
  const AddAdminPage({super.key});

  @override
  _AddAdminPageState createState() => _AddAdminPageState();
}

class _AddAdminPageState extends State<AddAdminPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;

  // Dropdown-related variables
  List<String> designations = [
    'Head of Department',
    'Chief Warden',
    'Warden',
    'DoAA',
  ];
  String? selectedDesignation;

  List<String> departments = [
    'Computer Science & Engineering',
    'Electronics Engineering',
    'Petroleum Engineering',
    'Chemical Engineering',
    'Mathematics & Computing',

  ];
  String? selectedDepartment;

  Future<void> addAdmin() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();

    // Validate email domain
    if (!email.endsWith('@rgipt.ac.in')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid college email ending with @rgipt.ac.in')),
      );
      return;
    }

    // Validate required fields
    if (name.isEmpty || email.isEmpty || selectedDesignation == null ||
        (selectedDesignation == 'Head of Department' && selectedDepartment == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill out all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Create the admin account in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: 'temporaryPassword123!', // Temporary password
      );

      // Step 2: Send a password reset email
      await _auth.sendPasswordResetEmail(email: email);

      // Step 3: Add the admin to Firestore with default values
      await _firestore.collection('admins').doc(userCredential.user?.uid).set({
        'name': name,
        'email': email,
        'designation': selectedDesignation,
        'department': selectedDepartment ?? '', // Add department only if applicable
        'Superadmin': false, // Default to false for new admins
        'adminPermission': true, // Default to active
        'profileCompletionStatus': false,
        'phone': "",
      });

      // Success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin added successfully. An email has been sent to set the password.')),
      );

      // Clear the input fields
      _nameController.clear();
      _emailController.clear();
      setState(() {
        selectedDesignation = null;
        selectedDepartment = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add admin: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Admin'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email ID',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              // Designation Dropdown
              DropdownButtonFormField<String>(
                value: selectedDesignation,
                onChanged: (value) {
                  setState(() {
                    selectedDesignation = value;
                    if (selectedDesignation != 'Head of Department') {
                      selectedDepartment = null; // Clear department if not applicable
                    }
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Designation',
                  border: OutlineInputBorder(),
                ),
                items: designations.map((designation) {
                  return DropdownMenuItem(
                    value: designation,
                    child: Text(designation),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              // Department Dropdown (conditionally shown)
              if (selectedDesignation == 'Head of Department')
                DropdownButtonFormField<String>(
                  value: selectedDepartment,
                  onChanged: (value) {
                    setState(() {
                      selectedDepartment = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                  items: departments.map((department) {
                    return DropdownMenuItem(
                      value: department,
                      child: Text(department),
                    );
                  }).toList(),
                ),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : addAdmin,
                  child: _isLoading
                      ? CircularProgressIndicator(
                    color: Colors.white,
                  )
                      : Text('Add Admin'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
