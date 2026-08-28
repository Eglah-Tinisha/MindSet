import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';

class JournalStore {
  JournalStore({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _entriesFor(String userId) {
    return _firestore.collection('users').doc(userId).collection('entries');
  }

  String _requireUserId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before accessing journal entries.');
    }
    return user.uid;
  }

  Stream<List<JournalEntry>> watchEntries() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    return _entriesFor(user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_entriesFromSnapshot);
  }

  Future<List<JournalEntry>> loadEntries() async {
    final userId = _requireUserId();
    final snapshot = await _entriesFor(
      userId,
    ).orderBy('createdAt', descending: true).get();
    return _entriesFromSnapshot(snapshot);
  }

  Future<JournalEntry> saveEntry(JournalEntry entry) async {
    final userId = _requireUserId();
    final entries = _entriesFor(userId);
    final document = entry.id.isEmpty ? entries.doc() : entries.doc(entry.id);
    final createdAt = entry.createdAt ?? DateTime.now();
    final savedEntry = JournalEntry(
      id: document.id,
      createdAt: createdAt,
      text: entry.text,
      result: entry.result,
      textResult: entry.textResult,
      audioResult: entry.audioResult,
      typingResult: entry.typingResult,
      fusionReason: entry.fusionReason,
      voiceReason: entry.voiceReason,
      voiceStrategy: entry.voiceStrategy,
      voicePipeline: entry.voicePipeline,
      voiceSttOk: entry.voiceSttOk,
      voiceSttMs: entry.voiceSttMs,
      voiceAudioMs: entry.voiceAudioMs,
      voiceTextMs: entry.voiceTextMs,
    );

    await document.set(
      _entryToFirestore(savedEntry, userId),
      SetOptions(merge: true),
    );

    return savedEntry;
  }

  Future<void> deleteEntry(String id) async {
    if (id.isEmpty) {
      return;
    }

    final userId = _requireUserId();
    await _entriesFor(userId).doc(id).delete();
  }

  Future<void> clearEntries() async {
    final userId = _requireUserId();

    while (true) {
      final snapshot = await _entriesFor(userId).limit(500).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  List<JournalEntry> _entriesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(_entryFromDocument).toList();
  }

  JournalEntry _entryFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = Map<String, dynamic>.from(document.data());
    final createdAt = _readDate(data['createdAt']);

    return JournalEntry.fromJson({
      ...data,
      'id': document.id,
      'createdAt': createdAt?.toIso8601String(),
    });
  }

  Map<String, dynamic> _entryToFirestore(JournalEntry entry, String userId) {
    return {
      'id': entry.id,
      'ownerId': userId,
      'createdAt': Timestamp.fromDate(
        (entry.createdAt ?? DateTime.now()).toUtc(),
      ),
      'text': entry.text,
      'result': entry.result?.toJson(),
      'textResult': entry.textResult?.toJson(),
      'audioResult': entry.audioResult?.toJson(),
      'typingResult': entry.typingResult?.toJson(),
      'fusionReason': entry.fusionReason,
      'voiceReason': entry.voiceReason,
      'voiceStrategy': entry.voiceStrategy,
      'voicePipeline': entry.voicePipeline,
      'voiceSttOk': entry.voiceSttOk,
      'voiceSttMs': entry.voiceSttMs,
      'voiceAudioMs': entry.voiceAudioMs,
      'voiceTextMs': entry.voiceTextMs,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  }
}
