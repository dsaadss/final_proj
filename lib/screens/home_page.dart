// lib/screens/home_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/action_card.dart';
import 'upload_page.dart';
import 'test_screen.dart';
import 'furniture_assembly_page.dart'; // To open the player

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // This list will hold the folders (Projects) found on your phone
  List<FileSystemEntity> _projectFolders = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // --- 1. SCAN PHONE FOR FOLDERS ---
  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();

      // Get all items in the documents directory
      final List<FileSystemEntity> entities = appDir.listSync();

      // Filter: Keep only Directories (these are your furniture names)
      final List<FileSystemEntity> folders = entities.where((e) {
        return e is Directory;
      }).toList();

      // Sort by date modified (Newest projects at top)
      folders.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      setState(() {
        _projectFolders = folders;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print("Error loading history: $e");
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  // --- 2. OPEN THE ASSEMBLY PLAYER ---
  void _openProject(Directory folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // We pass the folder to the Assembly Page so it can find all steps inside
        builder: (context) => FurnitureAssemblyPage(folder: folder),
      ),
    );
  }

  // --- 3. DELETE PROJECT ---
  Future<void> _deleteProject(Directory folder) async {
    try {
      await folder.delete(
        recursive: true,
      ); // Delete folder and all models inside
      _loadHistory(); // Refresh the UI
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Project deleted")));
      }
    } catch (e) {
      print("Error deleting: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHistory, // Pull down to refresh list
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // HEADER
              const Text(
                'Welcome to AR Assembly',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your own 3D guides or view saved projects.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // ACTION CARDS (Top Grid)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: [
                  ActionCard(
                    title: 'Create Guide',
                    imagePath: 'assets/images/pdf_upload.png',
                    onTap: () async {
                      // Wait for UploadPage to close, then reload history
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UploadPage(),
                        ),
                      );
                      _loadHistory();
                    },
                  ),
                  ActionCard(
                    title: 'Quick Test',
                    imagePath: 'assets/images/camera_scan.png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TestScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // HISTORY HEADER
              const Text(
                'My Projects',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // DYNAMIC PROJECT LIST
              if (_isLoadingHistory)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_projectFolders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "No projects yet",
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                      const Text(
                        "Tap 'Create Guide' to start!",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                // Render the list of folders
                ..._projectFolders.map((entity) {
                  final Directory folder = entity as Directory;
                  final String folderName = folder.path.split('/').last;

                  // Count files inside (optional, nice for UI)
                  int fileCount = 0;
                  try {
                    fileCount = folder
                        .listSync()
                        .where((e) => e.path.endsWith('.glb'))
                        .length;
                  } catch (_) {}

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openProject(folder), // OPEN PROJECT
                      onLongPress: () {
                        // DELETE PROJECT
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Delete Project?"),
                            content: Text(
                              "Are you sure you want to delete '$folderName'?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteProject(folder);
                                },
                                child: const Text(
                                  "Delete",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // Icon Box
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.folder_open,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Text Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    folderName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$fileCount steps",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
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
