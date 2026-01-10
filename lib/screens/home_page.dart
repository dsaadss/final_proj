// lib/screens/home_page.dart

import 'dart:io';
import 'dart:convert';
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
  List<FileSystemEntity> _projectFolders = [];
  List<FileSystemEntity> _filteredProjects = [];
  bool _isLoadingHistory = true;

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // 🆕 Progress tracking
  Map<String, Map<String, dynamic>> _projectProgress = {};

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

  // 🆕 Load progress for all projects
  Future<void> _loadAllProgress() async {
    Map<String, Map<String, dynamic>> allProgress = {};

    for (var folder in _projectFolders) {
      if (folder is Directory) {
        final folderName = folder.path.split('/').last;
        final progressData = await _loadProjectProgress(folder.path);
        if (progressData != null) {
          allProgress[folderName] = progressData;
        }
      }
    }

    setState(() {
      _projectProgress = allProgress;
    });
  }

  // 🆕 Load progress for a single project
  Future<Map<String, dynamic>?> _loadProjectProgress(String folderPath) async {
    try {
      final progressFile = File('$folderPath/progress.json');
      if (await progressFile.exists()) {
        final content = await progressFile.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error loading progress: $e");
    }
    return null;
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> entities = appDir.listSync();
      final List<FileSystemEntity> folders = entities.where((e) {
        return e is Directory;
      }).toList();

      folders.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      setState(() {
        _projectFolders = folders;
        _filteredProjects = folders;
        _isLoadingHistory = false;
      });

      // 🆕 Load progress after folders are loaded
      await _loadAllProgress();
    } catch (e) {
      print("Error loading history: $e");
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _openProject(Directory folder) async {
    // Navigate and wait for return
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FurnitureAssemblyPage(folder: folder),
      ),
    );

    // 🆕 Reload progress when returning from assembly page
    await _loadAllProgress();
  }

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

              // ACTION CARDS
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

              // PROJECT LIST
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

                  // Count total steps
                  int totalSteps = 0;
                  try {
                    totalSteps = folder
                        .listSync()
                        .where((e) => e.path.endsWith('_white.glb'))
                        .length;
                  } catch (_) {}

                  // 🆕 Get progress data
                  final progressData = _projectProgress[folderName];
                  final int currentStep = progressData?['currentStep'] ?? 0;
                  final int stepsLeft = totalSteps > 0
                      ? totalSteps - currentStep
                      : 0;

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
                                  // 🆕 Show progress or total steps
                                  if (totalSteps > 0 && currentStep > 0)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: stepsLeft == 0
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          stepsLeft == 0
                                              ? "Completed ✓"
                                              : "$stepsLeft/$totalSteps steps left",
                                          style: TextStyle(
                                            color: stepsLeft == 0
                                                ? Colors.green
                                                : Colors.orange.shade700,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      "$totalSteps steps",
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
    );
  }
}
