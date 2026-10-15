import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'at_risk_logic.dart';

/// Recycle Bin soft delete: students, enquiries, placements, companies.
/// The record isn't erased; it just gets isDeleted / deletedAt / deletedBy.
/// Older and seeded docs don't have these fields, so there's no query where;
/// everything is filtered client-side with [isLive].

/// Collections covered by the Recycle Bin
const List<String> kBinCollections = ['students', 'enquiries', 'placements', 'companies'];

/// true = record is not in the Recycle Bin
bool isLive(Map<String, dynamic>? data) => data != null && data['isDeleted'] != true;

/// Only the live docs of a snapshot
List<QueryDocumentSnapshot<Map<String, dynamic>>> liveDocs(QuerySnapshot<Map<String, dynamic>> snap) =>
    snap.docs.where((d) => isLive(d.data())).toList();

/// Only the live docs of an untyped snapshot (`StreamBuilder<QuerySnapshot>`)
List<QueryDocumentSnapshot> liveDocsOf(QuerySnapshot snap) =>
    snap.docs.where((d) => isLive(d.data() as Map<String, dynamic>?)).toList();

/// Moves a record to the Recycle Bin
Future<void> softDelete(DocumentReference ref) => ref.update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': FirebaseAuth.instance.currentUser?.uid,
    });

/// Removes all three fields, restoring the record exactly as before
Future<void> restoreFromBin(DocumentReference ref) => ref.update({
      'isDeleted': FieldValue.delete(),
      'deletedAt': FieldValue.delete(),
      'deletedBy': FieldValue.delete(),
    });

/// Trainee IDs (VIS-...) of deleted trainees. Placements are linked by this,
/// so placements with these IDs are left out of counts. Placements with an
/// empty or unknown Trainee ID are still counted.
Set<String> deletedTraineeIds(Iterable<Map<String, dynamic>> students) => students
    .where((s) => !isLive(s))
    .map((s) => (s['traineeId'] ?? '').toString().trim())
    .where((id) => id.isNotEmpty)
    .toSet();

/// Placement doesn't belong to a deleted trainee and isn't deleted itself
bool isCountablePlacement(Map<String, dynamic> p, Set<String> deletedIds) =>
    isLive(p) && !deletedIds.contains((p['traineeId'] ?? '').toString().trim());

/// Only attendance entries for [liveIds] (live trainees' doc ids).
/// Attendance docs aren't changed; deleted trainees are just left out of counts.
List<AttendanceDay> liveAttendance(Iterable<AttendanceDay> days, Set<String> liveIds) => [
      for (final d in days)
        AttendanceDay(
          d.date,
          {for (final e in d.statusMap.entries) if (liveIds.contains(e.key)) e.key: e.value},
          batchName: d.batchName,
        ),
    ];
