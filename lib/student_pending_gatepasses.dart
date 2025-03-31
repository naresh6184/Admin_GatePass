import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentPendingRequestsPage extends StatefulWidget {
  final String userId; // Add userId to fetch specific student's gate passes

  const StudentPendingRequestsPage({super.key, required this.userId});

  @override
  // ignore: library_private_types_in_public_api
  _StudentPendingRequestsPageState createState() => _StudentPendingRequestsPageState();
}

class _StudentPendingRequestsPageState extends State<StudentPendingRequestsPage> {
  Map<String, dynamic>? userData;


  @override
  void initState() {
    super.initState();
    _getUserData();

  }

  var approvalField;
  var adminUserId;
  String? adminDepartment;
  String adminDesignation =' ';
  var hodApprovalField;
  Future<void> _getUserData() async {
    try {
      await fetchAdminDepartmentandDesignation();
      getApprovalField(adminDesignation, adminDepartment);

      DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final data = documentSnapshot.data();
      String HODFIELD ='';
      if (data != null) {
        // Get the branch of the student
        final branch = data['branch'];



        // Map branches to corresponding HOD approval variables
        if (['Information Technology', 'Computer Science & Engineering', 'Integrated Dual Degree (CSE+AI)', 'Computer Science & Design']
            .contains(branch)) {
          HODFIELD= 'hodCSApproval';
        } else if (branch == 'Chemical Engineering') {
          HODFIELD = 'hodCEApproval';
        } else {
          // Handle unsupported branches (optional)
         HODFIELD = '';
        }
      }

      setState(() {
        hodApprovalField = HODFIELD;
        userData = documentSnapshot.data(); // Save data to state
      });




    } catch (e) {
      print('Error fetching user data: $e');
    }
  }



  Future<void> fetchAdminDepartmentandDesignation() async {

    adminUserId = (FirebaseAuth.instance.currentUser?.uid)!;
    try {
      // Fetch the admin document from Firestore
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('admins') // Replace with your admin collection name
          .doc(adminUserId)
          .get();

      // Check if the document exists
      if (docSnapshot.exists) {
        // Cast the document data to Map<String, dynamic> and access the 'department' field
        var data = docSnapshot.data() as Map<String, dynamic>;
        adminDepartment = data['department'];
        adminDesignation = data['designation'];

      } else {
        print('Admin not found');
        adminDepartment=  null;
      }
    } catch (error) {
      print('Error fetching admin data: $error');
      adminDepartment =  null;
    }
  }

  void getApprovalField(String adminDesignation, String? adminDepartment) {
    switch (adminDesignation) {
      case 'Chief Warden':
        approvalField= 'chiefWardenApproval';
      case 'DoAA':
        approvalField= 'doaaApproval';
      case 'Warden':
        approvalField= 'wardenApproval';
      case 'Head of Department':
      // Determine the HOD-specific approval field
        if (adminDepartment == 'Computer Science & Engineering') {
          approvalField= 'hodCSApproval';
        } else if (adminDepartment == 'Petroleum Engineering') {
          approvalField= 'hodPEApproval';
        } else if (adminDepartment == 'Chemical Engineering') {
          approvalField= 'hodCEApproval';
        } else {
          throw Exception('Unsupported HOD department: $adminDepartment');
        }

    }
  }


String userId =" ";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Gate Passes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('GatePasses')
            .where('request', isEqualTo: 0) // Only pending requests
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading pending requests'));
          }
         userId = widget.userId;

          var requests = snapshot.data?.docs ?? [];

          return ListView(
            children: requests.map((requestDoc) {
              var requestData = requestDoc.data() as Map<String, dynamic>;
              // ignore: unused_local_variable
              String gatePassId = requestDoc.id;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0), // Rounded corners
                ),
                color: Colors.yellow.shade100,
                elevation: 4.0, // Add elevation for a shadow effect
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${userData?['name'] ?? 'Unknown'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '(${userData?['rollNo'] ?? 'N/A'})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2.0),
                      Text('Out Time: ${_formatDateTime(requestData['timeOut'])}'),
                      const SizedBox(height: 2.0),
                      Text('In Time: ${_formatDateTime(requestData['timeIn'])}'),
                      const SizedBox(height: 8.0),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await _updateRequestStatus(
                                  userId, gatePassId, 1); // Approve
                            },
                            child: const Text('Approve',
                                style:
                                TextStyle(color: Colors.green)),
                          ),
                          TextButton(
                            onPressed: () {
                              _showRejectReasonDialog(
                                  context, userId, gatePassId);
                            },
                            child: const Text('Reject',
                                style:
                                TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _showGatePassDetails(context, widget.userId, gatePassId, requestData),
                ),
              );
            }).toList(),
          );

        },
      ),
    );
  }

  Future<void> _updateRequestStatus(
      String userId, String gatePassId, int status) async
  {

    try {

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('GatePasses')
          .doc(gatePassId)
          .update({approvalField: status});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(milliseconds: 800),
          content: Text(status == 1 ? 'Request approved' : 'Request rejected'),
        ),
      );

