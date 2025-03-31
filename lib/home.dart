// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:admin_app/approved.dart';
import 'package:admin_app/editprofile.dart';
import 'package:admin_app/login.dart';
import 'package:admin_app/rejected.dart';
import 'package:admin_app/statistics.dart';
import 'package:admin_app/studentdatabase.dart';
import 'package:admin_app/update_expired_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'addadmin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  var UserId;
  var adminUserId;
  List<String> selectedRequests = []; // List to hold selected request IDs
  var selectedBatch;
  String? _profileImage;
  String? adminDepartment;
  String adminDesignation =' ';
  var approvalField;

  // Function to handle long press
  void onLongPress(String gatePassId) {
    setState(() {
      // Toggle selection: add to the list if it's not selected, or remove if it is
      if (selectedRequests.contains(gatePassId)) {
        selectedRequests.remove(gatePassId);
      } else {
        selectedRequests.add(gatePassId);
      }
    });
  }




  int pendingRequestsCount = 0;
  int approvedRequestsCount = 0;
  int rejectedRequestsCount = 0;

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
        if(adminDepartment == 'Computer Science & Engineering' ) {
          approvalField= 'hodCSApproval';
        } else if (adminDepartment == 'Petroleum Engineering') {
          approvalField= 'hodPEApproval';
        } else if (adminDepartment == 'Chemical Engineering') {
          approvalField= 'hodCEApproval';
        }
        else if (adminDepartment == 'Mathematics & Computing') {
          approvalField= 'hodM&CApproval';
        }
        else if (adminDepartment == 'Electronics Engineering') {
          approvalField= 'hodEEApproval';
        }
        else {
          throw Exception('Unsupported HOD department: $adminDepartment');
        }

    }
  }

  Future<String> _getUserIdFromGatePass(String gatePassId) async {
    try {
      // Get all users
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id; // User's document ID

        // Check if a document with the gatePassId exists in the user's GatePasses subcollection
        final gatePassDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('GatePasses')
            .doc(gatePassId)
            .get();

        // If the document exists, return the userId
        if (gatePassDoc.exists) {
          return userId;
        }
      }

      // If no gate pass is found, return an empty string
      print('GatePassId: $gatePassId not found in any user\'s GatePasses.');
      return '';
    } catch (e) {
      print('Error fetching UserId for GatePassId: $e');
      return '';
    }
  }



  Future<void> approveSelectedRequests() async {
    for (String gatePassId in selectedRequests) {
      try {
        // Fetch the userId from the gate pass document
        String userId = await _getUserIdFromGatePass(gatePassId);

        // Update the request status if userId is found
        if (userId.isNotEmpty) {
          await _updateRequestStatus(userId, gatePassId, 1);
        } else {
          throw Exception('UserId not found for GatePassId: $gatePassId');
        }
      } catch (e) {
        print('Error processing request for $gatePassId: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve request for $gatePassId')),
        );
      }
    }

    setState(() {
      // Clear selected requests after approval
      selectedRequests.clear();
    });
  }


  Future<void> _refreshRequests() async {
    await checkAndUpdateExpiredGatePasses();

    getApprovalField(adminDesignation, adminDepartment);

    await _calculateRequestCounts();

  }

  @override
  void initState() {
    super.initState();
     checkAndUpdateExpiredGatePasses();
   fetchAdminDepartmentandDesignation();
    _calculateRequestCounts();

  }

  Future<void> _calculateRequestCounts() async {
    await fetchAdminDepartmentandDesignation();

    getApprovalField(adminDesignation, adminDepartment);
    int pendingCount = 0;
    int approvedCount = 0;
    int rejectedCount = 0;

    try {
      // Fetch users based on department (for HOD) or all users otherwise
      final usersSnapshot= await FirebaseFirestore.instance
          .collection('users')
          .get();




      // Iterate over users to calculate request counts
      for (var userDoc in usersSnapshot.docs) {
        final gatePassesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('GatePasses')
            .get();

        for (var gatePassDoc in gatePassesSnapshot.docs) {
          final requestData = gatePassDoc.data();

          if (requestData[approvalField] == 0) {
            pendingCount++;
          } else if (requestData[approvalField] == 1) {
            approvedCount++;
          } else if (requestData[approvalField] == -1) {
            rejectedCount++;
          }
        }
      }

      // Update the state with the calculated counts
      setState(() {
        pendingRequestsCount = pendingCount;
        approvedRequestsCount = approvedCount;
        rejectedRequestsCount = rejectedCount;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating request counts: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 20,  // Set the size of the profile picture
              backgroundImage: _profileImage != null && _profileImage!.isNotEmpty
                  ? NetworkImage(_profileImage!)  // Use network image if available
                  : AssetImage('assets/profile_pic.jpg') as ImageProvider,  // Default image if no profile pic
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const AdminEditProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs
                    .clear();
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminLoginPage()),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logout failed: ${e.toString()}')),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () async {
              // Fetch the current admin ID
              String? adminId = FirebaseAuth.instance.currentUser?.uid;


              if (adminId == null) {
                // Handle the case where the admin is not logged in
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unable to fetch admin ID. Please log in.')),
                );
                return;
              }

              try {
                // Fetch Superadmin status from Firestore
                DocumentSnapshot adminDoc = await FirebaseFirestore.instance
                    .collection('admins')
                    .doc(adminId)
                    .get();
                // Cast data to Map<String, dynamic>
                Map<String, dynamic>? adminData = adminDoc.data() as Map<String, dynamic>?;

                bool isSuperadmin = adminData?['SuperAdmin'] ?? false;

                // Show the dropdown menu
                showMenu(
                  context: context,
                  position: RelativeRect.fromLTRB(100, 80, 10, 0), // Adjust position as needed
                  items: [
                    PopupMenuItem(
                      value: 'student_database',
                      child: Text('Student Database'),
                    ),
                    if (isSuperadmin) // Conditionally show Add Admin
                      PopupMenuItem(
                        value: 'add_admin',
                        child: Text('Add Admin'),
                      ),
                    PopupMenuItem(
                        value:'show_statistics',
                        child: Text('Statistics')
                    )
                  ],
                ).then((value) {
                  if (value == 'student_database') {
                    // Navigate to Student Database page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => StudentDatabasePage()),
                    );
                  } else if (value == 'add_admin') {
                    // Navigate to Add Admin page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddAdminPage()),
                    );
                  }
                  else if(value == 'show_statistics') {
                    // Navigate to Statistics page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => StatisticsPage()),
                    );
                  }
                });
              } catch (e) {
                print('Error fetching admin data: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to fetch admin data.')),
                );
              }
            },
          )

        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshRequests,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Flexible(
                child: ListView(children: [
                  _buildPendingRequestsSection()
                ]
                ),
              ),
              const SizedBox(height: 16.0),
              _buildRequestsStatsSection(),
            ],
          ),
        ),
      ),
    );
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

        String profileImagePath = data['profileImage'] ?? '';

        setState(() {
          _profileImage = profileImagePath; // Store URL (string)
        });

      } else {
        print('Admin not found');
        adminDepartment=  null;
      }
    } catch (error) {
      print('Error fetching admin data: $error');
      adminDepartment =  null;
    }
  }

  Widget _buildPendingRequestsSection() {
    return Expanded(
      child: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading users'));
              }

              var users = snapshot.data?.docs ?? [];



              if (selectedBatch != null && selectedBatch!.isNotEmpty) {
                if (selectedBatch != 'all') {
                  // Filter by batch if it's not 'All Batches'
                  users = users.where((userDoc) {
                    var userData = userDoc.data() as Map<String, dynamic>;
                    String rollNo = userData['rollNo'] ?? '';
                    return rollNo.startsWith(selectedBatch!); // Compare with the 2-digit batch prefix
                  }).toList();
                }
                // If selectedBatch is 'all', no filtering will be applied, and all requests will be shown
              }


              List<Widget> tiles = [];

              // Add Dropdown for Batch Filtering
              tiles.add(
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter by Batch:',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<String>(
                        value: selectedBatch,
                        hint: const Text('Select Batch'),
                        items: [
                          {'fullYear': '2022', 'shortYear': '22'},
                          {'fullYear': '2023', 'shortYear': '23'},
                          {'fullYear': '2024', 'shortYear': '24'},
                          {'fullYear': '2025', 'shortYear': '25'},
                          {'fullYear': 'All Batches', 'shortYear': 'all'}, // Add "All Batches" option
                        ]
                            .map((batch) => DropdownMenuItem<String>(
                          value: batch['shortYear'], // Use the short year for selection
                          child: Text(
                            batch['fullYear'] == 'All Batches'
                                ? 'All Batches' // Show "All Batches" in the dropdown
                                : '${batch['fullYear']} Batch', // Show full year for other options
                          ),
                        ))
                            .toList(),
                        onChanged: (String? value) {
                          setState(() {
                            selectedBatch = value; // Store short year or "all" for filtering
                          });
                        },
                      ),

                    ],
                  ),
                ),
              );

              // Add "Select All" and "Cancel" buttons on top if selectedRequests is not empty
              if (selectedRequests.isNotEmpty) {
                tiles.add(
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Select All Checkbox
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  if (areAllRequestsSelected(users)) {
                                    clearSelectedRequests();
                                  } else {
                                    selectAllRequests(users);
                                  }
                                });
                              },
                              child: Text(
                                areAllRequestsSelected(users) ? 'Deselect All' : 'Select All',
                                style: TextStyle(color: Colors.blue), // Customize the text style as needed
                              ),
                            ),

                          ],
                        ),
                        // Cancel Button
                        TextButton(
                          onPressed: () {
                            setState(() {
                              clearSelectedRequests();
                            });
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              tiles.add(Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Pending Requests',
                  style: TextStyle(fontSize: 20.0, color: Colors.black),
                ),
              ));

              getApprovalField(adminDesignation, adminDepartment);

              for (var userDoc in users) {
                var userData = userDoc.data() as Map<String, dynamic>;
                String userId = userDoc.id;

                tiles.add(
                    StreamBuilder<QuerySnapshot>(
                      stream: (approvalField != null)
                          ? FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('GatePasses')
                          .where(approvalField, isEqualTo: 0)
                          .snapshots()
                          : Stream.empty(), // If approvalField is null, return an empty stream
                  builder: (context, gatepassSnapshot) {
                    if (gatepassSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (gatepassSnapshot.hasError) {
                      return Center(child: Text('Error loading gate passes'));
                    }

                    var requests = gatepassSnapshot.data?.docs ?? [];

                    return Column(
                      children: requests.map((requestDoc) {
                        var requestData =
                            requestDoc.data() as Map<String, dynamic>;
                        String gatePassId = requestDoc.id;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: GestureDetector(
                            onLongPress: () => onLongPress(gatePassId),
                            child: ListTile(
                              tileColor: selectedRequests.contains(gatePassId)
                                  ? Colors.blue.shade50
                                  : Colors.transparent, // Highlight if selected
                              leading: selectedRequests.isNotEmpty
                                  ? Checkbox(
                                      value:
                                          selectedRequests.contains(gatePassId),
                                      onChanged: (bool? value) {
                                        if (value == true) {
                                          setState(() {
                                            selectedRequests.add(gatePassId);
                                          });
                                        } else {
                                          setState(() {
                                            selectedRequests.remove(gatePassId);
                                          });
                                        }
                                      },
                                    )
                                  : null, // Show checkbox only when selectedRequests is not empty
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${userData['name'] ?? 'Unknown'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '(${userData['rollNo'] ?? 'N/A'})',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2.0),
                                  Text(
                                      'Out Time: ${_formatDateTime(requestData['timeOut'])}'),
                                  const SizedBox(height: 2.0),
                                  Text(
                                      'In Time: ${_formatDateTime(requestData['timeIn'])}'),
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
                              onTap: () => _showGatePassDetails(context, userId,
                                  gatePassId, userData, requestData),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ));
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tiles,
                ),
              );
            },
          ),
          // Floating Action Button
          if (selectedRequests.isNotEmpty)
            Positioned(
              bottom: 16.0,
              right: 16.0,
              child: FloatingActionButton.extended(
                onPressed: approveSelectedRequests,
                label: Text('Approve All'),
                icon: Icon(Icons.check),
                backgroundColor: Colors.green,
              ),
            ),
        ],
      ),
    );
  }

  bool areAllRequestsSelected(List<dynamic> users) {
    for (var userDoc in users) {
      var userId = userDoc.id;
      if (!selectedRequests.contains(userId)) {
        return false; // At least one request is not selected
      }
    }
    return true; // All requests are selected
  }

  void selectAllRequests(List users) {
    // Select all requests


    for (var userDoc in users) {
      var userId = userDoc.id;
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('GatePasses')
          .where(approvalField, isEqualTo: 0)
          .get()
          .then((snapshot) {
        for (var requestDoc in snapshot.docs) {
          String gatePassId = requestDoc.id;
          if (!selectedRequests.contains(gatePassId)) {
            selectedRequests.add(gatePassId);
          }
        }
      });
    }
  }

  void clearSelectedRequests() {
    // Clear all selections
    setState(() {
      selectedRequests.clear();
    });
  }

  void selectRequest(String gatePassId) {
    // Add a specific request to the selection list
    setState(() {
      selectedRequests.add(gatePassId);
    });
  }

  void deselectRequest(String gatePassId) {
    // Remove a specific request from the selection list
    setState(() {
      selectedRequests.remove(gatePassId);
    });
  }

  void deselectAllRequests(List users) {
    // Select all requests


    for (var userDoc in users) {
      var userId = userDoc.id;
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('GatePasses')
          .where(approvalField, isEqualTo: 0)
          .get()
          .then((snapshot) {
        for (var requestDoc in snapshot.docs) {
          String gatePassId = requestDoc.id;
          if (!selectedRequests.contains(gatePassId)) {
            selectedRequests.remove(gatePassId);
          }
        }
      });
    }
  }

  Widget _buildRequestsStatsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Use Expanded to allow the button to resize based on available space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4.0), // Add horizontal padding
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ApprovedRequestsPage(adminDesignation: adminDesignation,adminDepartment:adminDepartment ,),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity,
                        60), // Button takes full available width
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Center(
                    child: RichText(
                      textAlign: TextAlign.center, // Center the text
                      text: TextSpan(
                        text: 'Approved Requests ',
                        style: TextStyle(color: Colors.black),
                        children: [
                          TextSpan(
                            text: '($approvedRequestsCount)',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Use Expanded for the second button too
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4.0), // Add horizontal padding
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RejectedRequestsPage(adminDesignation: adminDesignation,adminDepartment: adminDepartment,),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity,
                        60), // Button takes full available width
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: Center(
                    child: RichText(
                      textAlign: TextAlign.center, // Center the text
                      text: TextSpan(
                        text: 'Rejected Requests ',
                        style: TextStyle(color: Colors.black),
                        children: [
                          TextSpan(
                            text: '($rejectedRequestsCount)',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showGatePassDetails(
      BuildContext context,
      String userId,
      String gatePassId,
      Map<String, dynamic> userData,
      Map<String, dynamic> requestData) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Gate Pass Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userData['profilePic'] != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                          8.0), // Adjust the value for rounded corners or set it to 0 for a perfect square.
                      child: Image.network(
                        userData['profilePic'],
                        width: 120.0, // Adjust the width as needed
                        height: 150.0, // Adjust the height as needed
                        fit: BoxFit
                            .cover, // Ensures the image covers the container
                      ),
                    ),
                  ),
                const SizedBox(height: 20), // Add space after the picture
                ...[
                  {'label': 'Name', 'value': userData['name']},
                  {'label': 'Roll No.', 'value': userData['rollNo']},
                  {'label': 'Branch', 'value': userData['branch']},
                  {
                    'label': 'Out Time',
                    'value': _formatDateTime(requestData['timeOut'])
                  },
                  {
                    'label': 'In Time',
                    'value': _formatDateTime(requestData['timeIn'])
                  },
                  {'label': 'Purpose', 'value': requestData['purpose']},
                  {'label': 'Place', 'value': requestData['place']},
                  {
                    'label': 'Overnight Stay',
                    'value': requestData['overnightStayInfo']
                  },
                  {'label': 'Contact No.', 'value': userData['phone']},
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
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black), // Black border
                    borderRadius: BorderRadius.circular(
                        8.0), // Rounded corners for the button
                  ),
                  child: TextButton(
                    onPressed: () async {
                      await _updateRequestStatus(userId, gatePassId, 1);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Approve',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 60), // Add space between buttons
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black), // Black border
                    borderRadius: BorderRadius.circular(
                        8.0), // Rounded corners for the button
                  ),
                  child: TextButton(
                    onPressed: () {
                      // Show the rejection reason dialog instead of directly updating the status
                      _showRejectReasonDialog(context, userId, gatePassId,
                          isFromDetailsPage: true);
                    },
                    child: Text(
                      'Reject',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
          String hodApprovalField;
          if (['Information Technology', 'Computer Science & Engineering', 'Integrated Dual Degree (CSE+AI)', 'Computer Science & Design']
              .contains(branch)) {
            hodApprovalField = 'hodCSApproval';
          } else if (branch == 'Chemical Engineering') {
            hodApprovalField = 'hodCEApproval';
          }
          else if (branch == 'Petroleum Engineering'  ||branch == 'Integrated Dual Degree (Petroleum)' ) {
            hodApprovalField = 'hodPEApproval';
          }
          else if (branch == 'Electronics Engineering Major in E-Vehicle'  ||branch == 'Electronics Engineering' ) {
            hodApprovalField = 'hodPEApproval';
          }


          else {
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
                final wardenApproval = gatePassData['wardenApproval']??0;

               if(gatePassData['gatepassType']=='OUT STATION')
                 {
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

               else if((gatePassData['gatepassType']=='EMERGENCY') || (gatePassData['gatepassType']=='VACATION'))
                 {
                   // Check if all conditions are met
                   if (wardenApproval == 1) {
                     // Step 3: Update the request variable
                     await FirebaseFirestore.instance
                         .collection('users')
                         .doc(userId)
                         .collection('GatePasses')
                         .doc(gatePassId)
                         .update({'request': 1});
                   }
                   else if(wardenApproval == -1)
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
      }


      await _calculateRequestCounts(); // Recalculate counts after status update
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: ${e.toString()}')),
      );
    }
  }

  // Function to show rejection reason dialog
  void _showRejectReasonDialog(
      BuildContext context, String userId, String gatePassId,
      {bool isFromDetailsPage = false}) {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reason for Rejecting'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A nicely styled text input field
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Enter reason for rejection',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
                maxLines: 4, // Allow multiple lines
              ),
              const SizedBox(height: 10),
              // Error message if input is empty
              if (reasonController.text.isEmpty)
                Text(
                  'Please provide a reason.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                    context); // Close the dialog without doing anything
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String rejectReason = reasonController.text.trim();

                if (rejectReason.isNotEmpty) {
                  // Perform the two operations
                  await _updateRequestStatus(userId, gatePassId, -1);
                  await _saveRejectReason(userId, gatePassId, rejectReason);

                  if (isFromDetailsPage) {
                    Navigator.pop(context); // Close the rejection reason dialog
                    Navigator.pop(context); // Close the request details dialog
                  } else {
                    Navigator.pop(context); // Close the rejection reason dialog
                  }
                } else {
                  // Show a warning if no reason is provided
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
}
