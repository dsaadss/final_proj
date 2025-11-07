// lib/screens/home_page.dart

import 'package:flutter/material.dart';
import '../widgets/action_card.dart'; // Import our reusable card
import 'upload_page.dart'; // Import the upload page for navigation
import 'test_screen.dart'; // <-- THIS IS THE NEW IMPORT FOR THE TEST SCREEN

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // State variable for the bottom navigation bar
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // ListView makes the screen scrollable
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Welcome Text
            const Text(
              'Welcome to AR Assembly',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get step-by-step instructions for your IKEA furniture and more.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Grid for PDF and Camera Scan Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
              children: [
                ActionCard(
                  title: 'PDF upload',
                  imagePath: 'assets/images/pdf_upload.png',
                  onTap: () {
                    // Navigate to the Upload Page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UploadPage(),
                      ),
                    );
                  },
                ),
                ActionCard(
                  title: 'Camera scan',
                  imagePath: 'assets/images/camera_scan.png',
                  onTap: () {
                    print("Camera Tapped!");
                  },
                ),
                ActionCard(
                  title: 'My Furniture',
                  imagePath: 'assets/images/furniture.png',
                  onTap: () {
                    print("Furniture Tapped!");
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // History Section Title
            const Text(
              'History',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ----- THIS IS THE NEW BUTTON YOU ADDED -----
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // Added some color
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Go to 3D/AR Test Screen'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TestScreen()),
                );
              },
            ),
            const SizedBox(height: 16), // Added spacing after the button
            // ---------------------------------------------

            // Your ListTile items for history...
            ListTile(
              leading: const Icon(Icons.description_outlined, size: 30),
              title: const Text(
                'IKEA Manual',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('1d ago'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, size: 30),
              title: const Text(
                'Amazon Manual',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('3d ago'),
              onTap: () {},
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
