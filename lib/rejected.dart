// ignore_for_file: library_private_types_in_public_api

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RejectedRequestsPage extends StatefulWidget {
  final String? adminDesignation;
  final String? adminDepartment;

  // Constructor to accept the arguments
  const RejectedRequestsPage({
    super.key,
    required this.adminDesignation,
    required this.adminDepartment,
  });

  @override
  // ignore: library_private_types_in_public_api
  _RejectedRequestsPageState createState() => _RejectedRequestsPageState();
}

class _RejectedRequestsPageState extends State<RejectedRequestsPage> {
  @override
  Widget build(BuildContext context) {

    // Accessing the passed arguments
    final String? adminDesignation = widget.adminDesignation;
    final String? adminDepartment = widget.adminDepartment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejected Requests'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading rejected requests'));
          }

          var users = snapshot.data?.docs ?? [];
          List<Widget> tiles = [];

          for (var userDoc in users) {
            var userData = userDoc.data() as Map<String, dynamic>;
            String userId = userDoc.id;
            // Determine the approval field based on designation
            String approvalField = '';
            if (adminDesignation == 'Chief Warden') {
              approvalField = 'chiefWardenApproval';
            } else if (adminDesignation == 'DoAA') {
              approvalField = 'doaaApproval';
            } else if (adminDesignation == 'Warden') {
              approvalField = 'wardenApproval';
            } else if (adminDesignation == 'Head of Department') {
              if (
                  adminDepartment == 'Computer Science & Engineering') {
                approvalField = 'hodCSApproval';
              } else if (adminDepartment == 'Petroleum Engineering') {
                approvalField = 'hodPEApproval';
              } else if (adminDepartment == 'Chemical Engineering') {
                approvalField = 'hodCEApproval';
              } else {
                throw Exception('Unsupported HOD department: $adminDepartment');
              }
            } else {
              throw Exception('Unsupported designation: $adminDesignation');
            }


            tiles.add(StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('GatePasses')
                  .where(approvalField, isEqualTo: -1)
                  .snapshots(),
              builder: (context, gatepassSnapshot) {
                if (gatepassSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (gatepassSnapshot.hasError) {
                  return const Center(child: Text('Error loading gate passes'));
                }

                var requests = gatepassSnapshot.data?.docs ?? [];

                return Column(
                  children: requests.map((requestDoc) {
                    var requestData = requestDoc.data() as Map<String, dynamic>;
                    // ignore: unused_local_variable
                    String gatePassId = requestDoc.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0), // Rounded corners
                      ),
                      color: Colors.red.shade100,
                      elevation: 4.0, // Optional: Add shadow for better visual appeal
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${userData['name'] ?? 'Unknown'}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '(${userData['rollNo'] ?? 'N/A'})',
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
                          ],
                        ),
                        onTap: () => _showGatePassDetails(context, userId, gatePassId, userData, requestData),
                      ),
                    );

                  }).toList(),
                );
              },
            ));
          }

          return ListView(
            children: tiles,
          );
        },
      ),
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
                    borderRadius: BorderRadius.circular(8.0), // Adjust the value for rounded corners or set it to 0 for a perfect square.
                    child: Image.network(
                      userData['profilePic'],
                      width: 120.0, // Adjust the width as needed
                      height: 150.0, // Adjust the height as needed
                      fit: BoxFit.cover, // Ensures the image covers the container
                    ),
                  ),
                ),
              const SizedBox(height: 20), // Add space after the picture
              ...[
                {'label': 'Name', 'value': userData['name']},
                {'label': 'Roll No', 'value': userData['rollNo']},
                {'label': 'Branch', 'value': userData['branch']},
                {'label': 'Out Time', 'value': _formatDateTime(requestData['timeOut'])},
                {'label': 'In Time', 'value': _formatDateTime(requestData['timeIn'])},
                {'label': 'Purpose', 'value': requestData['purpose']},
                {'label': 'Place', 'value': requestData['place']},
                {'label': 'Overnight Stay', 'value': requestData['overnightStayInfo']},
                {'label': 'Contact No', 'value': userData['phone']},
                {'label': 'Reason for Rejection','value':requestData['RejectReason']},
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
