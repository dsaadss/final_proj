// lib/main.dart

// 'import' is how you bring in code from other files or packages.
// 'package:flutter/material.dart' is the core package for all Flutter UI widgets.
import 'package:flutter/material.dart';
import 'screens/home_page.dart'; // We import the home page we are about to create.

// 'void main()' is the first function that runs when your app starts.
// It's the entry point, just like in C++ or Java.
// 'runApp()' is the Flutter command to start and display your main widget.
void main() {
  runApp(const AreaApp());
}

// In Flutter, everything is a Widget. This is your main "App" widget.
// 'StatelessWidget' is a widget that *cannot* change its own properties.
// It's perfect for your main app widget, which just sets things up.
class AreaApp extends StatelessWidget {
  // 'const' means this widget is created at compile-time, which is very efficient.
  const AreaApp({super.key});

  // 'build' is the most important method in any widget.
  // It's the function that Flutter calls to *draw* the widget on the screen.
  // 'BuildContext context' tells the widget *where* it is in the widget tree.
  @override
  Widget build(BuildContext context) {
    // 'MaterialApp' is the root widget. It gives your app
    // standard Google Material Design features, like navigation and themes.
    return MaterialApp(
      // This turns off the "Debug" banner in the corner.
      debugShowCheckedModeBanner: false,
      title: 'AR Assmbly',

      // 'theme' defines the global colors, fonts, and styles for your *entire* app.
      theme: ThemeData(
        // This sets the background color for most screens.
        scaffoldBackgroundColor: const Color(0xFFFBFBFA),
        // 'fontFamily' sets the default font.
        // **IMPORTANT**: You must add this font file to your project.
        fontFamily: 'Inter',
      ),

      // 'home' defines which widget (screen) to show when the app first starts.
      // We are pointing it to the 'HomePage' widget.
      home: const HomePage(),
    );
  }
}
