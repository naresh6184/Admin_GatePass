import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> checkAndUpdateExpiredGatePasses() async {
  final DateTime now = DateTime.now();
  final firestore = FirebaseFirestore.instance;

  try {

    // Fetch all users
    QuerySnapshot userSnapshot = await firestore.collection('users').get();

    for (var userDoc in userSnapshot.docs) {
      var userId = userDoc.id;

      // Fetch all gate passes for this user
      QuerySnapshot gatePassSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('GatePasses')
          .get();

      for (var gatePassDoc in gatePassSnapshot.docs) {
        var gatePassData = gatePassDoc.data() as Map<String, dynamic>;

        // Check expiry date
        DateTime expiryDate = (gatePassData['timeIn'] as Timestamp).toDate();
        // If expired, update the expired status
        if (expiryDate.isBefore(now) && gatePassData['out']==0) {
          await firestore
              .collection('users')
              .doc(userId)
              .collection('GatePasses')
              .doc(gatePassDoc.id)
              .update({
            'expired': true,
          });
        }
      }
    }
  } catch (e) {
    print("Error checking and updating expired gate passes: $e");
  }
}
