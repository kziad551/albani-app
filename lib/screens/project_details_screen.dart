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
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  
  // Set to keep track of deleted task IDs to ensure they don't reappear in UI
  Set<String> _deletedTaskIds = {};
  
  // Tab controller and tabs
  late TabController _tabController;
  List<Map<String, dynamic>> _tabs = [];
  
  final _searchController = TextEditingController();
  
  // Add missing state variables
  String _projectName = '';
  String _projectStatus = '';
  String _projectLocation = '';
  
  // Dialog context variable for safe dialog dismissal
  BuildContext? _dialogContext;
  
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
        debugPrint('Task IDs: ${tasks.map((t) => t['id'] ?? t['guid']).toList()}');
        
        if (!mounted) return;
        
        // Update the state with the fresh data
        setState(() {
          // Replace the entire map entries to ensure full refresh
          _bucketFiles[bucketGuid] = List<Map<String, dynamic>>.from(files);
          
          // Filter out any tasks we know have been deleted
          final filteredTasks = tasks.where((task) {
            final taskId = task['id']?.toString();
            final taskGuid = task['guid']?.toString();
            return !(_deletedTaskIds.contains(taskId) || _deletedTaskIds.contains(taskGuid));
          }).toList();
          
          _bucketTasks[bucketGuid] = List<Map<String, dynamic>>.from(filteredTasks);
          
          debugPrint('Updated UI with ${_bucketTasks[bucketGuid]?.length ?? 0} tasks for bucket $bucketGuid');
          debugPrint('Filtered out ${tasks.length - filteredTasks.length} deleted tasks using _deletedTaskIds cache');
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
            debugPrint('Initialized empty lists for bucket $bucketGuid');
          });
        }
      }
    }
    
    // Force a rebuilding of the UI
    if (mounted) {
      setState(() {});
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
                      label: const Text('UPLOAD FILE'),
                      onPressed: () async {
                        // Store a reference to the context for safer usage
                        final BuildContext outerContext = context;
                        
                        try {
                          // Show file picker
                          final result = await FilePicker.platform.pickFiles();
                          
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            if (file.path != null) {
                              // Show loading dialog
                              if (mounted) {
                                _showLoadingDialog(outerContext);
                              }
                              
                              try {
                                // Upload the file
                                final uploadedFile = await _apiService.uploadFile(
                                  bucketGuid,
                                  file.path!,
                                );
                                
                                // Refresh the bucket
                                await _loadFilesAndTasksForBucket(bucketGuid);
                                
                                if (mounted) {
                                  // Close loading dialog
                                  _dismissDialog(outerContext);
                                  
                                  ScaffoldMessenger.of(outerContext).showSnackBar(
                                    const SnackBar(
                                      content: Text('File uploaded successfully'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error uploading file: $e');
                                
                                // Close loading dialog
                                if (mounted) {
                                  _dismissDialog(outerContext);
                                  
                                  ScaffoldMessenger.of(outerContext).showSnackBar(
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
                            ScaffoldMessenger.of(outerContext).showSnackBar(
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
                          leading: _getFileIcon(file['type'] ?? ''),
                          title: Text(
                            fileName,
                            style: const TextStyle(
                              fontSize: 14,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () async {
                                  // Store a reference to the context for safer usage
                                  final BuildContext outerContext = context;
                                  
                                  try {
                                    // Specifically get the GUID for file download, not the ID
                                    final fileGuid = file['guid'];
                                    if (fileGuid == null) {
                                      throw Exception('File GUID not found. Download requires a GUID.');
                                    }
                                    
                                    // Get the file name from the file object
                                    final fileName = file['name'] ?? 
                                                  file['fileName'] ?? 
                                                  file['title'] ?? 
                                                  'downloaded_file';
                                    
                                    debugPrint('Starting direct download for file: $fileName with GUID: $fileGuid');
                                    
                                    // Show loading dialog with a message
                                    if (mounted) {
                                      _showLoadingDialog(outerContext);
                                    }
                                    
                                    // Get auth token and base URL
                                    final baseUrl = await _apiService.getBaseUrl();
                                    final token = await _apiService.getAuthToken();
                                    
                                    // Construct the direct download URL with the correct parameter name
                                    final downloadUrl = '$baseUrl/api/Attachments/DownloadAttachment?AttachmentGuid=$fileGuid';
                                    debugPrint('Download URL: $downloadUrl');
                                    
                                    // Create a Dio instance with auth headers
                                    final dio = Dio();
                                    dio.options.headers['Authorization'] = 'Bearer $token';
                                    
                                    // Get the downloads directory
                                    Directory directory;
                                    String filePath;
                                    
                                    if (Platform.isAndroid) {
                                      try {
                                        // Request storage permissions
                                        Map<Permission, PermissionStatus> statuses = await [
                                          Permission.storage,
                                        ].request();
                                        
                                        debugPrint('Permission statuses: $statuses');
                                        
                                        // Direct download to Downloads folder without showing share sheet
                                        final sdkVersion = await _getSdkVersion();
                                        debugPrint('Android SDK version: $sdkVersion');
                                        
                                        String downloadPath;
                                        
                                        if (sdkVersion < 29) { // Below Android 10 (Q)
                                          // Direct path to Download folder for older Android versions
                                          downloadPath = '/storage/emulated/0/Download';
                                          final downloadDir = Directory(downloadPath);
                                          if (!await downloadDir.exists()) {
                                            await downloadDir.create(recursive: true);
                                          }
                                        } else {
                                          // For Android 10+ (SDK 29+), we need to use the external storage directory
                                          // that the app has access to, no additional permissions needed due to scoped storage
                                          final externalDir = await getExternalStorageDirectory();
                                          if (externalDir == null) {
                                            throw Exception('Could not access external storage');
                                          }
                                          
                                          // Create a dedicated downloads folder within our app's external storage
                                          final appDownloadsDir = Directory('${externalDir.path}/Downloads');
                                          if (!await appDownloadsDir.exists()) {
                                            await appDownloadsDir.create(recursive: true);
                                          }
                                          downloadPath = appDownloadsDir.path;
                                        }
                                        
                                        filePath = '$downloadPath/$fileName';
                                        debugPrint('Saving file directly to: $filePath');
                                        
                                        // Download the file
                                        await dio.download(
                                          downloadUrl,
                                          filePath,
                                          onReceiveProgress: (received, total) {
                                            if (total != -1) {
                                              final progress = (received / total * 100).toStringAsFixed(0);
                                              debugPrint('Download progress: $progress%');
                                            }
                                          },
                                        );
                                        
                                        // No need to use the Share API for Android 10+ as we're using our app's
                                        // dedicated external storage space which is fully accessible
                                        
                                        // Close loading dialog
                                        if (mounted) {
                                          _dismissDialog(outerContext);
                                          
                                          // Show success message with a clear location description
                                          ScaffoldMessenger.of(outerContext).showSnackBar(
                                            SnackBar(
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Download Complete!',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(
                                                    'File: $fileName',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  Text(
                                                    'Saved to: ${sdkVersion < 29 ? 'Downloads folder' : 'App Storage/Downloads'}',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        // On any error, dismiss dialog and show error message
                                        if (mounted) {
                                          _dismissDialog(outerContext);
                                          
                                          debugPrint('Error in Android file download: $e');
                                          ScaffoldMessenger.of(outerContext).showSnackBar(
                                            SnackBar(
                                              content: Text('Download error: ${e.toString().split('\n').first}'),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 5),
                                            )
                                          );
                                        }
                                      }
                                      return; // Exit early for Android as we've handled everything
                                    } else {
                                      // iOS and other platforms
                                      directory = await getApplicationDocumentsDirectory();
                                      filePath = '${directory.path}/$fileName';
                                      debugPrint('Using app documents directory for iOS: $filePath');
                                    }
                                    
                                    // Only download file directly if we're not using the Share approach
                                    // for Android 10+ (which we already handled above)
                                    final sdkVersion = Platform.isAndroid ? await _getSdkVersion() : 0;
                                    if (!Platform.isAndroid || sdkVersion < 29) {
                                      debugPrint('Downloading file to: $filePath');
                                      await dio.download(
                                        downloadUrl,
                                        filePath,
                                        onReceiveProgress: (received, total) {
                                          if (total != -1) {
                                            final progress = (received / total * 100).toStringAsFixed(0);
                                            debugPrint('Download progress: $progress%');
                                          }
                                        },
                                      );
                                      
                                      // Close loading dialog
                                      if (mounted) {
                                        _dismissDialog(outerContext);
                                      
                                        // Show success message with location info
                                        ScaffoldMessenger.of(outerContext).showSnackBar(
                                          SnackBar(
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Download Complete!',
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  'File: $fileName',
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                                Text(
                                                  'Saved to: ${Platform.isAndroid ? "Downloads folder" : filePath}',
                                                  style: const TextStyle(fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: const Duration(seconds: 5),
                                            action: SnackBarAction(
                                              label: 'OPEN',
                                              onPressed: () async {
                                                try {
                                                  final file = File(filePath);
                                                  // Make sure file exists before trying to open it
                                                  if (await file.exists()) {
                                                    try {
                                                      // Try to open using open_file package
                                                      debugPrint('Attempting to open file with OpenFile.open: $filePath');
                                                      final result = await OpenFile.open(filePath);
                                                      debugPrint('Open file result: ${result.type} - ${result.message}');
                                                      
                                                      // If it fails, use the share method as fallback
                                                      if (result.type != ResultType.done) {
                                                        debugPrint('OpenFile failed, falling back to Share.shareXFiles');
                                                        await Share.shareXFiles([XFile(filePath)], text: 'File: $fileName');
                                                      }
                                                    } catch (openError) {
                                                      // If OpenFile throws an exception, fall back to sharing
                                                      debugPrint('Error opening file with OpenFile: $openError');
                                                      debugPrint('Falling back to Share.shareXFiles');
                                                      await Share.shareXFiles([XFile(filePath)], text: 'File: $fileName');
                                                    }
                                                  } else {
                                                    throw Exception('File not found at location: $filePath');
                                                  }
                                                } catch (e) {
                                                  debugPrint('Cannot open downloaded file: $e');
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(outerContext).showSnackBar(
                                                      SnackBar(
                                                        content: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text('Unable to open file: ${e.toString().split('\n').first}'),
                                                            const Text('Try using the Share option instead', style: TextStyle(fontSize: 12)),
                                                          ],
                                                        ),
                                                        backgroundColor: Colors.red,
                                                        action: SnackBarAction(
                                                          label: 'SHARE',
                                                          onPressed: () async {
                                                            try {
                                                              final file = File(filePath);
                                                              if (await file.exists()) {
                                                                await Share.shareXFiles([XFile(filePath)], text: 'File: $fileName');
                                                              }
                                                            } catch (shareError) {
                                                              debugPrint('Error sharing file: $shareError');
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    // Close loading dialog
                                    if (mounted) {
                                      _dismissDialog(outerContext);
                                      
                                      debugPrint('Error in download process: $e');
                                      ScaffoldMessenger.of(outerContext).showSnackBar(
                                        SnackBar(
                                          content: Text('Error downloading file: $e'),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 5),
                                        )
                                      );
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () async {
                                  // Store a reference to the context for safer usage
                                  final BuildContext outerContext = context;
                                  
                                  try {
                                    // Specifically get the GUID for file sharing, not the ID
                                    final fileGuid = file['guid'];
                                    if (fileGuid == null) {
                                      throw Exception('File GUID not found. Sharing requires a GUID.');
                                    }
                                    
                                    // Get the file name from the file object
                                    final fileName = file['name'] ?? 
                                                  file['fileName'] ?? 
                                                  file['title'] ?? 
                                                  'shared_file';
                                    
                                    debugPrint('Starting file share for: $fileName with GUID: $fileGuid');
                                    
                                    // Show loading dialog
                                    if (mounted) {
                                      _showLoadingDialog(outerContext);
                                    }
                                    
                                    // Use the dedicated API method to get the file share URL
                                    final shareUrl = await _apiService.getFileShareUrl(fileGuid.toString());
                                    debugPrint('Generated share URL: $shareUrl');
                                    
                                    // Close loading dialog 
                                    if (mounted) {
                                      _dismissDialog(outerContext);
                                    }
                                    
                                    // Share the link to the file
                                    final shareMessage = 'File: $fileName\nAccess at: $shareUrl';
                                    await Share.share(shareMessage);
                                    
                                  } catch (e) {
                                    // Close loading dialog if it's showing
                                    if (mounted) {
                                      _dismissDialog(outerContext);
                                    
                                      debugPrint('Error sharing file: $e');
                                      ScaffoldMessenger.of(outerContext).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to share file: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  // Store a reference to the context for safer usage
                                  final BuildContext outerContext = context;
                                  
                                  // Show confirmation dialog
                                  final shouldDelete = await showDialog<bool>(
                                    context: outerContext,
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
                                      // Specifically get the GUID for file deletion, not the ID
                                      final fileGuid = file['guid'];
                                      if (fileGuid == null) {
                                        throw Exception('File GUID not found. Deletion requires a GUID.');
                                      }
                                      
                                      debugPrint('Attempting to delete file with GUID: $fileGuid');
                                      
                                      // Show loading dialog
                                      _showLoadingDialog(outerContext);
                                      
                                      // Delete the file - this now handles errors internally
                                      await _apiService.deleteFile(fileGuid.toString());
                                      
                                      // Refresh the bucket
                                      await _loadFilesAndTasksForBucket(bucketGuid);
                                      
                                      if (mounted) {
                                        // Dismiss loading dialog
                                        _dismissDialog(outerContext);
                                        
                                        // Success message - note the change in message to reflect that 
                                        // deletion was attempted but may not be confirmed
                                        ScaffoldMessenger.of(outerContext).showSnackBar(
                                          const SnackBar(
                                            content: Text('File deletion request processed'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('Error deleting file: $e');
                                      
                                      // Dismiss loading dialog
                                      if (mounted) {
                                        _dismissDialog(outerContext);
                                        
                                        ScaffoldMessenger.of(outerContext).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to delete file: $e'),
                                            backgroundColor: Colors.red,
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
                    key: ValueKey('tasks-${tasks.length}-${DateTime.now().millisecondsSinceEpoch}'),
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
                      final String taskAssignee = _getSafeString(task['assignedToName']) ?? 
                                                _getSafeString(task['displayAssignee']) ?? 
                                                _getSafeString(task['assignedTo']?['displayName']) ?? 
                                                _getSafeString(task['assignedTo']?['name']) ?? 
                                                _getSafeString(task['employee']?['displayName']) ?? 
                                                _getSafeString(task['employee']?['name']) ?? 
                                                'Unassigned';
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
                                              // Store a reference to the context for safer usage
                                              final BuildContext outerContext = context;
                                              
                                              // Close the confirmation dialog
                                              Navigator.of(outerContext).pop();
                                              
                                              // Prioritize GUID over numeric ID for deletion
                                              final taskGuid = task['guid'];
                                              final taskId = task['id'];
                                              final deleteId = taskGuid ?? taskId;
                                              
                                              if (deleteId == null) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(outerContext).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Task ID not found'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                                return;
                                              }
                                              
                                              // Log for debugging
                                              debugPrint('Deleting task with GUID: $taskGuid / ID: $taskId');
                                              
                                              // Show loading indicator
                                              if (mounted) {
                                                _showLoadingDialog(outerContext);
                                              }
                                              
                                              // Store the task before removing it in case we need to restore it
                                              final Map<String, dynamic> originalTask = Map<String, dynamic>.from(task);
                                              
                                              // Optimistically remove the task from local list first
                                              if (mounted) {
                                                setState(() {
                                                  if (_bucketTasks.containsKey(bucketGuid)) {
                                                    _bucketTasks[bucketGuid] = _bucketTasks[bucketGuid]!
                                                        .where((t) => t['guid'] != taskGuid && t['id'] != taskId)
                                                        .toList();
                                                    debugPrint('DELETION: Task removed from local state. Remaining tasks: ${_bucketTasks[bucketGuid]?.length}');
                                                  }
                                                });
                                              }
                                              
                                              try {
                                                // Delete the task - Wait for longer timeout
                                                await _apiService.deleteTask(deleteId.toString())
                                                  .timeout(const Duration(seconds: 15));
                                                
                                                // Add a short delay to ensure server sync
                                                await Future.delayed(const Duration(seconds: 1));
                                                
                                                // Close loading dialog with appropriate context checking
                                                if (mounted) {
                                                  _dismissDialog(outerContext);
                                                
                                                  // Show success message
                                                  // Permanently track this task ID as deleted
                                                  if (taskId != null) _deletedTaskIds.add(taskId.toString());
                                                  if (taskGuid != null) _deletedTaskIds.add(taskGuid.toString());
                                                  
                                                  debugPrint('PERMANENT DELETION: Added task ID to _deletedTaskIds cache. Current size: ${_deletedTaskIds.length}');
                                                  
                                                  ScaffoldMessenger.of(outerContext).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Task "$taskTitle" deleted'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                  
                                                  // Multiple approaches to ensure UI refresh:
                                                  
                                                  // 1. First try immediate manual state update
                                                  setState(() {
                                                    // Ensure we have the latest deleted task IDs reflected in the UI
                                                    if (_bucketTasks.containsKey(bucketGuid)) {
                                                      // Create a completely fresh list without the deleted task
                                                      _bucketTasks[bucketGuid] = _bucketTasks[bucketGuid]!
                                                          .where((t) => 
                                                            (t['guid'] == null || t['guid'].toString() != taskGuid?.toString()) && 
                                                            (t['id'] == null || t['id'].toString() != taskId?.toString()))
                                                          .toList();
                                                          
                                                      debugPrint('SUCCESS: Manual task removal successful. Remaining tasks: ${_bucketTasks[bucketGuid]?.length}');
                                                      
                                                      // Force a complete rebuild of the task list
                                                      _tabController.animateTo(_tabController.index);
                                                    }
                                                  });
                                                  
                                                  // 2. After the API call succeeds, force a refresh from the server
                                                  _refreshBucketData(bucketGuid);
                                                  
                                                  // 3. Schedule another UI refresh shortly after server data is fetched
                                                  Future.delayed(Duration(milliseconds: 500), () {
                                                    if (mounted) {
                                                      setState(() {
                                                        debugPrint('SUCCESS: Delayed UI refresh after task deletion');
                                                      });
                                                    }
                                                  });
                                                }
                                              } catch (deleteError) {
                                                debugPrint('Task deletion API error: $deleteError');
                                                
                                                // Close loading dialog safely
                                                if (mounted) {
                                                  _dismissDialog(outerContext);
                                                
                                                  // Add the task back to the list if API failed
                                                  setState(() {
                                                    if (_bucketTasks.containsKey(bucketGuid)) {
                                                      // Restore the original task
                                                      _bucketTasks[bucketGuid] = [..._bucketTasks[bucketGuid]!, originalTask];
                                                      debugPrint('ERROR: Task restored to local state after API error. Task count: ${_bucketTasks[bucketGuid]?.length}');
                                                    }
                                                  });
                                                  
                                                  // Show error message
                                                  ScaffoldMessenger.of(outerContext).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Failed to delete task: $deleteError'),
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
    // Debugging for task count
    debugPrint('FILTER: Processing ${tasks.length} tasks for bucket $bucketGuid');
    
    // Create a fresh copy of the tasks list to avoid modifying the original
    final List<Map<String, dynamic>> filteredTasks = List<Map<String, dynamic>>.from(tasks);
    
    // First filter out deleted tasks
    var tasksWithoutDeleted = filteredTasks.where((task) {
      final taskId = task['id']?.toString();
      final taskGuid = task['guid']?.toString();
      
      // Skip this task if it's in our deleted tasks set
      if ((taskId != null && _deletedTaskIds.contains(taskId)) || 
          (taskGuid != null && _deletedTaskIds.contains(taskGuid))) {
        return false;
      }
      return true;
    }).toList();
    
    // Apply standard filters
    var result = tasksWithoutDeleted.where((task) {
      final String taskTitle = _getSafeString(task['title']) ?? _getSafeString(task['name']) ?? 'Unnamed Task';
      final String taskDesc = _getSafeString(task['description']) ?? _getSafeString(task['desc']) ?? '';
      final String taskStatus = _getSafeString(task['status']) ?? 'pending';
      final String taskAssignee = _getSafeString(task['assignedToName']) ?? 
                                _getSafeString(task['displayAssignee']) ?? 
                                _getSafeString(task['assignedTo']?['displayName']) ?? 
                                _getSafeString(task['assignedTo']?['name']) ?? 
                                _getSafeString(task['employee']?['displayName']) ?? 
                                _getSafeString(task['employee']?['name']) ?? 
                                'Unassigned';
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

  // Show a loading dialog and store its context for safer dismissal
  void _showLoadingDialog(BuildContext context) {
    if (!mounted) return;
    
    // Clear any existing dialog context
    _dialogContext = null;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Store the dialog context for later use
        _dialogContext = dialogContext;
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  // Safely dismiss dialogs when the widget might be deactivated
  void _dismissDialog(BuildContext context) {
    try {
      // If we have a cached dialog context that is still valid, use it
      if (_dialogContext != null) {
        // Use a safer approach that doesn't depend on calling Navigator.canPop
        // which can cause "Looking up a deactivated widget's ancestor" error
        Navigator.of(_dialogContext!, rootNavigator: true).pop();
        debugPrint('Dialog dismissed using cached context');
        _dialogContext = null;
        return;
      }
      
      // Fall back to using provided context if we're still mounted
      // Skip the Navigator.canPop check which is what causes the error
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        debugPrint('Dialog dismissed using provided context');
      }
    } catch (e) {
      debugPrint('Error dismissing dialog: $e');
      // Dialog may already be closed, just ignore
    }
  }

  // Refresh data for a specific bucket
  Future<void> _refreshBucketData(String bucketGuid) async {
    if (!mounted) return;
    
    try {
      debugPrint('REFRESH: Starting data refresh for bucket: $bucketGuid');
      
      // First try to get fresh data from the server
      await _loadFilesAndTasksForBucket(bucketGuid);
      
      // Force a UI update with a complete state refresh
      if (mounted) {
        setState(() {
          // Create a completely new copy of the tasks list
          if (_bucketTasks.containsKey(bucketGuid)) {
            _bucketTasks[bucketGuid] = List<Map<String, dynamic>>.from(_bucketTasks[bucketGuid] ?? []);
          }
          debugPrint('REFRESH: Forced complete UI refresh after bucket data reload. Task count: ${_bucketTasks[bucketGuid]?.length}');
        });
      }
    } catch (e) {
      debugPrint('ERROR in refreshBucketData: $e');
      
      // Even if the refresh fails, force a UI update to make sure
      // the deleted task remains removed from the view
      if (mounted) {
        setState(() {
          debugPrint('REFRESH: Forced UI refresh after failed bucket reload');
        });
      }
    }
  }

  Future<int> _getSdkVersion() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.version.sdkInt;
      }
    } catch (e) {
      debugPrint('Error getting SDK version: $e');
    }
    return 0; // Default return if not Android or if there's an error
  }
} 