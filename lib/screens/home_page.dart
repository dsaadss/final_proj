// lib/screens/home_page.dart

import 'dart:io'; // Needed to read files
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; // Needed to find the folder
import 'package:model_viewer_plus/model_viewer_plus.dart'; // Needed to view the model
import 'furniture_assembly_page.dart';

import '../widgets/action_card.dart';
import 'upload_page.dart';
import 'test_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  
  // This list will hold the real folders found on your phone
  List<FileSystemEntity> _historyFolders = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    // Load the history as soon as the app starts
    _loadHistory();
  }

  // --- 1. LOAD HISTORY FUNCTION ---
  Future<void> _loadHistory() async {
    setState(() { _isLoadingHistory = true; });
    
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      
      // Get all items in the documents directory
      // We only want the Directories (folders), because that's how we saved them (Folder = Furniture Name)
      final List<FileSystemEntity> entities = appDir.listSync();
      
      final List<FileSystemEntity> folders = entities.where((e) {
        return e is Directory; // Filter to keep only folders
      }).toList();

      // Sort them by date modified (newest first)
      folders.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      setState(() {
        _historyFolders = folders;
        _isLoadingHistory = false;
      });
      
    } catch (e) {
      print("Error loading history: $e");
      setState(() { _isLoadingHistory = false; });
    }
  }

  // --- 2. OPEN MODEL FUNCTION ---
void _openSavedModel(Directory folder) {
    // Navigate directly to the Assembly Page
    // We pass the whole folder so it can find ALL steps inside
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FurnitureAssemblyPage(folder: folder),
      ),
    );
  }

  // --- 3. DELETE FUNCTION (Optional) ---
  Future<void> _deleteItem(Directory folder) async {
    try {
      await folder.delete(recursive: true); // Delete folder and contents
      _loadHistory(); // Refresh the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Item deleted")),
        );
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHistory, // Pull down to refresh list
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
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

              // --- ACTION CARDS ---
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
                    onTap: () async {
                      // Wait for the Upload Page to close, then reload history
                      // This ensures the new item shows up immediately when you come back!
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UploadPage()),
                      );
                      _loadHistory(); 
                    },
                  ),
                  ActionCard(
                    title: 'Camera scan',
                    imagePath: 'assets/images/camera_scan.png',
                    onTap: () { print("Camera Tapped"); },
                  ),
                  ActionCard(
                    title: 'My Furniture',
                    imagePath: 'assets/images/furniture.png',
                    onTap: () { print("Furniture Tapped"); },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              const Text(
                'History',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // --- TEST SCREEN BUTTON ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, 
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
              const SizedBox(height: 16), 

              // --- DYNAMIC HISTORY LIST ---
              if (_isLoadingHistory)
                const Center(child: CircularProgressIndicator())
              else if (_historyFolders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("No history yet. Upload a manual!"),
                  ),
                )
              else
                // Use the spread operator ... to insert the list of widgets
                ..._historyFolders.map((entity) {
                  final Directory folder = entity as Directory;
                  final String folderName = folder.path.split('/').last; // Get just the name
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
                      ),
                      title: Text(
                        folderName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: const Text("Tap to view model"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      
                      // RELOAD: Tap to open
                      onTap: () => _openSavedModel(folder),
                      
                      // DELETE: Long press to remove
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Delete Item?"),
                            content: Text("Remove '$folderName' from history?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteItem(folder);
                                },
                                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }),
                
                // Add some space at the bottom
                const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}