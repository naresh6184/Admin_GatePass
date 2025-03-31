import 'package:admin_app/studentprofile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentDatabasePage extends StatefulWidget {
  @override
  _StudentDatabasePageState createState() => _StudentDatabasePageState();
}

class _StudentDatabasePageState extends State<StudentDatabasePage> {
  String selectedProgram = '';  // Selected program (e.g., BTech, PhD, MBA)
  String selectedBatch = '';    // Selected batch (e.g., 2022, 2023)
  String selectedBranch = '';   // Selected branch (e.g., IT, CS)
  String searchQuery = '';      // Search query for Roll No. and Student Name
  List<Map<String, dynamic>> students = []; // Updated to allow dynamic types
  bool isLoading = false;
  // Fetch student data from Firestore based on program, batch, and branch
  Future<void> fetchStudents() async {
    try {
      // Start building the query
      Query query = FirebaseFirestore.instance.collection('users');

      // Apply filters dynamically based on selected conditions
      if (selectedProgram.isNotEmpty) {
        query = query.where('program', isEqualTo: selectedProgram);
      }
      if (selectedBatch.isNotEmpty) {
        query = query.where('batch', isEqualTo: selectedBatch);
      }
      if (selectedBranch.isNotEmpty) {
        query = query.where('branch', isEqualTo: selectedBranch);
      }

      // Fetch data from Firestore
      final snapshot = await query.get();

      // Map data to the students list
      setState(() {
        students = snapshot.docs
            .map((doc) => {
          'userId': doc.id, // Add the userId here (document ID)
          'rollNo': doc['rollNo']?.toString() ?? '',
          'name': doc['name']?.toString() ?? '',
          'batch': doc['batch']?.toString() ?? '',
          'branch': doc['branch']?.toString() ?? '',
          'profilePic': doc['profilePic']?.toString() ?? '',
          'semester': doc['semester']?.toString() ?? '',
          'roomNo': doc['roomNo']?.toString() ?? '',
          'email': doc['email']?.toString() ?? '',
          'phone': doc['phone']?.toString() ?? '',
          'program': doc['program']?.toString() ?? '',
        })
            .toList();
      });
    } catch (e) {
      print('Error fetching students: $e');
    }
  }


  // Filter students based on the search query
  List<Map<String, dynamic>> getFilteredStudents() {
    return students
        .where((student) =>
    student['rollNo']!.toLowerCase().contains(searchQuery.toLowerCase()) ||
        student['name']!.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  // Method to handle program selection
  void selectProgram(String program) {
    setState(() {
      selectedProgram = program;
      selectedBatch = '';
      selectedBranch = '';
      students = [];
    });
    fetchStudents();
  }

  // Method to handle batch selection
  void selectBatch(String batch) {
    setState(() {
      selectedBatch = batch;
      selectedBranch = '';
      students = [];
    });
    fetchStudents(); // Fetch students for selected batch
  }

  // Method to handle branch selection
  void selectBranch(String branch) {
    setState(() {
      selectedBranch = branch;
    });
    fetchStudents(); // Fetch students for selected branch
  }

  // Fetch student data based on rollNo from Firestore
  Future<void> fetchStudentByRollNo(String rollNo) async {
    setState(() => isLoading = true);

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('rollNo', isEqualTo: rollNo)
          .get();

      if (snapshot.docs.isNotEmpty) {
        students = snapshot.docs.map((doc) => {
          'userId': doc.id,   // Include Firestore document ID
          ...doc.data() as Map<String, dynamic>  // Include all Firestore fields
        }).toList();
      } else {
        students = [];
      }
    } catch (e) {
      print('Error fetching student: $e');
      students = [];
    }

    setState(() => isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student DataBase'),
      ),
      body: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Search Bar
    TextField(
    onChanged: (query) {
    setState(() {
    searchQuery = query.toUpperCase();  // Convert the input to uppercase
    });
    // Pass searchQuery as an argument to the function
    fetchStudentByRollNo(searchQuery);
    },
    decoration: InputDecoration(
    labelText: 'Search by Roll No.',
    border: OutlineInputBorder(),
    hintText: 'Enter Roll No.',  // Placeholder text
    ),
    ),
    SizedBox(height: 16),

    // Program Selection (BTech, PhD, MBA) as Cards
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
    _buildProgramCard('B.Tech'),
    _buildProgramCard('PhD'),
    _buildProgramCard('MBA'),
    ],
    ),
    SizedBox(height: 16),

