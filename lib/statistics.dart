import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class StatisticsPage extends StatefulWidget {
  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateTime? startDate;
  DateTime? endDate;
  String selectedBatch = "All";
  String selectedBranch = "All";
  String selectedProgram = "All";
  String selectedGatePassType = "All";
  List<Map<String, dynamic>> gatePassData = [];
  bool isLoading = false;

  // Example dropdown options
  final List<String> batchList = ["All", "2022", "2023", "2024","2025"];
  final List<String> branchList = ["All", "Computer Science & Engineering", "Electronics Engineering", "Mechanical Engineering","Computer Science & Design","Chemical Engineering","Petroleum Engineering","Integrated Dual Degree (CSE+AI)","Integrated Dual Degree (Petroleum)","Mathematics & Computing","Information Technology"];
  final List<String> programList = ["All", "B.Tech", "PhD", "MBA"];
  final List<String> gatePassTypeList = ["All", "LOCAL", "VACATION", "OUT STATION", "EMERGENCY"];




  Future<void> fetchData() async {
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select both start and end dates')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      gatePassData = [];
    });

    // Normalize startDate and endDate to ignore time parts
    DateTime startDateNormalized = DateTime(startDate!.year, startDate!.month, startDate!.day);
    DateTime endDateNormalized = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59, 999);

    // If the dates are the same, ensure endDateNormalized covers the full day
    if (startDateNormalized == endDateNormalized) {
      endDateNormalized = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59, 999);
    }

    FirebaseFirestore firestore = FirebaseFirestore.instance;
    QuerySnapshot userSnapshot = await firestore.collection('users').get();

    for (var user in userSnapshot.docs) {
      var gatePassQuery = firestore
          .collection('users')
          .doc(user.id)
          .collection('GatePasses')
          .where('timeOut', isGreaterThanOrEqualTo: startDateNormalized)
          .where('timeOut', isLessThanOrEqualTo: endDateNormalized);

      // Apply gate pass type filter if selected
      if (selectedGatePassType != "All") {
        gatePassQuery = gatePassQuery.where('gatepassType', isEqualTo: selectedGatePassType);
      }

      // Fetch the gate pass data for each user
      QuerySnapshot gatePassSnapshot = await gatePassQuery.get();

      for (var doc in gatePassSnapshot.docs) {
        var gatePass = doc.data() as Map<String, dynamic>;
        gatePass['userId'] = user.id;

        // Fetch user data for additional filters (batch, branch, program)
        DocumentSnapshot userDoc = await firestore.collection('users').doc(user.id).get();
        var userData = userDoc.data() as Map<String, dynamic>?;

        if (userData != null) {
          bool include = true;

          // Apply additional filters
          if (selectedBatch != "All" && userData['batch'] != selectedBatch) include = false;
          if (selectedBranch != "All" && userData['branch'] != selectedBranch) include = false;
          if (selectedProgram != "All" && userData['program'] != selectedProgram) include = false;

          // If the entry passes all filters, add it to the data list
          if (include) {
            gatePassData.add({
              'userId': user.id,
              'rollNo': userData['rollNo'] ?? 'Unknown',
              'name': userData['name'] ?? 'Unknown',
              'program': userData['program'] ?? 'Unknown',
              'batch': userData['batch'] ?? 'Unknown',
              'branch': userData['branch'] ?? 'Unknown',
              'semester': userData['semester'] ?? 'Unknown',
              'phone': userData['phone'] ?? 'Unknown',
              'gatepassType': gatePass['gatepassType'] ?? 'Unknown',
              'timeOut': gatePass['timeOut'] ?? 'Unknown',
              'timeIn': gatePass['timeIn'] ?? 'Unknown',
              'request': gatePass['request'] ?? 'Unknown',
            });
          }
        }
      }
    }

    setState(() {
      isLoading = false;
    });
  }


  Future<void> exportToExcel() async {
    TextEditingController fileNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter File Name'),
          content: TextField(
            controller: fileNameController,
            decoration: InputDecoration(hintText: 'Enter a custom file name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String customFileName = fileNameController.text.isNotEmpty
                    ? fileNameController.text
                    : 'GatePassData_${DateTime.now().millisecondsSinceEpoch}';

                var excel = Excel.createExcel();  // Create Excel file
                Sheet sheet = excel.sheets[excel.getDefaultSheet()]!; // Access the default sheet

                // Define a centered style
                var centeredStyle = CellStyle(
                  horizontalAlign: HorizontalAlign.Center,
                  verticalAlign: VerticalAlign.Center,
                );

                // Set column widths
                sheet.setColWidth(0, 35); // UserId
                sheet.setColWidth(1, 10); // Roll No.
                sheet.setColWidth(2, 30); // Name
                sheet.setColWidth(3, 20); // Program
                sheet.setColWidth(4, 10); // Batch
                sheet.setColWidth(5, 30); // Branch
                sheet.setColWidth(6, 10); // Semester
                sheet.setColWidth(7, 15); // Contact No.
                sheet.setColWidth(8, 20); // Gate Pass Type
                sheet.setColWidth(9, 25); // Time Out
                sheet.setColWidth(10, 25); // Time In
                sheet.setColWidth(11, 10); // Status

                // Add headers with centered style
                List<String> headers = [
                  'UserId',
                  'Roll No.',
                  'Name',
                  'Program',
                  'Batch',
                  'Branch',
                  'Semester',
                  'Contact No.',
                  'Gate Pass Type',
                  'Time Out',
                  'Time In',
                  'Status',
                ];
                for (int i = 0; i < headers.length; i++) {
                  var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
                  cell.value = headers[i];
                  cell.cellStyle = centeredStyle;
                }

                // Add data with centered style
                for (int rowIndex = 0; rowIndex < gatePassData.length; rowIndex++) {
                  var entry = gatePassData[rowIndex];
                  List<dynamic> row = [
                    entry['userId'] ?? 'Unknown',
                    entry['rollNo'] ?? 'Unknown',
                    entry['name'] ?? 'Unknown',
                    entry['program'] ?? 'Unknown',
                    entry['batch'] ?? 'Unknown',
                    entry['branch'] ?? 'Unknown',
                    entry['semester'] ?? 'Unknown',
                    entry['phone'] ?? 'Unknown',
                    entry['gatepassType'] ?? 'Unknown',
                    entry['timeOut'] != null
                        ? DateFormat('dd-MM-yyyy HH:mm:ss').format(
                        (entry['timeOut'] is Timestamp)
                            ? (entry['timeOut'] as Timestamp).toDate()
                            : entry['timeOut'] as DateTime)
                        : 'Unknown',
                    entry['timeIn'] != null
                        ? DateFormat('dd-MM-yyyy HH:mm:ss').format(
                        (entry['timeIn'] is Timestamp)
                            ? (entry['timeIn'] as Timestamp).toDate()
                            : entry['timeIn'] as DateTime)
                        : 'Unknown',
                    entry['request'] ?? 'Unknown',
                  ];

                  for (int colIndex = 0; colIndex < row.length; colIndex++) {
                    var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex + 1));
                    cell.value = row[colIndex];
                    cell.cellStyle = centeredStyle; // Apply centered style
                  }
                }

                var fileBytes = excel.encode();
                saveFileToDownloads(fileBytes!, customFileName);

                Navigator.of(context).pop();
              },
              child: Text('Export'),
            ),

          ],
        );
      },
    );
  }


  Future<void> saveFileToDownloads(List<int> fileBytes, String customFileName) async {
    try {
      String? downloadsDirectoryPath;

      if (Platform.isAndroid) {
        final externalStorageDir = await getExternalStorageDirectory();
        if (externalStorageDir != null) {
          downloadsDirectoryPath = path.join(
              externalStorageDir.parent.parent.parent.parent.path, 'Download');
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        final appDocumentsDir = await getApplicationDocumentsDirectory();
        downloadsDirectoryPath = appDocumentsDir.path;
      } else if (Platform.isWindows || Platform.isLinux) {
        final userDirectory = Directory.current.path;
        downloadsDirectoryPath = path.join(userDirectory, 'Downloads');
      }

      if (downloadsDirectoryPath != null) {
        final filePath = path.join(downloadsDirectoryPath, '$customFileName.xlsx');
        final File() = File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        // Show a Snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to: $filePath'),
            duration: Duration(seconds: 5),
          ),
        );
        print('File saved to: $filePath');
      } else {
        print('Unable to determine downloads directory.');
      }
    } catch (e) {
      print('Error saving file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Statistics Page')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
        Column(
          children: [
            // Time Interval
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => startDate = picked);
                    },
                    child: Text(startDate == null
                        ? 'Select Start Date'
                        : DateFormat('yyyy-MM-dd').format(startDate!)),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => endDate = picked);
                    },
                    child: Text(endDate == null
                        ? 'Select End Date'
                        : DateFormat('yyyy-MM-dd').format(endDate!)),
                  ),
                ),
              ],
            ),

            // Program and Batch
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text('Program: ', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.033)),
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedProgram,
                          items: programList.map((program) {
                            return DropdownMenuItem(value: program, child: Text(program));
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedProgram = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Text('Batch: ', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.033)),
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedBatch,
                          items: batchList.map((batch) {
                            return DropdownMenuItem(value: batch, child: Text(batch));
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedBatch = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Branch
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text('Branch: ', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.033)),
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedBranch,
                          items: branchList.map((branch) {
                            return DropdownMenuItem(value: branch, child: Text(branch));
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedBranch = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Gate Pass Type
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text('Gate Pass Type: ', style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.033)),
                      Expanded(
                        child: DropdownButton<String>(
                          value: selectedGatePassType,
                          items: gatePassTypeList.map((type) {
                            return DropdownMenuItem(value: type, child: Text(type));
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedGatePassType = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Fetch Data and Export Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: fetchData,
                    child: Text('Fetch Data'),
                  ),
                ),
                SizedBox(width: 10), // Space between buttons
              ],
            ),

            // Show Loader or Data Table
            if (isLoading) CircularProgressIndicator(),
            if (!isLoading)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text('Sr. No.')),
                        DataColumn(label: Text('UserId')),
                        DataColumn(label: Text('Roll No.')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Program')),
                        DataColumn(label: Text('Batch')),
                        DataColumn(label: Text('Branch')),
                        DataColumn(label: Text('Semester')),
                        DataColumn(label: Text('Contact No.')),
                        DataColumn(label: Text('Gate Pass Type')),
                        DataColumn(label: Text('Time Out')),
                        DataColumn(label: Text('Time In')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: gatePassData.asMap().map((index, entry) {
                        return MapEntry(
                          index,
                          DataRow(cells: [
                            DataCell(Text('${index + 1}')), // Display Sr. No.
                            DataCell(Text(entry['userId'] ?? 'Unknown')),
                            DataCell(Text((entry['rollNo'] ?? 'Unknown').toString())),
                            DataCell(Text(entry['name'] ?? 'Unknown')),
                            DataCell(Text(entry['program'] ?? 'Unknown')),
                            DataCell(Text(entry['batch'] ?? 'Unknown')),
                            DataCell(Text(entry['branch'] ?? 'Unknown')),
                            DataCell(Text(entry['semester'] ?? 'Unknown')),
                            DataCell(Text(entry['phone'] ?? 'Unknown')),
                            DataCell(Text(entry['gatepassType'] ?? 'Unknown')),
                            DataCell(Text(entry['timeOut'] != null
                                ? DateFormat('dd-MM-yyyy HH:mm:ss').format(
                                (entry['timeOut'] is Timestamp)
                                    ? (entry['timeOut'] as Timestamp).toDate()
                                    : entry['timeOut'] as DateTime)
                                : 'Unknown')),
                            DataCell(Text(entry['timeIn'] != null
                                ? DateFormat('dd-MM-yyyy HH:mm:ss').format(
                                (entry['timeIn'] is Timestamp)
                                    ? (entry['timeIn'] as Timestamp).toDate()
                                    : entry['timeIn'] as DateTime)
                                : 'Unknown')),
                            DataCell(Text((entry['request'] ?? 'Unknown').toString())),
                          ]),
                        );
                      }).values.toList(),
                    ),
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: exportToExcel,
              child: Text('Export to Excel'),
            ),
          ],
        ),
      ),
    );
  }
}
