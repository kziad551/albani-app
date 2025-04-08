import 'package:flutter/material.dart';
import 'dart:math';
import '../config/app_config.dart';
import 'create_task_screen.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import 'edit_project_screen.dart';
import '../widgets/app_drawer.dart';
import 'project_buckets_screen.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final dynamic projectId;
  final String projectName;
  final Map<String, dynamic>? projectDetails;

  const ProjectDetailsScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.projectDetails,
  });

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> with TickerProviderStateMixin {
  // API service
  final ApiService _apiService = ApiService();
  
  // UI state
  bool _isLoading = true;
  String _errorMessage = '';
  bool _showTaskFilter = false;
  
  // Task filters
  String? _sortBy;
  String? _status;
  String? _assignee;
  String? _priority;
  String? _groupBy;
  
  // Project data
  Map<String, dynamic> _projectData = {};
  List<Map<String, dynamic>> _projectBuckets = [];
  List<Map<String, dynamic>> _projectEmployees = [];
  
  // Maps to store bucket files and tasks
  Map<String, List<Map<String, dynamic>>> _bucketFiles = {};
  Map<String, List<Map<String, dynamic>>> _bucketTasks = {};
  
  // Tab controller and tabs
  late TabController _tabController;
  List<Map<String, dynamic>> _tabs = [];
  
  final _searchController = TextEditingController();
  
  // Add missing state variables
  String _projectName = '';
  String _projectStatus = '';
  String _projectLocation = '';
  
  @override
  void initState() {
    super.initState();
    
    // Initialize the maps
    _bucketFiles = {};
    _bucketTasks = {};
    
    // Setup tabs
    _setupTabs();
    
    // Load project data
    _loadProjectData();
  }

  Future<void> _loadProjectData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // First validate token
      final isValid = await _apiService.validateToken();
      if (!isValid) {
        throw Exception('Please log in again to continue');
      }
      
      // Get project ID and ensure it's not empty
      final projectId = widget.projectId;
      if (projectId == null || projectId.toString().trim().isEmpty) {
        throw Exception('Project ID is required');
      }
      
      debugPrint('Loading project data for ID: $projectId (type: ${projectId.runtimeType})');
      
      // Load project details with buckets included
      Map<String, dynamic> projectDetails;
      try {
        if (widget.projectDetails != null) {
          projectDetails = widget.projectDetails!;
          debugPrint('Using provided project details: ${projectDetails['title']}');
        } else {
          // This will also fetch the project's buckets
          projectDetails = await _apiService.getProjectById(projectId);
          debugPrint('Fetched project details from API: ${projectDetails['title']}');
        }
      } catch (e) {
        debugPrint('Error loading project details: $e');
        throw Exception('Failed to load project details. Please try again.');
      }
      
      if (!mounted) return;
      
      setState(() {
        _projectData = projectDetails;
        _projectName = projectDetails['title'] ?? 'Unknown Project';
        _projectStatus = projectDetails['status'] ?? 'Unknown';
        _projectLocation = projectDetails['location'] ?? 'Unknown';
      });
      
      // First set up the tabs to ensure the UI shows immediately
      _setupTabs();
      
      // Handle buckets data which should be included in the project details
      List<Map<String, dynamic>> buckets = [];
      
      if (projectDetails.containsKey('buckets') && projectDetails['buckets'] != null) {
        debugPrint('Buckets in project details type: ${projectDetails['buckets'].runtimeType}');
        
        if (projectDetails['buckets'] is List) {
          buckets = List<Map<String, dynamic>>.from(projectDetails['buckets']);
          debugPrint('Found ${buckets.length} buckets in project details');
        } else if (projectDetails['buckets'] is Map) {
          // If it's a single bucket as a map, wrap it in a list
          buckets = [Map<String, dynamic>.from(projectDetails['buckets'])];
          debugPrint('Found a single bucket in project details');
        } else if (projectDetails['buckets'] is String) {
          // Try to parse if it's a JSON string
          try {
            final parsed = jsonDecode(projectDetails['buckets']);
            if (parsed is List) {
              buckets = List<Map<String, dynamic>>.from(parsed);
            } else if (parsed is Map) {
              buckets = [Map<String, dynamic>.from(parsed)];
            }
            debugPrint('Parsed buckets from string: ${buckets.length}');
          } catch (e) {
            debugPrint('Error parsing buckets from string: $e');
          }
        }
      } else {
        debugPrint('No buckets found in project details, trying to fetch them separately');
        
        // Try to fetch buckets directly if not included in project details
        try {
          final projectGuid = projectDetails['guid'] ?? projectId;
          buckets = await _apiService.getBuckets(projectId: projectGuid);
          debugPrint('Fetched ${buckets.length} buckets separately');
        } catch (e) {
          debugPrint('Error fetching buckets separately: $e');
          // Fall back to standard buckets
          buckets = _apiService.getStandardBuckets();
          debugPrint('Using ${buckets.length} standard buckets as fallback');
        }
      }
      
      // Load project employees
      final projectGuid = projectDetails['guid'] ?? projectId;
      try {
        final employees = await _apiService.getProjectEmployees(projectGuid.toString());
        debugPrint('Loaded ${employees.length} project employees');
        if (mounted) {
          setState(() {
            _projectEmployees = employees;
          });
        }
      } catch (e) {
        debugPrint('Error loading project employees: $e');
      }
      
      // Process the buckets
      await _processProjectBuckets(buckets, projectGuid.toString());
      
    } catch (e) {
      debugPrint('Error loading project data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        
        // If unauthorized, navigate back to login
        if (e.toString().toLowerCase().contains('unauthorized') || 
            e.toString().toLowerCase().contains('log in again')) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processProjectBuckets(List<Map<String, dynamic>> buckets, String projectGuid) async {
    try {
      debugPrint('Processing ${buckets.length} buckets for project: $projectGuid');
      
      // Print all buckets and their GUIDs for debugging
      for (var bucket in buckets) {
        debugPrint('Bucket from API: ${bucket['name'] ?? bucket['title']} (${bucket['guid'] ?? 'no-guid'}) - ID: ${bucket['id'] ?? 'no-id'}');
      }
      
      // Check if buckets have GUIDs, which are crucial for API calls
      final bucketsWithoutGuid = buckets.where((b) => b['guid'] == null).length;
      if (bucketsWithoutGuid > 0) {
        debugPrint('WARNING: $bucketsWithoutGuid buckets don\'t have GUIDs, which may cause issues');
      }
      
      if (!mounted) return;
      
      setState(() {
        _projectBuckets = buckets;
        
        // Clear existing bucket assignments
        for (var tab in _tabs) {
          tab.remove('bucket');
          tab.remove('bucketGuid');
        }
        
        // First, try to match buckets by name/title directly with tabs
        for (var bucket in buckets) {
          if (bucket['guid'] == null) continue; // Skip buckets without GUIDs
          
          final bucketName = (bucket['name'] ?? '').toString().toUpperCase();
          final bucketTitle = (bucket['title'] ?? '').toString().toUpperCase();
          
          // Find matching tab
          final matchingTab = _tabs.firstWhere(
            (tab) => 
              tab['title'].toString().toUpperCase() == bucketName || 
              tab['title'].toString().toUpperCase() == bucketTitle,
            orElse: () => {},
          );
          
          if (matchingTab.isNotEmpty) {
            debugPrint('Matched bucket ${bucket['name'] ?? bucket['title']} with tab ${matchingTab['title']}');
            matchingTab['bucket'] = bucket;
            matchingTab['bucketGuid'] = bucket['guid'];
          }
        }
        
        // For any tabs without assigned buckets, try more flexible matching
        for (var tab in _tabs.where((t) => !t.containsKey('bucketGuid'))) {
          final tabTitle = tab['title'].toString().toUpperCase();
          
          // Find any bucket that contains the tab title or vice versa
          final matchingBucket = buckets.firstWhere(
            (bucket) {
              if (bucket['guid'] == null) return false; // Skip buckets without GUIDs
              
              final bucketName = (bucket['name'] ?? '').toString().toUpperCase();
              final bucketTitle = (bucket['title'] ?? '').toString().toUpperCase();
              
              return bucketName.contains(tabTitle) || 
                     tabTitle.contains(bucketName) ||
                     bucketTitle.contains(tabTitle) ||
                     tabTitle.contains(bucketTitle);
            },
            orElse: () => {},
          );
          
          if (matchingBucket.isNotEmpty) {
            debugPrint('Flexibly matched bucket ${matchingBucket['name'] ?? matchingBucket['title']} with tab ${tab['title']}');
            tab['bucket'] = matchingBucket;
            tab['bucketGuid'] = matchingBucket['guid'];
          }
        }
        
        // For tabs that still don't have buckets, use the first bucket that isn't already assigned
        final assignedBucketGuids = _tabs
            .where((t) => t.containsKey('bucketGuid'))
            .map((t) => t['bucketGuid'])
            .toList();
        
        final unassignedTabs = _tabs.where((t) => !t.containsKey('bucketGuid')).toList();
        final unassignedBuckets = buckets
            .where((b) => b['guid'] != null && !assignedBucketGuids.contains(b['guid']))
            .toList();
        
        for (int i = 0; i < unassignedTabs.length && i < unassignedBuckets.length; i++) {
          final bucket = unassignedBuckets[i];
          debugPrint('Assigning unmatched bucket ${bucket['name'] ?? bucket['title']} to tab ${unassignedTabs[i]['title']}');
          unassignedTabs[i]['bucket'] = bucket;
          unassignedTabs[i]['bucketGuid'] = bucket['guid'];
        }
        
        // For any remaining tabs, create placeholder buckets
        for (var tab in _tabs.where((t) => !t.containsKey('bucketGuid'))) {
          debugPrint('Creating placeholder bucket for tab ${tab['title']}');
          final placeholderId = '${tab['key']}-${DateTime.now().millisecondsSinceEpoch}';
          tab['bucket'] = {
            'id': tab['key'],
            'guid': placeholderId,
            'name': tab['title'],
            'title': tab['title'],
            'description': '${tab['title']} section',
            'projectGuid': projectGuid,
          };
          tab['bucketGuid'] = placeholderId;
        }
      });
      
      // Log the final tab-bucket assignments
      for (var tab in _tabs) {
        debugPrint('Final assignment: Tab ${tab['title']} → Bucket GUID: ${tab['bucketGuid']}');
      }
      
      // Load files and tasks for each tab's bucket
      for (var tab in _tabs) {
        if (tab['bucketGuid'] != null) {
          final bucketGuid = tab['bucketGuid'].toString();
          final tabTitle = tab['title'].toString();
          
          // Skip placeholder buckets
          if (bucketGuid.contains('-guid') || bucketGuid.contains('-bucket') || bucketGuid.contains(DateTime.now().year.toString())) {
            debugPrint('Skipping API calls for placeholder bucket: $bucketGuid');
            continue;
          }
          
          debugPrint('Loading files and tasks for tab $tabTitle with bucket $bucketGuid');
          
          try {
            await _loadFilesAndTasksForBucket(bucketGuid);
          } catch (e) {
            debugPrint('Error loading files and tasks for bucket $bucketGuid: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing project buckets: $e');
    }
  }

  Future<void> _loadFilesAndTasksForBucket(String bucketGuid) async {
    if (bucketGuid.isEmpty) {
      debugPrint('Warning: Empty bucketGuid provided to _loadFilesAndTasksForBucket');
      return;
    }
    
    debugPrint('Loading files and tasks for bucket GUID: $bucketGuid');
    
    // Track retries
    int retries = 0;
    const maxRetries = 2;
    
    while (retries <= maxRetries) {
      try {
        // Load files and tasks in parallel
        final filesAndTasks = await Future.wait([
          _apiService.getBucketFiles(bucketGuid),
          _apiService.getBucketTasks(bucketGuid),
        ]);
        
        final files = filesAndTasks[0];
        final tasks = filesAndTasks[1];
        
        debugPrint('Loaded ${files.length} files and ${tasks.length} tasks for bucket $bucketGuid');
        
        if (!mounted) return;
        
        setState(() {
          _bucketFiles[bucketGuid] = files;
          _bucketTasks[bucketGuid] = tasks;
        });
        
        // Successfully loaded data, exit the retry loop
        break;
      } catch (e) {
        retries++;
        debugPrint('Error loading files and tasks for bucket $bucketGuid (attempt $retries/$maxRetries): $e');
        
        if (retries <= maxRetries) {
          // Wait before retrying
          await Future.delayed(Duration(milliseconds: 500 * retries));
        } else {
          // Max retries reached, just continue without throwing
          debugPrint('Max retries reached for bucket $bucketGuid');
          
          if (!mounted) return;
          
          // If we couldn't load data, at least initialize empty lists
          setState(() {
            _bucketFiles[bucketGuid] = _bucketFiles[bucketGuid] ?? [];
            _bucketTasks[bucketGuid] = _bucketTasks[bucketGuid] ?? [];
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showTaskFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          dialogBackgroundColor: Colors.white,
        ),
        child: AlertDialog(
          title: const Text('Filter Tasks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _sortBy,
                decoration: const InputDecoration(labelText: 'Sort By'),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('None')),
                  DropdownMenuItem(value: 'title', child: Text('Title')),
                  DropdownMenuItem(value: 'status', child: Text('Status')),
                  DropdownMenuItem(value: 'assignee', child: Text('Assignee')),
                  DropdownMenuItem(value: 'priority', child: Text('Priority')),
                ],
                onChanged: (value) => setState(() => _sortBy = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Row(
                      children: [
                        Icon(Icons.pending, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Pending'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('In Progress'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Done'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _status = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _assignee,
                decoration: const InputDecoration(labelText: 'Assignee'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'oussama', child: Text('Oussama Tahmaz')),
                  DropdownMenuItem(value: 'nabih', child: Text('Nabih Darwich')),
                  DropdownMenuItem(value: 'hassan', child: Text('Hassan Bassam')),
                ],
                onChanged: (value) => setState(() => _assignee = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(
                    value: 'none',
                    child: Row(
                      children: [
                        Icon(Icons.remove, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('None'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'low',
                    child: Row(
                      children: [
                        Icon(Icons.arrow_downward, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Low'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Row(
                      children: [
                        Icon(Icons.remove, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Medium'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Row(
                      children: [
                        Icon(Icons.arrow_upward, color: Colors.red),
                        SizedBox(width: 8),
                        Text('High'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _priority = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _groupBy,
                decoration: const InputDecoration(labelText: 'Group By'),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('None')),
                  DropdownMenuItem(value: 'status', child: Text('Status')),
                  DropdownMenuItem(value: 'assignee', child: Text('Assignee')),
                  DropdownMenuItem(value: 'priority', child: Text('Priority')),
                ],
                onChanged: (value) => setState(() => _groupBy = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(String tabTitle) {
    // Find the tab that matches this title
    final tab = _tabs.firstWhere(
      (t) => t['title'] == tabTitle,
      orElse: () => {},
    );
    
    if (tab.isEmpty) {
      return const Center(
        child: Text(
          'Tab information not found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    // Get the bucket GUID from the tab
    final bucketGuid = tab['bucketGuid']?.toString();
    
    if (bucketGuid == null) {
      return const Center(
        child: Text(
          'No bucket found for this section',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    final bucket = tab['bucket'] as Map<String, dynamic>? ?? {};
    final files = _bucketFiles[bucketGuid] ?? [];
    final tasks = _bucketTasks[bucketGuid] ?? [];
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Files Section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Files',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('UPLOAD'),
                      onPressed: () async {
                        try {
                          // Show file picker
                          final result = await FilePicker.platform.pickFiles();
                          
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            if (file.path != null) {
                              // Show loading dialog
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                              
                              try {
                                // Upload the file
                                final uploadedFile = await _apiService.uploadFile(
                                  bucketGuid,
                                  file.path!,
                                );
                                
                                // Refresh the bucket
                                await _loadFilesAndTasksForBucket(bucketGuid);
                                
                                if (mounted) {
                                  // Check if Navigator can be safely used
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.pop(context); // Close loading dialog
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('File uploaded successfully'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  // Check if Navigator can be safely used
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.pop(context); // Close loading dialog
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to upload file: $e'),
                                    ),
                                  );
                                }
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint('Error picking file: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to pick file: $e'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (files.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No files found', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final fileName = file['name'] ?? 
                                    file['fileName'] ?? 
                                    file['title'] ?? 
                                    'Unnamed File';
                      
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(fileName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () async {
                                  try {
                                    final fileId = file['id'] ?? file['guid'];
                                    if (fileId == null) {
                                      throw Exception('File ID not found');
                                    }
                                    
                                    // Show loading dialog
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                    
                                    // Get download URL
                                    final downloadUrl = await _apiService.getFileDownloadUrl(fileId.toString());
                                    
                                    if (mounted) {
                                      // Check if Navigator can be safely used
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.pop(context); // Close loading dialog
                                      }
                                      
                                      // Launch URL in browser
                                      if (await canLaunchUrl(Uri.parse(downloadUrl))) {
                                        await launchUrl(Uri.parse(downloadUrl));
                                      } else {
                                        throw Exception('Could not launch URL');
                                      }
                                    }
                                  } catch (e) {
                                    debugPrint('Error downloading file: $e');
                                    if (mounted) {
                                      // Check if Navigator can be safely used
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.pop(context); // Close loading dialog if open
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to download file: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () async {
                                  try {
                                    final fileId = file['id'] ?? file['guid'];
                                    if (fileId == null) {
                                      throw Exception('File ID not found');
                                    }
                                    
                                    // Get download URL for sharing
                                    final downloadUrl = await _apiService.getFileDownloadUrl(fileId.toString());
                                    
                                    if (mounted) {
                                      // Share the URL
                                      await Share.share(
                                        'Check out this file: $downloadUrl',
                                        subject: fileName,
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('Error sharing file: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to share file: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  // Show confirmation dialog
                                  final shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete File'),
                                      content: Text('Are you sure you want to delete "$fileName"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('CANCEL'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('DELETE'),
                                        ),
                                      ],
                                    ),
                                  );
                                  
                                  if (shouldDelete == true && mounted) {
                                    try {
                                      final fileId = file['id'] ?? file['guid'];
                                      if (fileId == null) {
                                        throw Exception('File ID not found');
                                      }
                                      
                                      // Show loading dialog
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                      
                                      // Delete the file
                                      await _apiService.deleteFile(fileId.toString());
                                      
                                      // Refresh the bucket
                                      await _loadFilesAndTasksForBucket(bucketGuid);
                                      
                                      if (mounted) {
                                        // Check if Navigator can be safely used
                                        if (Navigator.of(context).canPop()) {
                                          Navigator.pop(context); // Close loading dialog
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('File deleted successfully'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('Error deleting file: $e');
                                      if (mounted) {
                                        // Check if Navigator can be safely used
                                        if (Navigator.of(context).canPop()) {
                                          Navigator.pop(context); // Close loading dialog
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to delete file: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          const Divider(height: 32),

          // Tasks Section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tasks',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('ADD TASK'),
                      onPressed: () {
                        // Navigate to task creation screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateTaskScreen(
                              projectId: widget.projectId.toString(),
                              projectName: _projectData['title'] ?? widget.projectName,
                              bucketId: bucketGuid,
                              bucketName: bucket['name'] ?? tabTitle,
                              onTaskCreated: (Map<String, dynamic> taskData) async {
                                // Handle newly created task
                                if (mounted) {
                                  setState(() {
                                    if (_bucketTasks.containsKey(bucketGuid)) {
                                      _bucketTasks[bucketGuid]!.add(taskData);
                                    } else {
                                      _bucketTasks[bucketGuid] = [taskData];
                                    }
                                  });
                                  
                                  // Refresh the bucket to get the real task data from the server
                                  try {
                                    // Give the server a moment to process the task
                                    await Future.delayed(const Duration(seconds: 1));
                                    await _loadFilesAndTasksForBucket(bucketGuid);
                                    debugPrint('Refreshed bucket tasks after task creation');
                                  } catch (e) {
                                    debugPrint('Error refreshing bucket after task creation: $e');
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.filter_list),
                      label: const Text('FILTER TASKS'),
                      onPressed: () => _showTaskFilterDialog(),
                    ),
                  ],
                ),
                if (tasks.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No tasks found', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sortAndFilterTasks(tasks, bucketGuid).length,
                    itemBuilder: (context, index) {
                      // Get the sorted/filtered tasks list
                      final filteredTasks = _sortAndFilterTasks(tasks, bucketGuid);
                      if (index >= filteredTasks.length) {
                        return const SizedBox.shrink();
                      }
                      
                      final task = filteredTasks[index];
                      
                      // Get task information with fallbacks
                      final String taskTitle = _getSafeString(task['title']) ?? _getSafeString(task['name']) ?? 'Unnamed Task';
                      final String taskDesc = _getSafeString(task['description']) ?? _getSafeString(task['desc']) ?? '';
                      final String taskStatus = _getSafeString(task['status']) ?? 'pending';
                      final String taskAssignee = _getSafeString(task['assignedTo']) ?? _getSafeString(task['assignee']) ?? 'Unassigned';
                      final String taskPriority = _getSafeString(task['priority']) ?? 'None';
                      
                      // Determine the priority color
                      Color priorityColor = Colors.grey;
                      if (taskPriority.toLowerCase() == 'high') {
                        priorityColor = Colors.red;
                      } else if (taskPriority.toLowerCase() == 'medium') {
                        priorityColor = Colors.orange;
                      } else if (taskPriority.toLowerCase() == 'low') {
                        priorityColor = Colors.green;
                      }
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: _getStatusIcon(taskStatus),
                          title: Text(taskTitle),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (taskDesc.isNotEmpty) Text(taskDesc),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Assigned to: $taskAssignee',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  if (taskPriority.toLowerCase() != 'none')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: priorityColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        taskPriority,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreateTaskScreen(
                                        projectId: widget.projectId.toString(),
                                        projectName: _projectData['title'] ?? widget.projectName,
                                        bucketId: bucketGuid,
                                        bucketName: bucket['name'] ?? tabTitle,
                                        existingTask: task,
                                        isEditMode: true,
                                        onTaskCreated: (Map<String, dynamic> updatedTask) async {
                                          // Handle updated task
                                          if (mounted) {
                                            setState(() {
                                              // Replace the old task with the updated one
                                              if (_bucketTasks.containsKey(bucketGuid)) {
                                                final index = _bucketTasks[bucketGuid]!.indexWhere((t) => 
                                                  t['id'] == task['id'] || t['guid'] == task['guid']);
                                                if (index >= 0) {
                                                  _bucketTasks[bucketGuid]![index] = updatedTask;
                                                }
                                              }
                                            });
                                            
                                            // Refresh the bucket to get the real task data from the server
                                            try {
                                              await Future.delayed(const Duration(seconds: 1));
                                              await _loadFilesAndTasksForBucket(bucketGuid);
                                              debugPrint('Refreshed bucket tasks after task update');
                                            } catch (e) {
                                              debugPrint('Error refreshing bucket after task update: $e');
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Confirm Deletion'),
                                        content: Text('Are you sure you want to delete task "$taskTitle"?'),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('CANCEL'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              
                                              try {
                                                // Show loading dialog
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (context) => const Center(
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                );
                                                
                                                final taskId = task['id'] ?? task['guid'];
                                                if (taskId == null) {
                                                  throw Exception('Task ID not found');
                                                }
                                                
                                                // Optimistically remove the task from local list first
                                                if (mounted) {
                                                  setState(() {
                                                    _bucketTasks[bucketGuid]?.removeWhere((t) => 
                                                      t['id'] == taskId || t['guid'] == taskId);
                                                  });
                                                }
                                                
                                                // Delete the task - Wait for longer timeout
                                                try {
                                                  await _apiService.deleteTask(taskId.toString())
                                                    .timeout(const Duration(seconds: 15));
                                                  
                                                  // Add a short delay to ensure server sync
                                                  await Future.delayed(const Duration(seconds: 1));
                                                  
                                                  // Get task data for the bucket to sync with server
                                                  if (mounted) {
                                                    try {
                                                      final fileBucketGuid = task['bucketGuid'] ?? task['bucketId'] ?? bucketGuid;
                                                      await _loadFilesAndTasksForBucket(fileBucketGuid);
                                                      debugPrint('Successfully synced with server after task deletion');
                                                    } catch (syncError) {
                                                      // If sync fails, it's ok, we've already removed the task locally
                                                      debugPrint('Failed to sync with server after deletion: $syncError');
                                                    }
                                                    
                                                    // Check if Navigator can be safely used
                                                    if (Navigator.of(context).canPop()) {
                                                      Navigator.pop(context); // Close loading dialog
                                                    }
                                                    
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Task "$taskTitle" deleted'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } catch (deleteError) {
                                                  debugPrint('Task deletion API error: $deleteError');
                                                  
                                                  // Add the task back to the list if API failed
                                                  if (mounted) {
                                                    setState(() {
                                                      if (_bucketTasks.containsKey(bucketGuid)) {
                                                        if (_bucketTasks[bucketGuid]?.any((t) => 
                                                          t['id'] == taskId || t['guid'] == taskId) == false) {
                                                          _bucketTasks[bucketGuid]?.add(task);
                                                        }
                                                      }
                                                    });
                                                    
                                                    // Close loading dialog if open
                                                    if (Navigator.of(context).canPop()) {
                                                      Navigator.pop(context);
                                                    }
                                                    
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Failed to delete task: $deleteError'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                debugPrint('General error during task deletion: $e');
                                                if (mounted) {
                                                  // Check if Navigator can be safely used
                                                  if (Navigator.of(context).canPop()) {
                                                    Navigator.pop(context); // Close loading dialog
                                                  }
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Failed to delete task: $e'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text('DELETE'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () {
                            // Show task details in a bottom sheet
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (context) => DraggableScrollableSheet(
                                initialChildSize: 0.6,
                                maxChildSize: 0.9,
                                minChildSize: 0.4,
                                expand: false,
                                builder: (context, scrollController) {
                                  return SingleChildScrollView(
                                    controller: scrollController,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header with close button
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Task Details',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () => Navigator.pop(context),
                                              ),
                                            ],
                                          ),
                                          const Divider(),
                                          
                                          // Title
                                          const Text(
                                            'Title',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(taskTitle),
                                          const SizedBox(height: 16),
                                          
                                          // Status
                                          Row(
                                            children: [
                                              const Text(
                                                'Status',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Chip(
                                                avatar: _getStatusIcon(taskStatus),
                                                label: Text(taskStatus),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          
                                          // Priority
                                          Row(
                                            children: [
                                              const Text(
                                                'Priority',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Chip(
                                                backgroundColor: priorityColor,
                                                label: Text(
                                                  taskPriority,
                                                  style: const TextStyle(color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          
                                          // Assignee
                                          Row(
                                            children: [
                                              const Text(
                                                'Assignee',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Chip(
                                                avatar: const CircleAvatar(
                                                  backgroundColor: Colors.blue,
                                                  child: Icon(Icons.person, size: 16, color: Colors.white),
                                                ),
                                                label: Text(taskAssignee),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          
                                          // Description
                                          const Text(
                                            'Description',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(taskDesc.isNotEmpty ? taskDesc : 'No description provided'),
                                          const SizedBox(height: 24),
                                          
                                          // Comments section
                                          const Text(
                                            'Comments',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text('No comments yet. Be the first one to comment!'),
                                          const SizedBox(height: 16),
                                          
                                          // Comment input
                                          TextField(
                                            decoration: InputDecoration(
                                              hintText: 'Type a comment...',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              suffixIcon: TextButton(
                                                onPressed: () {
                                                  // Add comment functionality
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Adding comments coming soon')),
                                                  );
                                                },
                                                child: const Text('POST'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Get the appropriate icon for a file type
  Widget _getFileIcon(String fileType) {
    IconData iconData;
    Color iconColor;
    
    switch (fileType.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
        iconData = Icons.table_chart;
        iconColor = Colors.green;
        break;
      case 'dwg':
        iconData = Icons.architecture;
        iconColor = Colors.orange;
        break;
      case 'zip':
      case 'rar':
        iconData = Icons.folder_zip;
        iconColor = Colors.purple;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        iconData = Icons.image;
        iconColor = Colors.amber;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }
    
    return Icon(iconData, color: iconColor);
  }
  
  // Get the appropriate icon for a task status
  Widget _getStatusIcon(String status) {
    IconData iconData;
    Color iconColor;
    
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'in progress':
        iconData = Icons.sync;
        iconColor = Colors.blue;
        break;
      case 'pending':
      case 'waiting':
        iconData = Icons.pending_actions;
        iconColor = Colors.orange;
        break;
      case 'cancelled':
      case 'rejected':
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'on hold':
        iconData = Icons.pause_circle;
        iconColor = Colors.amber;
        break;
      case 'review':
      case 'in review':
        iconData = Icons.rate_review;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.help_outline;
        iconColor = Colors.grey;
    }
    
    return Icon(iconData, color: iconColor);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'on hold':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  void _navigateToEditProject() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProjectScreen(
          projectId: widget.projectId,
          title: _projectData['name'] ?? _projectData['title'] ?? '',
          description: _projectData['description'] ?? '',
          location: _projectData['location'] ?? '',
          status: _projectData['status'] ?? 'In Progress',
        ),
      ),
    ).then((_) => _loadProjectData());
  }

  void _showDeleteConfirmation() {
    // For now, we'll just show a dialog without actual deletion
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('This feature is currently disabled'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Set up the tabs for the project details screen
  void _setupTabs() {
    _tabs = [
      {
        'title': 'ARCHITECTURE',
        'icon': Icons.architecture,
        'key': 'architecture',
        'defaultBucketName': 'Architecture Bucket'
      },
      {
        'title': 'STRUCTURAL DESIGN',
        'icon': Icons.construction,
        'key': 'structural',
        'defaultBucketName': 'Structural Design Bucket'
      },
      {
        'title': 'BILL OF QUANTITY',
        'icon': Icons.calculate,
        'key': 'boq',
        'defaultBucketName': 'Bill of Quantity Bucket'
      },
      {
        'title': 'PROJECT MANAGEMENT',
        'icon': Icons.business_center,
        'key': 'management',
        'defaultBucketName': 'Project Management Bucket'
      },
      {
        'title': 'ELECTRO-MECHANICAL DESIGN',
        'icon': Icons.electrical_services,
        'key': 'mechanical',
        'defaultBucketName': 'Electro-Mechanical Design Bucket'
      },
      {
        'title': 'ON SITE',
        'icon': Icons.location_on,
        'key': 'onsite',
        'defaultBucketName': 'On Site Bucket'
      },
      {
        'title': 'CLIENT SECTION',
        'icon': Icons.people,
        'key': 'client',
        'defaultBucketName': 'Client Section Bucket'
      },
    ];
    
    debugPrint('Set up ${_tabs.length} tabs');
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(showBackButton: true),
      endDrawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProjectData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Project name in blue header
                    Container(
                      color: const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      width: double.infinity,
                      child: Text(
                        _projectData['name'] ?? widget.projectName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    // Tab bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: const Color(0xFF1976D2),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF1976D2),
                        tabs: _tabs.map((tab) => Tab(
                          icon: Icon(tab['icon'] as IconData),
                          text: tab['title'] as String,
                        )).toList(),
                      ),
                    ),
                    
                    // Tab Content - directly use TabBarView without the extra titles
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: _tabs.map((tab) => _buildTabContent(tab['title'] as String)).toList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  String? _getSafeString(dynamic value) {
    if (value is String) {
      return value;
    } else if (value is num) {
      return value.toString();
    } else if (value is bool) {
      return value.toString();
    } else if (value is Map<String, dynamic>) {
      return jsonEncode(value);
    } else if (value is List<dynamic>) {
      return jsonEncode(value);
    } else {
      return null;
    }
  }

  List<Map<String, dynamic>> _sortAndFilterTasks(List<Map<String, dynamic>> tasks, String bucketGuid) {
    // Create a copy of the tasks list to avoid modifying the original
    final List<Map<String, dynamic>> filteredTasks = List.from(tasks);
    
    // Apply filters
    var result = filteredTasks.where((task) {
      final String taskTitle = _getSafeString(task['title']) ?? _getSafeString(task['name']) ?? 'Unnamed Task';
      final String taskDesc = _getSafeString(task['description']) ?? _getSafeString(task['desc']) ?? '';
      final String taskStatus = _getSafeString(task['status']) ?? 'pending';
      final String taskAssignee = _getSafeString(task['assignedTo']) ?? _getSafeString(task['assignee']) ?? 'Unassigned';
      final String taskPriority = _getSafeString(task['priority']) ?? 'None';
      
      // Apply status filter
      if (_status != null && _status != 'all') {
        final statusFilter = _status?.toLowerCase() ?? '';
        final taskStatusLower = taskStatus.toLowerCase();
        
        if (statusFilter == 'pending' && !taskStatusLower.contains('pending')) {
          return false;
        } else if (statusFilter == 'in_progress' && !taskStatusLower.contains('progress')) {
          return false;
        } else if (statusFilter == 'completed' && !taskStatusLower.contains('done') && !taskStatusLower.contains('completed')) {
          return false;
        }
      }
      
      // Apply assignee filter
      if (_assignee != null && _assignee != 'all') {
        final assigneeFilter = _assignee?.toLowerCase() ?? '';
        final taskAssigneeLower = taskAssignee.toLowerCase();
        
        if (!taskAssigneeLower.contains(assigneeFilter)) {
          return false;
        }
      }
      
      // Apply priority filter
      if (_priority != null && _priority != 'all') {
        final priorityFilter = _priority?.toLowerCase() ?? '';
        final taskPriorityLower = taskPriority.toLowerCase();
        
        if (priorityFilter != taskPriorityLower && 
            !(priorityFilter == 'none' && taskPriorityLower.isEmpty)) {
          return false;
        }
      }
      
      // Apply search filter
      if (_searchController.text.isNotEmpty) {
        final searchTerm = _searchController.text.toLowerCase();
        final taskTitleLower = taskTitle.toLowerCase();
        final taskDescLower = taskDesc.toLowerCase();
        
        if (!taskTitleLower.contains(searchTerm) && !taskDescLower.contains(searchTerm)) {
          return false;
        }
      }
      
      return true;
    }).toList();
    
    // Apply sorting if enabled
    if (_sortBy != null && _sortBy != 'none') {
      result.sort((a, b) {
        final aTitle = _getSafeString(a['title']) ?? _getSafeString(a['name']) ?? '';
        final bTitle = _getSafeString(b['title']) ?? _getSafeString(b['name']) ?? '';
        
        final aStatus = _getSafeString(a['status']) ?? '';
        final bStatus = _getSafeString(b['status']) ?? '';
        
        final aAssignee = _getSafeString(a['assignedTo']) ?? _getSafeString(a['assignee']) ?? '';
        final bAssignee = _getSafeString(b['assignedTo']) ?? _getSafeString(b['assignee']) ?? '';
        
        final aPriority = _getSafeString(a['priority']) ?? '';
        final bPriority = _getSafeString(b['priority']) ?? '';
        
        switch (_sortBy) {
          case 'title':
            return aTitle.compareTo(bTitle);
          case 'status':
            return aStatus.compareTo(bStatus);
          case 'assignee':
            return aAssignee.compareTo(bAssignee);
          case 'priority':
            // Custom priority sorting (High > Medium > Low > None)
            final aPriorityValue = _getPriorityValue(aPriority);
            final bPriorityValue = _getPriorityValue(bPriority);
            return bPriorityValue.compareTo(aPriorityValue); // Note: reversed to put high priority first
          default:
            return 0;
        }
      });
    }
    
    return result;
  }
  
  int _getPriorityValue(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }
} 