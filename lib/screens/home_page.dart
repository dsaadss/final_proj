// lib/screens/home_page.dart

import 'dart:io';
import 'dart:convert'; // <--- 1. ADD THIS IMPORT
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/action_card.dart';
import 'upload_page.dart';
import 'furniture_assembly_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // This list will hold the folders (Projects) found on your phone
  List<FileSystemEntity> _projectFolders = [];
  List<FileSystemEntity> _filteredProjects = [];
  bool _isLoadingHistory = true;

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_filterProjects);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter projects based on search query
  void _filterProjects() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProjects = _projectFolders;
      } else {
        _filteredProjects = _projectFolders.where((entity) {
          final folderName = entity.path.split('/').last.toLowerCase();
          return folderName.contains(query);
        }).toList();
      }
    });
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
        _filteredProjects = folders;
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
  void _openProject(Directory folder) async {
    // We use await here so when the user comes BACK from the page,
    // we reload history to update the "Step 2/3" text immediately.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FurnitureAssemblyPage(folder: folder),
      ),
    );
    _loadHistory();
  }

  // --- 3. DELETE PROJECT ---
  Future<void> _deleteProject(Directory folder) async {
    try {
      await folder.delete(recursive: true);
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Project deleted")));
      }
    } catch (e) {
      print("Error deleting: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to AR Assembly',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create your own 3D guides or view saved projects.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // SEARCH BAR
              if (_isSearching)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search projects...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ),

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
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UploadPage(),
                        ),
                      );
                      _loadHistory();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // HISTORY HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Projects',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (_isSearching && _searchController.text.isNotEmpty)
                    Text(
                      '${_filteredProjects.length} found',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
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
              else if (_filteredProjects.isEmpty &&
                  _searchController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "No projects found",
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                      Text(
                        "Try a different search term",
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              else if (_filteredProjects.isEmpty)
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
                ..._filteredProjects.map((entity) {
                  final Directory folder = entity as Directory;
                  final String folderName = folder.path.split('/').last;

                  // --- LOGIC TO READ PROGRESS -----------------------
                  String subText = "";

                  // 1. Calculate file count (total steps based on files)
                  int fileCount = 0;
                  try {
                    fileCount = folder
                        .listSync()
                        .where((e) => e.path.endsWith('.glb'))
                        .length;
                    subText = "$fileCount steps"; // Default fallback
                  } catch (_) {}

                  // 2. Check for progress.json
                  File progressFile = File('${folder.path}/progress.json');
                  if (progressFile.existsSync()) {
                    try {
                      // Read the file synchronously (it's small, so it's safe here)
                      String jsonContent = progressFile.readAsStringSync();
                      Map<String, dynamic> data = jsonDecode(jsonContent);

                      int current = data['currentStep'] ?? 0;
                      int total = data['totalSteps'] ?? fileCount;

                      // Format: Step 2/3
                      subText = "Step $current/$total";

                      // Optional: Make it look nice if finished
                      if (current >= total && total > 0) {
                        subText = "Completed ($total/$total)";
                      }
                    } catch (e) {
                      print("Error reading progress: $e");
                    }
                  }
                  // --------------------------------------------------

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
                      onTap: () => _openProject(folder),
                      onLongPress: () {
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
                                    subText, // <--- CHANGED FROM "fileCount steps"
                                    style: TextStyle(
                                      color:
                                          Colors.orange, // Highlight progress
                                      fontWeight: FontWeight.w500,
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
    );
  }
}
