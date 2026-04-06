import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  FirebaseConfig._();

  static bool get isConfigured {
    final key = dotenv.maybeGet('FIREBASE_API_KEY');
    return key != null && key.isNotEmpty;
  }

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: dotenv.get('FIREBASE_API_KEY'),
        appId: dotenv.get('FIREBASE_APP_ID'),
        messagingSenderId: dotenv.get('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: dotenv.get('FIREBASE_PROJECT_ID'),
        storageBucket: dotenv.get('FIREBASE_STORAGE_BUCKET'),
      );
}
