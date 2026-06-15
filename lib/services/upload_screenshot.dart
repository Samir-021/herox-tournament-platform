import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<void> uploadScreenshot(String requestId) async {
  final picker = ImagePicker();

  final image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 70,
  );

  if (image == null) return;

  final file = File(image.path);

  final ref = FirebaseStorage.instance
      .ref()
      .child('payment_screenshots/$requestId.jpg');

  await ref.putFile(file);

  final url = await ref.getDownloadURL();

  await FirebaseFirestore.instance
      .collection('join_requests')
      .doc(requestId)
      .update({
    'screenshotUrl': url,
    'status': 'verification_pending',
    'uploadedAt': FieldValue.serverTimestamp(),
  });
}