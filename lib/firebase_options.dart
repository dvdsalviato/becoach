import 'package:firebase_core/firebase_core.dart';

/// Configurazione Firebase dell'app web (Android usa google-services.json).
const webFirebaseOptions = FirebaseOptions(
  apiKey: 'WEB_API_KEY',
  authDomain: 'WEB_AUTH_DOMAIN',
  projectId: 'WEB_PROJECT_ID',
  storageBucket: 'WEB_STORAGE_BUCKET',
  messagingSenderId: 'WEB_SENDER_ID',
  appId: 'WEB_APP_ID',
);
