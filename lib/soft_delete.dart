import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'at_risk_logic.dart';

/// Recycle Bin ka soft delete: students, enquiries, placements, companies.
/// Record mitta nahi, bas isDeleted / deletedAt / deletedBy lag jaate hain.
/// Purane aur seeded docs me ye field nahi hota, isliye query me where nahi,
/// har jagah client-side [isLive] se filter hota hai.

/// Recycle Bin wale collections
const List<String> kBinCollections = ['students', 'enquiries', 'placements', 'companies'];

/// true = record Recycle Bin me nahi hai
bool isLive(Map<String, dynamic>? data) => data != null && data['isDeleted'] != true;

/// Snapshot ke sirf live docs
List<QueryDocumentSnapshot<Map<String, dynamic>>> liveDocs(QuerySnapshot<Map<String, dynamic>> snap) =>
    snap.docs.where((d) => isLive(d.data())).toList();

/// Untyped snapshot (`StreamBuilder<QuerySnapshot>`) ke sirf live docs
List<QueryDocumentSnapshot> liveDocsOf(QuerySnapshot snap) =>
    snap.docs.where((d) => isLive(d.data() as Map<String, dynamic>?)).toList();

/// Record ko Recycle Bin me bhejta hai
Future<void> softDelete(DocumentReference ref) => ref.update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': FirebaseAuth.instance.currentUser?.uid,
    });

/// Teeno field hata deta hai, record bilkul pehle jaisa
Future<void> restoreFromBin(DocumentReference ref) => ref.update({
      'isDeleted': FieldValue.delete(),
      'deletedAt': FieldValue.delete(),
      'deletedBy': FieldValue.delete(),
    });

/// Deleted trainees ke Trainee ID (VIS-...). Placements isi se jude hote hain,
/// isliye ginti me in IDs wali placements chhod di jaati hain. Khali ya
/// anjaan Trainee ID wali placement ginti me rehti hai.
Set<String> deletedTraineeIds(Iterable<Map<String, dynamic>> students) => students
    .where((s) => !isLive(s))
    .map((s) => (s['traineeId'] ?? '').toString().trim())
    .where((id) => id.isNotEmpty)
    .toSet();

/// Placement kisi deleted trainee ki nahi hai aur khud bhi deleted nahi
bool isCountablePlacement(Map<String, dynamic> p, Set<String> deletedIds) =>
    isLive(p) && !deletedIds.contains((p['traineeId'] ?? '').toString().trim());

/// Attendance me sirf [liveIds] (live trainees ke doc id) wali entries.
/// Attendance docs khud nahi badalte, bas ginti me deleted trainee nahi aata.
List<AttendanceDay> liveAttendance(Iterable<AttendanceDay> days, Set<String> liveIds) => [
      for (final d in days)
        AttendanceDay(
          d.date,
          {for (final e in d.statusMap.entries) if (liveIds.contains(e.key)) e.key: e.value},
          batchName: d.batchName,
        ),
    ];