// Step 2: Retrieve the branch and GatePass data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();

        if (userData != null) {
          // Get the branch of the student
          final branch = userData['branch'];

          // Map branches to corresponding HOD approval variables

          if (['Information Technology', 'Computer Science', 'IDD', 'CSD']
              .contains(branch)) {
            hodApprovalField = 'hodCSApproval';
          } else if (branch == 'Chemical Engineering') {
            hodApprovalField = 'hodCEApproval';
          } else {
            // Handle unsupported branches (optional)
            hodApprovalField = '';
          }







          // If a valid HOD approval field is found, proceed with checks
          if (hodApprovalField.isNotEmpty) {
            // Get the specific GatePass document
            final gatePassDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('GatePasses')
                .doc(gatePassId)
                .get();

            if (gatePassDoc.exists) {
              final gatePassData = gatePassDoc.data();

              if (gatePassData != null) {
                // Retrieve approval variables
                final hodApproval = gatePassData[hodApprovalField] ?? 0;
                final doaaApproval = gatePassData['doaaApproval'] ?? 0;
                final chiefWardenApproval = gatePassData['chiefWardenApproval'] ?? 0;

                // Check if all conditions are met
                if (hodApproval == 1 && doaaApproval == 1 && chiefWardenApproval == 1) {
                  // Step 3: Update the request variable
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('GatePasses')
                      .doc(gatePassId)
                      .update({'request': 1});
                }
                else if(hodApproval == -1 || doaaApproval == -1 || chiefWardenApproval == -1)
                {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('GatePasses')
                      .doc(gatePassId)
                      .update({'request': -1});

                }
              }
            }
          }
        }
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: ${e.toString()}')),
      );
    }
  }



  // Function to show rejection reason dialog
  void _showRejectReasonDialog(
      BuildContext context, String userId, String gatePassId,
      {bool isFromDetailsPage = false})
  {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reason for Rejecting'),
          content: SizedBox(
            height: 200,  // Limit the height
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Enter reason for rejection',
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                if (reasonController.text.isEmpty)
                  Text(
                    'Please provide a reason.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String rejectReason = reasonController.text.trim();

                if (rejectReason.isNotEmpty) {
                  await _updateRequestStatus(userId, gatePassId, -1);
                  await _saveRejectReason(userId, gatePassId, rejectReason);

                  if (isFromDetailsPage) {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  } else {
                    Navigator.pop(context);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please provide a reason for rejection.'),
                  ));
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );

  }

// Function to save the rejection reason in the database
  Future<void> _saveRejectReason(
      String userId, String gatePassId, String rejectReason) async {
    try {
      // Update the 'RejectReason' field in the correct document path
      await FirebaseFirestore.instance
          .collection('users') // Collection name should be 'users'
          .doc(userId) // User document ID
          .collection('GatePasses') // 'GatePasses' sub-collection
          .doc(gatePassId) // Gate pass document ID
          .update({
        'RejectReason': rejectReason, // Save rejection reason
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save rejection reason: ${e.toString()}'),
      ));
    }
  }



  void _showGatePassDetails(
      BuildContext context, String userId, String gatePassId, Map<String, dynamic> requestData) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Gate Pass Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                ...[
                  {'label': 'Name', 'value': userData?['name']},
                  {'label': 'Roll No.', 'value': userData?['rollNo']},
                  {'label': 'Branch', 'value': userData?['branch']},
                  {'label': 'Out Time', 'value': _formatDateTime(requestData['timeOut'])},
                  {'label': 'In Time', 'value': _formatDateTime(requestData['timeIn'])},
                  {'label': 'Purpose', 'value': requestData['purpose']},
                  {'label': 'Place', 'value': requestData['place']},
                  {'label': 'Overnight Stay', 'value': requestData['overnightStayInfo']},
                  {'label': 'Contact No.', 'value': userData?['phone']},
                  {'label': 'DoAA Approval', 'value': requestData['doaaApproval']},
                  {'label': 'Chief Warden Approval', 'value': requestData['chiefWardenApproval']},
                  {'label': 'HOD Approval', 'value': requestData[hodApprovalField]},
                ].map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${item['label']}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: Text('${item['value']}'),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Not specified';
    DateTime date = timestamp.toDate();
    return '${TimeOfDay.fromDateTime(date).format(context)}, ${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