    // Batch Selection as Cards (only if a program is selected)
    if (selectedProgram.isNotEmpty) ...[
    Text('Select Batch:', style: TextStyle(fontSize: 18)),
    SizedBox(height: 8),
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
    _buildBatchCard('2022'),
    _buildBatchCard('2023'),
    _buildBatchCard('2024'),
    _buildBatchCard('2025'),
    ],
    ),
    ],
    SizedBox(height: 16),

    // Branch Selection as Cards (only if a batch is selected)
    if (selectedBatch.isNotEmpty) ...[
    Text('Select Branch:', style: TextStyle(fontSize: 18)),
    SizedBox(height: 8),
    Expanded(
    child: ListView(
    children: [
    _buildBranchCard('Information Technology'),
    _buildBranchCard('Computer Science'),
    _buildBranchCard('Mechanical Engineering'),
    _buildBranchCard('Chemical Engineering'),
    _buildBranchCard('Petroleum Engineering'),
    ],
    ),
    ),
    ],
    SizedBox(height: 16),

    // Display loading, no students, or student list
    Expanded(
    child: isLoading
    ? Center(child: CircularProgressIndicator())  // Show spinner when loading
        : getFilteredStudents().isNotEmpty
    ? ListView.builder(
    itemCount: getFilteredStudents().length,
    itemBuilder: (context, index) {
    final student = getFilteredStudents()[index];
    return Card(
    margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),  // Reduced vertical margin for smaller card
    elevation: 4,
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8.0),
    ),
    child: ListTile(
    contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),  // Reduced padding
    leading: student['profilePic'] != null
    ? Container(
    height: 50.0,  // Reduced height for profile picture
    width: 35.0,   // Width remains smaller
    decoration: BoxDecoration(
    image: DecorationImage(
    image: NetworkImage(student['profilePic']!),
    fit: BoxFit.cover,
    ),
    borderRadius: BorderRadius.circular(8.0),
    ),
    )
        : Container(
    height: 50.0,  // Default height reduced
    width: 35.0,   // Default width reduced
    decoration: BoxDecoration(
    color: Colors.grey[300],  // Default background color
    borderRadius: BorderRadius.circular(8.0),
    ),
    child: Icon(Icons.person, color: Colors.grey[600]),
    ),
    title: Center(
    child: Text(student['name']!,
    style: TextStyle(
    fontSize: 18, fontWeight: FontWeight.bold))),
    subtitle: Center(
    child: Text(student['rollNo']!,
    style: TextStyle(fontSize: 16))),
    onTap: () {
    print("Student ID is ${student['userId']}");
    // Navigate to the student's profile page
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) =>
    StudentProfilePage(student: student),
    ),
    );
    },
    ),
    );
    },
    )
        : Center(child: Text('No students found')),
    ),
    ],
    ),
    )

    );
  }

  Future<String?> getUserIdByRollNo(String rollNo) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('rollNo', isEqualTo: rollNo)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id; // Document ID (userId)
      }
    } catch (e) {
      print('Error fetching userId: $e');
    }
    return null; // Return null if not found
  }

  Widget _buildProgramCard(String program) {
    return Padding(
      padding:  EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.04),
      child: ElevatedButton(
        onPressed: () {
          selectProgram(program);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: selectedProgram == program ? Colors.purple : Colors.grey[200], // Change the color when selected
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          program,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.035,
            color: selectedProgram == program ? Colors.white : Colors.black, // Adjust text color
          ),
        ),
      ),
    );
  }

  Widget _buildBatchCard(String batch) {
    return Padding(
      padding:  EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.01),
      child: ElevatedButton(
        onPressed: () {
          selectBatch(batch);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: selectedBatch == batch ? Colors.purple : Colors.grey[200], // Change the color when selected
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          batch,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.03,
            color: selectedBatch == batch ? Colors.white : Colors.black, // Adjust text color
          ),
        ),
      ),
    );
  }

  // Branch card builder
  Widget _buildBranchCard(String branchName) {
    return GestureDetector(
      onTap: () {
        selectBranch(branchName);
      },
      child: Card(
        color: selectedBranch == branchName ? Colors.purple : Colors.grey[200], // Change background color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 4, // Optional: Adds a shadow for better visibility
        child: Container(
          width: double.infinity, // Ensures the card takes full width
          height: 60, // Set a fixed height for consistency
          child: Center(
            child: Text(
              branchName,
              style: TextStyle(
                color: selectedBranch == branchName ? Colors.white : Colors.black,
                fontSize: MediaQuery.of(context).size.width * 0.05, // Adjust font size if needed
              ),
            ),
          ),
        ),
      ),
    );
  }
}


