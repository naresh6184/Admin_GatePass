import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentLocalRequestsPage extends StatefulWidget {
  final String userId; // Add userId to fetch specific student's gate passes

  const StudentLocalRequestsPage({super.key, required this.userId});

  @override
  // ignore: library_private_types_in_public_api
  _StudentLocalRequestsPageState createState() => _StudentLocalRequestsPageState();
}

class _StudentLocalRequestsPageState extends State<StudentLocalRequestsPage> {
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      setState(() {
        userData = documentSnapshot.data(); // Save data to state
      });
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Gate Passes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('GatePasses')
            .where('gatepassType', isEqualTo: "LOCAL") // Only Local requests
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading local requests'));
          }


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
                color: Colors.blueGrey.shade100,
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
                  if (requestData['realTimeOut'] != null) // Only add if present
                    {'label': 'Actual Out Time', 'value': _formatDateTime(requestData['realTimeOut'])},
                  if (requestData['realTimeIn'] != null) // Only add if present
                    {'label': 'Actual In Time', 'value': _formatDateTime(requestData['realTimeIn'])},
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
