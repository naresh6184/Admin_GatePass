import 'package:admin_app/student_approved_gatepasses.dart';
import 'package:admin_app/student_local_gatepasses.dart';
import 'package:admin_app/student_pending_gatepasses.dart';
import 'package:admin_app/student_rejected_gatepasses.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentProfilePage extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentProfilePage({required this.student, super.key});

  @override
  _StudentProfilePageState createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  late String remark;
  late TextEditingController _remarkController; // TextEditingController for remark
   bool isBanned = false;
  bool isEditingRemark = false; // Flag to toggle between editing and viewing the remark
String userId ='userId';
  int totalGatePasses = 0;
  int approvedGatePasses = 0;
  int rejectedGatePasses = 0;
  int pendingGatePasses=0;
  int localGatePasses=0;


  /// Function to refresh profile data
  Future<void> _refreshProfileData() async {
    await Future.wait([
      Future(() => _loadRemark()),      // Ensures it returns Future<void>
      Future(() => _loadBanStatus()),   // Ensures it returns Future<void>
      Future(() => _loadGatePassStats())// Ensures it returns Future<void>
    ]);
  }



  @override
  void initState() {
    super.initState();
    _remarkController = TextEditingController();
    _refreshProfileData();
  }


  @override
  void dispose() {
    _remarkController.dispose(); // Dispose the controller
    super.dispose();
  }



  // Method to load the remark from Firestore
  void _loadRemark() async {
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.student['userId']) // Fetch student by userId
          .get();

      userId = widget.student['userId'];
      if (studentDoc.exists) {
        setState(() {
          remark = studentDoc.get('remark') ?? ''; // Set remark from Firestore
          _remarkController.text = remark; // Set the text controller to the fetched remark
        });
      }
    } catch (e) {
      print('Error fetching remark: $e');
    }
  }

  // Method to load the ban status from Firestore
  void _loadBanStatus() async {
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.student['userId'])
          .get();

      setState(() {
        isBanned = studentDoc.get('banned') ?? false;
      });
    } catch (e) {
      print('Error fetching ban status: $e');
    }
  }
  void _loadGatePassStats() async {


    int totalCount = 0;
    int pendingCount=0;
    int approvedCount = 0;
    int rejectedCount = 0;
    int localCount=0;

    try {

        final gatePassesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.student['userId'])
            .collection('GatePasses')
            .get();

        for (var gatePassDoc in gatePassesSnapshot.docs) {
          final requestData = gatePassDoc.data();
          totalCount++;
           if (requestData['request'] == 1) {
            approvedCount++;
          } else if (requestData['request'] == -1) {
            rejectedCount++;
          }
           else if(requestData['request']==0)
             {
               pendingCount++;
             }
           else if(requestData['gatepassType']=="LOCAL")
             {
               localCount++;
             }
        }


      setState(() {
        totalGatePasses = totalCount;
        approvedGatePasses = approvedCount;
        rejectedGatePasses = rejectedCount;
        pendingGatePasses =pendingCount;
        localGatePasses=localCount;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating request counts: $e')),
      );
    }
  }

  // Update Remark in Firebase
  Future<void> saveRemark() async {
    try {
      await FirebaseFirestore.instance
          .collection('users') // Correct collection name
          .doc(widget.student['userId']) // Correct document ID
          .update({'remark': remark}); // Update remark field

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remark saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save remark.')),
      );
    }
  }

  // Toggle Ban Status in Firebase
  Future<void> toggleBanStatus() async {
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.student['userId'])
          .get();

      bool currentStatus = studentDoc.get('banned') ?? false;
      bool newStatus = !currentStatus;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.student['userId'])
          .update({
        'banned': newStatus,
      });

      // Update local isBanned state and show success message
      setState(() {
        isBanned = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'Student has been banned!' : 'Student has been unbanned!',
          ),
        ),
      );
    } catch (e) {
      print('Error updating ban status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update ban status.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfileData, // Function to refresh data
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Profile Picture with Banned Stamp
              Stack(
                alignment: Alignment.center,
                children: [
                  // Profile Picture
                  Container(
                    height: 150,
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(widget.student['profilePic']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // BANNED Text without container, rotated 45 degrees
                  if (isBanned)
                    Transform.rotate(
                      angle: -3.14 / 4, // Rotate -45 degrees to make the text go from bottom-left to top-right
                      child: Text(
                        'BANNED',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 30, // Increase the font size to make it bold and big
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2, // Optional: Add some letter spacing for a clearer look
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Name
              Text(
                widget.student['name'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // Details Section
              Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildDetailRow('Roll No.', widget.student['rollNo']),
                      _buildDetailRow('Email', widget.student['email']),
                      _buildDetailRow('Program', widget.student['program']),
                      _buildDetailRow('Batch', widget.student['batch']),
                      _buildDetailRow('Branch', widget.student['branch']),
                      _buildDetailRow('Room No.', widget.student['roomNo']),
                      _buildDetailRow('Contact No.', widget.student['phone']),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Editable Remark Section
              Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Remark:',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextField(
                        style: TextStyle(color: Colors.black,fontSize: 18),
                        controller: _remarkController, // Use _remarkController to control the TextField
                        decoration: const InputDecoration(
                          hintText: 'Add a remark...',
                        ),
                        onChanged: (value) {
                          setState(() {
                            remark = value;
                          });
                        },
                        enabled: isEditingRemark, // Enable or disable the field based on edit mode
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isEditingRemark = !isEditingRemark; // Toggle between edit and view mode
                            });
                            if (!isEditingRemark) {
                              saveRemark(); // Save the remark when editing ends
                            }
                          },
                          child: Text(isEditingRemark ? 'Save Remark' : 'Edit Remark'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),


              const SizedBox(height: 20),

              // Ban/Unban Button
              ElevatedButton(
                onPressed: toggleBanStatus,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0), // Adjust this value for the roundness of the corners
                  ),
                  backgroundColor: isBanned ? Colors.green : Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                ),
                child: Text(
                  isBanned ? 'Unban Student' : 'Ban Student',
                  style: const TextStyle(fontSize: 18,color: Colors.black,),
                ),
              ),

              const SizedBox(height: 20),

              // Stats Section
              Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildStatRow('Total Gate Passes', totalGatePasses),
                      _buildStatCard(context,'Pending Gate Passes', pendingGatePasses,Colors.blueGrey,userId,"pending" ),
                      _buildStatCard(context,'Approved Gate Passes', approvedGatePasses,Colors.green,userId,"approved"),
                      _buildStatCard(context,'Rejected Gate Passes', rejectedGatePasses,Colors.red,userId,"rejected"),
                      _buildStatCard(context,'Local Gate Passes', localGatePasses,Colors.grey,userId,"local"),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 22, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

Widget _buildStatCard(BuildContext context, String label, int value, Color color, String userId,String condition) {
  return SizedBox(
    width: double.infinity, // This will make the Card take the full width of its parent
    child: GestureDetector(
      onTap: () {
        if(condition=="approved")
          {
            // Navigate to the StudentApprovedRequestsPage
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentApprovedRequestsPage(userId: userId),
              ),
            );
          }
        else if(condition=="rejected")
        {
          // Navigate to the StudentApprovedRequestsPage
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentRejectedGatepasses(userId: userId),
            ),
          );
        }
        else if(condition=="pending")
        {
          // Navigate to the StudentApprovedRequestsPage
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentPendingRequestsPage(userId: userId),
            ),
          );
        }
        else if(condition=="local")
        {
          // Navigate to the StudentApprovedRequestsPage
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentLocalRequestsPage(userId: userId),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 20,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}




