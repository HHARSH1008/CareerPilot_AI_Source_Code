// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class ThemeController extends ChangeNotifier {
//   ThemeController._();

//   static final ThemeController instance =
//       ThemeController._();

//   ThemeMode _themeMode = ThemeMode.light;

//   ThemeMode get themeMode => _themeMode;

//   bool get isDark =>
//       _themeMode == ThemeMode.dark;

//   Future<void> loadTheme() async {
//     try {
//       final user =
//           FirebaseAuth.instance.currentUser;

//       if (user == null) {
//         _themeMode = ThemeMode.light;
//         notifyListeners();
//         return;
//       }

//       final doc = await FirebaseFirestore
//           .instance
//           .collection('users')
//           .doc(user.uid)
//           .get();

//       final data = doc.data();

//       if (data == null) {
//         _themeMode = ThemeMode.light;
//         notifyListeners();
//         return;
//       }

//       final settings =
//           data['profileSettings'];

//       if (settings is Map) {
//         final appearance =
//             settings['appearance']
//                 ?.toString()
//                 .toLowerCase();

//         if (appearance == 'dark') {
//           _themeMode = ThemeMode.dark;
//         } else {
//           _themeMode = ThemeMode.light;
//         }
//       } else {
//         _themeMode = ThemeMode.light;
//       }

//       notifyListeners();
//     } catch (e) {
//       debugPrint(
//         'Theme Load Error: $e',
//       );

//       _themeMode = ThemeMode.light;
//       notifyListeners();
//     }
//   }

//   Future<void> setTheme(
//     ThemeMode mode,
//   ) async {
//     _themeMode = mode;

//     notifyListeners();

//     try {
//       final user =
//           FirebaseAuth.instance.currentUser;

//       if (user == null) return;

//       final appearance =
//           mode == ThemeMode.dark
//               ? 'dark'
//               : 'light';

//       await FirebaseFirestore
//           .instance
//           .collection('users')
//           .doc(user.uid)
//           .set(
//         {
//           'profileSettings': {
//             'appearance': appearance,
//           },
//           'updatedAt':
//               FieldValue.serverTimestamp(),
//         },
//         SetOptions(merge: true),
//       );
//     } catch (e) {
//       debugPrint(
//         'Theme Save Error: $e',
//       );
//     }
//   }

//   Future<void> toggleTheme() async {
//     if (_themeMode == ThemeMode.dark) {
//       await setTheme(
//         ThemeMode.light,
//       );
//     } else {
//       await setTheme(
//         ThemeMode.dark,
//       );
//     }
//   }
// }