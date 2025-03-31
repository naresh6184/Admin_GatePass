// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:io';

import 'package:admin_app/home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AdminEditProfilePage extends StatefulWidget {
  const AdminEditProfilePage({super.key});

  @override
  _AdminEditProfilePageState createState() => _AdminEditProfilePageState();
}

class _AdminEditProfilePageState extends State<AdminEditProfilePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpMobileController = TextEditingController();
  String email ="N/A" ;
  String countryCode = '+91';
  bool mobileVerified = false;
  bool otpRequested = false;
  String? _profileImage;  // This holds the file path for the selected image (local path)
  String? _profileImageUrl;  // This holds the Firebase Storage image URL (network image)
  String errorMessage = '';
  String successMessage = '';
  String verificationId = '';

  int profileCompletionStatus = 0;

  // Department and Designation dropdown values
  String selectedDepartment = '';
  String selectedDesignation = '';


  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();



      final adminData = adminDoc.data() as Map<String, dynamic>?;

      // If a profilePic is stored in the database, initialize it
      if (adminData != null && adminData['profileImage'] != null) {
        setState(() {
          _profileImageUrl = adminData['profileImage']; // Set the profile pic URL
        });
      }

      email = adminData?['email']??"N/A";

      setState(() {
        nameController.text = adminData?['name'] ?? user.displayName ?? 'No Name';
        phoneController.text = adminData?['phone'] ?? '';
        selectedDepartment = adminData?['department'] ?? selectedDepartment;
        selectedDesignation = adminData?['designation'] ?? selectedDesignation;

      });
    }
  }

  Future<void> _requestOTP() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '$countryCode${phoneController.text}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await user.updatePhoneNumber(credential);
          setState(() {
            mobileVerified = true;
            otpRequested = false;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            errorMessage = e.message ?? 'Unknown error occurred';
            otpRequested = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            this.verificationId = verificationId;
            otpRequested = true;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    }
  }


  Future<void> _validateMobileOTP() async {
    String otp = otpMobileController.text;
    if (otp.length == 6) {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: otp);

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePhoneNumber(credential);
        setState(() {
          mobileVerified = true; // Set this flag locally
          otpRequested = false;
          errorMessage = '';
        });
      }
    } else {
      setState(() {
        errorMessage = 'Invalid OTP';
      });
    }
  }

  Future<void> _saveProfileAndGoHome() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (nameController.text.isNotEmpty &&
          phoneController.text.isNotEmpty &&
          selectedDesignation != 'Select Designation' &&
          (selectedDesignation == 'Head of Department'
              ? selectedDepartment != 'Select Department'
              : true)) {
        try {
          // Fetch the current phone number from Firestore
          DocumentSnapshot adminDoc = await FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get();

          String currentPhone = adminDoc['phone'] ?? '';

          if (currentPhone == phoneController.text) {
            // If the phone number matches, proceed with the update
            await _updateProfile(user.uid);
          } else if (mobileVerified) {
            // If the phone is new but verified, proceed with the update
            await _updateProfile(user.uid);
          } else {
            // Mobile number is neither verified nor matching
            setState(() {
              errorMessage = 'Please verify your mobile number before saving';
            });
          }
        } catch (e) {
          setState(() {
            errorMessage = 'Failed to fetch admin data: $e';
          });
        }
      } else {
        setState(() => errorMessage = 'Please complete all required fields');
      }
    } else {
      setState(() {
        errorMessage = 'User not logged in.';
      });
    }
  }



  Future<void> _updateProfile(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('admins').doc(userId).update({
        'name': nameController.text,
        'phone': phoneController.text,
        'department': selectedDesignation == 'Head of Department'
            ? selectedDepartment
            : null,
        'designation': selectedDesignation,
        'profileCompletionStatus': true, // Profile completion status
      });

      setState(() {
        successMessage = 'Profile updated successfully!';
        errorMessage = ''; // Clear any previous errors
      });

      // Navigate to the Home page after saving
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminHomePage()),
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to update profile: $e';
      });
    }
  }


  Future<void> _pickImage() async {
    // Pick an image from the gallery
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // Set the selected image path (using String?) instead of File
      setState(() {
        _profileImage = pickedFile.path; // Store the file path as String?
      });

      // Upload the image to Firebase Storage and get the download URL
      String? downloadUrl = await _uploadProfileImage(_profileImage!);

      if (downloadUrl != null && downloadUrl.isNotEmpty) {
        // Update the user's profilePic field in Firestore with the download URL
        await _updateProfilePicInFirestore(downloadUrl);

        // Save the Firebase download URL for later display
        setState(() {
          _profileImageUrl = downloadUrl;
        });
      }
    }
  }

  Future<String?> _uploadProfileImage(String imagePath) async {
    User? user = FirebaseAuth.instance.currentUser;
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(user?.uid)
        .get();

    final userData = userDoc.data() as Map<String, dynamic>?;

    try {
      // Define the storage path for the image
      String storagePath = "Admins' Profile Pics/${userData?['name']}.jpg";
      // Reference to Firebase Storage
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference storageReference = storage.ref().child(storagePath);

      // Upload the file to Firebase Storage
      UploadTask uploadTask = storageReference.putFile(File(imagePath)); // Convert path to File
      TaskSnapshot taskSnapshot = await uploadTask;
      print("FIle Uploaded");
      // Get the image URL after upload
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading image: $e");
      return ''; // Return an empty string in case of an error
    }
  }

  Future<void> _updateProfilePicInFirestore(String downloadUrl) async {
    User? user = FirebaseAuth.instance.currentUser;

    try {
      // Reference to Firestore 'users' collection
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Update the profilePic field in Firestore with the download URL
      await firestore.collection('admins').doc(user?.uid).update({
        'profileImage': downloadUrl,  // Store the URL as a reference
      });

      print("Profile picture updated successfully.");
    } catch (e) {
      print("Error updating Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => errorMessage = ''),
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Admin Profile')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileImage(),
                const SizedBox(height: 20),
                _buildEditableField('Full Name', nameController),
                const SizedBox(height: 10),
                _buildNonEditableField("Email", email),
                const SizedBox(height: 10),

                // Designation
                _buildNonEditableField('Designation', selectedDesignation),
                const SizedBox(height: 10),

                // Department (if applicable)
                if (selectedDesignation == 'Head of Department')
                  _buildNonEditableField('Department', selectedDepartment),
                const SizedBox(height: 10),

                _buildMobileField(),
                const SizedBox(height: 20),
                if (errorMessage.isNotEmpty)
                  _buildMessage(errorMessage, Colors.red),
                if (successMessage.isNotEmpty)
                  _buildMessage(successMessage, Colors.green),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveProfileAndGoHome,
                  child: const Text('Save Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNonEditableField(String labelText, String value) {
    return TextField(
      style: TextStyle(color: Colors.black),
      controller: TextEditingController(text: value,),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.black),  // Black label color
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black), // Black border when focused
        ),
        filled: true,  // Set background color
        fillColor: Colors.grey[200],
      ),
      enabled: false,  // Makes the field non-editable
    );
  }




  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight, // Better placement for edit icon
        children: [
          // Profile image container
          Container(
            width: 120.0,
            height: 160.0,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle, // Square shape
              image: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(_profileImageUrl!),  // Use the URL directly
                fit: BoxFit.cover,
              )
                  : const DecorationImage(
                image: AssetImage('assets/profile_pic.jpg'), // Default local image
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(10.0), // Rounded corners
            ),
          ),
          // Edit icon button
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(5.0),
              decoration: BoxDecoration(
                color: Colors.white, // Background color for the edit button
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade400,
                    blurRadius: 4.0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit,
                color: Colors.blue,
                size: 20.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String labelText, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(),
      ),
    );
  }


  Widget _buildMobileField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DropdownButton<String>(
              value: countryCode,
              items: ['+91', '+1', '+44', '+61', '+81']
                  .map((code) =>
                  DropdownMenuItem(value: code, child: Text(code)))
                  .toList(),
              onChanged: (newValue) =>
                  setState(() => countryCode = newValue ?? '+91'),
            ),
            const SizedBox(width: 10),
            Expanded(child: _buildMobileNumberField()),
            if (!mobileVerified && !otpRequested)
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: _requestOTP,
              ),
            if (mobileVerified)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        mobileVerified = false;
                        otpRequested = false;
                      });
                    },
                    child: const Text('Change Mobile No.'),
                  ),
                ],
              ),
          ],
        ),
        if (!mobileVerified && otpRequested) _buildOTPSection(), // OTP section
      ],
    );
  }

  Widget _buildMobileNumberField() {
    return TextField(
      controller: phoneController,
      keyboardType: TextInputType.number,
      maxLength: 10,
      readOnly: mobileVerified || otpRequested,
      decoration: const InputDecoration(
        labelText: 'Mobile Number',
        border: OutlineInputBorder(),
        counterText: '',
      ),
    );
  }

  Widget _buildOTPSection() {
    return Column(
      children: [
        TextField(
          controller: otpMobileController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Enter OTP',
            border: OutlineInputBorder(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _requestOTP,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Resend OTP'),
            ),
            ElevatedButton(
              onPressed: _validateMobileOTP,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Validate OTP'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessage(String message, Color color) {
    return Text(
      message,
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}
