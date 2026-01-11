import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🆕 IMPORT
import 'package:http/http.dart' as http; // 🆕 FOR CONNECTION CHECK

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

  // --- 🆕 SERVER SETTINGS DIALOG ---
 Future<void> _showSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final ipController = TextEditingController(
      text: prefs.getString('server_ip') ?? "100.x.x.x",
    );
    final portController = TextEditingController(
      text: prefs.getString('server_port') ?? "8000",
    );
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Server Configuration"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ipController,
                  decoration: const InputDecoration(labelText: "Tailscale IP"),
                ),
                TextField(
                  controller: portController,
                  decoration: const InputDecoration(labelText: "Port"),
                ),
                const SizedBox(height: 20),
                if (isTesting)
                  const CircularProgressIndicator(color: Colors.green)
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      setDialogState(() => isTesting = true);
                      try {
                        final url = Uri.parse(
                          "http://${ipController.text.trim()}:${portController.text.trim()}/",
                        );
                        final response = await http
                            .get(url)
                            .timeout(const Duration(seconds: 5));

                        if (response.statusCode == 200) {
                          final data = jsonDecode(response.body);
                          if (data['status'] == 'connected') {
                            // 🟢 User-side UI Feedback
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "🚀 Server Connected Successfully!",
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("❌ Connection Failed: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setDialogState(() => isTesting = false);
                      }
                    },
                    icon: const Icon(Icons.flash_on),
                    label: const Text("Test Connection"),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  await prefs.setString('server_ip', ipController.text.trim());
                  await prefs.setString(
                    'server_port',
                    portController.text.trim(),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text("Save Settings"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> entities = appDir.listSync();
      final List<FileSystemEntity> folders = entities
          .whereType<Directory>()
          .toList();

      folders.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );

      setState(() {
        _projectFolders = folders;
        _filteredProjects = folders;
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint("Error loading history: $e");
      setState(() => _isLoadingHistory = false);
    }
  }

  void _openProject(Directory folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FurnitureAssemblyPage(folder: folder),
      ),
    );
    _loadHistory();
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
      debugPrint("Error deleting: $e");
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
                          'Create your own 3D guides.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.settings,
                          size: 28,
                          color: Colors.grey,
                        ),
                        onPressed: _showSettingsDialog, // 🆕 SETTINGS GEAR
                      ),
                      IconButton(
                        icon: Icon(
                          _isSearching ? Icons.close : Icons.search,
                          size: 28,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) _searchController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_isSearching)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search projects...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),

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
              const Text(
                'My Projects',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (_isLoadingHistory)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filteredProjects.isEmpty)
                const Center(
                  child: Text(
                    "No projects yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ..._filteredProjects.map((entity) {
                  final Directory folder = entity as Directory;
                  final String folderName = folder.path.split('/').last;

                  String subText = "Calculating steps...";
                  int fileCount = 0;
                  try {
                    fileCount = folder
                        .listSync()
                        .where((e) => e.path.endsWith('.glb'))
                        .length;
                    subText = "$fileCount steps";
                  } catch (_) {}

                  File progressFile = File('${folder.path}/progress.json');
                  if (progressFile.existsSync()) {
                    try {
                      Map<String, dynamic> data = jsonDecode(
                        progressFile.readAsStringSync(),
                      );
                      int current = data['currentStep'] ?? 0;
                      int total = data['totalSteps'] ?? fileCount;
                      subText = current >= total
                          ? "Completed ($total/$total)"
                          : "Step $current/$total";
                    } catch (_) {}
                  }

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
                      onLongPress: () => _deleteProject(folder),
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
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subText,
                                    style: const TextStyle(
                                      color: Colors.orange,
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
