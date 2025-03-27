import 'package:flutter/material.dart';
import 'dart:math';
import '../config/app_config.dart';
import 'create_task_screen.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import 'edit_project_screen.dart';
import '../widgets/app_drawer.dart';
import 'project_buckets_screen.dart';

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
  late ApiService _apiService;
  
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
  
  // Maps to store bucket files and tasks
  Map<String, List<Map<String, dynamic>>> _bucketFiles = {};
  Map<String, List<Map<String, dynamic>>> _bucketTasks = {};
  
  // Tab controller and tabs
  late TabController _tabController;
  List<Map<String, dynamic>> _tabs = [];
  
  final _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize the API service
    _apiService = ApiService();
    
    // Initialize the maps
    _bucketFiles = {};
    _bucketTasks = {};
    
    // Setup tabs
    _setupTabs();
    
    // Load project data
    _loadProjectData();
    
    // Load buckets for this project
    _loadProjectBuckets();
  }

  Future<void> _loadProjectDetails() async {
    if (widget.projectDetails != null && widget.projectDetails!.isNotEmpty) {
      setState(() {
        _projectData = Map<String, dynamic>.from(widget.projectDetails!);
        _isLoading = false;
      });
      _loadProjectBuckets();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final projectData = await _apiService.getProjectById(widget.projectId);
      
      if (projectData.isEmpty) {
        throw Exception('Project details could not be found');
      }
      
      if (mounted) {
        setState(() {
          _projectData = projectData;
          _isLoading = false;
        });
        _loadProjectBuckets();
      }
    } catch (e) {
      debugPrint('Error loading project details: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load project details: ${e.toString().split(':').first}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadProjectBuckets() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      // Get project ID and ensure it's not empty
      final projectId = widget.projectId;
      if (projectId == null) {
        throw Exception('Project ID is null');
      }
      
      debugPrint('Loading buckets for project ID: $projectId');
      
      // Handle project ID - try to use it directly if it's a number, otherwise use as string
      dynamic finalProjectId = projectId;
      if (projectId is String) {
        // Try to parse as int, but if it fails, use the string value
        finalProjectId = int.tryParse(projectId) ?? projectId;
      }
      
      debugPrint('Using project ID (${finalProjectId.runtimeType}): $finalProjectId');
      
      final buckets = await _apiService.getBuckets(projectId: finalProjectId);
      
      if (mounted) {
        setState(() {
          _projectBuckets = buckets;
          _isLoading = false;
          
          // Set up tabs based on buckets
          _tabs = buckets.map((bucket) => {
            'title': bucket['name'] ?? 'Unknown',
            'icon': Icons.folder,
            'bucket': bucket,
          }).toList();
          
          // Update tab controller with new length
          _tabController = TabController(
            length: _tabs.length,
            vsync: this,
          );
        });
        
        // Load files and tasks for each bucket
        for (var bucket in buckets) {
          await _loadFilesAndTasksForBucket(bucket);
        }
      }
    } catch (e) {
      debugPrint('Error loading project buckets: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load project data: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  // Helper method to load files and tasks for a bucket
  Future<void> _loadFilesAndTasksForBucket(Map<String, dynamic> bucket) async {
    if (bucket.isEmpty) {
      debugPrint('Skipping empty bucket');
      return;
    }
    
    try {
      // Get bucket ID - try different possible field names
      final bucketId = (bucket['id'] ?? bucket['guid'] ?? '').toString();
      
      if (bucketId.isEmpty) {
        debugPrint('Bucket ID is empty, skipping: ${bucket.toString().substring(0, min(100, bucket.toString().length))}');
        return;
      }
      
      debugPrint('Loading files and tasks for bucket: ${bucket['name']} (ID: $bucketId)');
      
      // Load files
      try {
        final files = await _apiService.getBucketFiles(bucketId);
        setState(() {
          _bucketFiles[bucketId] = files;
        });
        debugPrint('Loaded ${files.length} files for bucket ${bucket['name']}');
      } catch (e) {
        debugPrint('Error loading files for bucket $bucketId: $e');
        setState(() {
          _bucketFiles[bucketId] = [];
        });
      }
      
      // Load tasks
      try {
        final tasks = await _apiService.getBucketTasks(bucketId);
        setState(() {
          _bucketTasks[bucketId] = tasks;
        });
        debugPrint('Loaded ${tasks.length} tasks for bucket ${bucket['name']}');
      } catch (e) {
        debugPrint('Error loading tasks for bucket $bucketId: $e');
        setState(() {
          _bucketTasks[bucketId] = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading data for bucket ${bucket['name'] ?? 'Unknown'}: $e');
    }
  }
  
  Future<void> _loadBucketFiles(Map<String, dynamic> bucket) async {
    try {
      final bucketId = bucket['guid'] ?? bucket['id'] ?? '';
      final bucketName = bucket['name'] ?? 'Unknown';
      
      if (bucketId.isEmpty) return;
      
      final files = await _apiService.getBucketFiles(bucketId);
      
      if (mounted) {
        setState(() {
          _bucketFiles[bucketName] = files;
        });
      }
    } catch (e) {
      debugPrint('Error loading bucket files: $e');
    }
  }
  
  Future<void> _loadBucketTasks(Map<String, dynamic> bucket) async {
    try {
      final bucketId = bucket['guid'] ?? bucket['id'] ?? '';
      final bucketName = bucket['name'] ?? 'Unknown';
      
      if (bucketId.isEmpty) return;
      
      final tasks = await _apiService.getBucketTasks(bucketId);
      
      if (mounted) {
        setState(() {
          _bucketTasks[bucketName] = tasks;
        });
      }
    } catch (e) {
      debugPrint('Error loading bucket tasks: $e');
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
    
    // Get the bucket from the tab
    final bucket = tab['bucket'] as Map<String, dynamic>? ?? {};
    
    if (bucket.isEmpty) {
      return const Center(
        child: Text(
          'No data found for this category',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    final bucketId = bucket['id']?.toString() ?? '';
    final files = _bucketFiles[bucketId] ?? [];
    final tasks = _bucketTasks[bucketId] ?? [];
    
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade200,
            child: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.folder), text: 'Files'),
                Tab(icon: Icon(Icons.task), text: 'Tasks'),
              ],
              labelColor: Color(0xFF1976D2),
              unselectedLabelColor: Colors.grey,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Files tab
                _buildFilesTab(bucketId, bucket['name'] ?? 'Unknown'),
                
                // Tasks tab
                _buildTasksTab(bucketId, bucket['name'] ?? 'Unknown'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build the files tab content for a bucket
  Widget _buildFilesTab(String bucketId, String bucketName) {
    final files = _bucketFiles[bucketId] ?? [];
    
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No files found',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  final refreshedFiles = await _apiService.getBucketFiles(bucketId);
                  setState(() {
                    _bucketFiles[bucketId] = refreshedFiles;
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to refresh files: $e')),
                  );
                }
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: files.length,
      padding: const EdgeInsets.all(8.0),
      itemBuilder: (context, index) {
        final file = files[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: _getFileIcon(file['fileType'] ?? 'unknown'),
            title: Text(file['name'] ?? 'Unnamed File'),
            subtitle: Text(file['description'] ?? ''),
            trailing: const Icon(Icons.download),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download not implemented')),
              );
            },
          ),
        );
      },
    );
  }
  
  // Build the tasks tab content for a bucket
  Widget _buildTasksTab(String bucketId, String bucketName) {
    final tasks = _bucketTasks[bucketId] ?? [];
    
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No tasks found',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  final refreshedTasks = await _apiService.getBucketTasks(bucketId);
                  setState(() {
                    _bucketTasks[bucketId] = refreshedTasks;
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to refresh tasks: $e')),
                  );
                }
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: tasks.length,
      padding: const EdgeInsets.all(8.0),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(task['title'] ?? task['name'] ?? 'Unnamed Task'),
            subtitle: Text(task['description'] ?? ''),
            trailing: _getStatusIcon(task['status'] ?? 'pending'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('View task details coming soon')),
              );
            },
          ),
        );
      },
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
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'in progress':
        iconData = Icons.sync;
        iconColor = Colors.blue;
        break;
      case 'pending':
        iconData = Icons.pending;
        iconColor = Colors.orange;
        break;
      case 'rejected':
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.help_outline;
        iconColor = Colors.grey;
    }
    
    return Icon(iconData, color: iconColor);
  }

  // Find the bucket with the matching name or title
  Map<String, dynamic> _findBucketByName(String tabTitle) {
    debugPrint('Finding bucket for tab: $tabTitle');
    
    // Handle common bucket titles with variations
    final Map<String, List<String>> commonAliases = {
      'Architecture': ['Architecture', 'Arch', 'architecture', 'arch'],
      'Structural Design': ['Structural Design', 'Structural', 'structural', 'structure', 'struct'],
      'Mechanical': ['Mechanical', 'HVAC', 'MEP', 'mechanical'],
      'Electrical': ['Electrical', 'Electric', 'electrical', 'Lighting'],
      'Plumbing': ['Plumbing', 'Water', 'plumbing'],
      'Project Management': ['Project Management', 'PM', 'Management'],
      'Bill of Quantity': ['Bill of Quantity', 'BoQ', 'Quantity', 'Quantities'],
      'Client Section': ['Client Section', 'Client', 'client'],
      'On Site': ['On Site', 'Site', 'Construction Site', 'on-site'],
    };
    
    // Normalize the tab title
    final normalizedTabTitle = tabTitle.trim().toLowerCase();
    
    // First try: Direct match with name or title
    try {
      final bucket = _projectBuckets.firstWhere(
        (b) => 
            (b['name'] ?? '').toString().trim().toLowerCase() == normalizedTabTitle ||
            (b['title'] ?? '').toString().trim().toLowerCase() == normalizedTabTitle,
        orElse: () => <String, dynamic>{},
      );
      
      if (bucket.isNotEmpty) {
        debugPrint('Found bucket by direct name/title match: ${bucket['name']}');
        return bucket;
      }
    } catch (e) {
      debugPrint('Error in direct match: $e');
    }
    
    // Second try: Check against aliases
    for (var entry in commonAliases.entries) {
      final standardName = entry.key;
      final aliases = entry.value;
      
      if (aliases.any((alias) => alias.toLowerCase().contains(normalizedTabTitle) || 
                               normalizedTabTitle.contains(alias.toLowerCase()))) {
        try {
          final bucket = _projectBuckets.firstWhere(
            (b) => 
                aliases.any((alias) => 
                    (b['name'] ?? '').toString().toLowerCase().contains(alias.toLowerCase()) ||
                    (b['title'] ?? '').toString().toLowerCase().contains(alias.toLowerCase()) ||
                    alias.toLowerCase().contains((b['name'] ?? '').toString().toLowerCase()) ||
                    alias.toLowerCase().contains((b['title'] ?? '').toString().toLowerCase())
                ),
            orElse: () => <String, dynamic>{},
          );
          
          if (bucket.isNotEmpty) {
            debugPrint('Found bucket by alias match: ${bucket['name']}');
            return bucket;
          }
        } catch (e) {
          debugPrint('Error in alias match: $e');
        }
      }
    }
    
    // Third try: Look for any bucket with similar name
    try {
      final bucket = _projectBuckets.firstWhere(
        (b) => 
            (b['name'] ?? '').toString().toLowerCase().contains(normalizedTabTitle) ||
            (b['title'] ?? '').toString().toLowerCase().contains(normalizedTabTitle) ||
            normalizedTabTitle.contains((b['name'] ?? '').toString().toLowerCase()) ||
            normalizedTabTitle.contains((b['title'] ?? '').toString().toLowerCase()),
        orElse: () => <String, dynamic>{},
      );
      
      if (bucket.isNotEmpty) {
        debugPrint('Found bucket by partial match: ${bucket['name']}');
        return bucket;
      }
    } catch (e) {
      debugPrint('Error in partial match: $e');
    }
    
    // Last resort: Just take the first bucket or return empty
    if (_projectBuckets.isNotEmpty) {
      debugPrint('No matching bucket found, using first available: ${_projectBuckets.first['name']}');
      return _projectBuckets.first;
    }
    
    debugPrint('No buckets available for tab: $tabTitle');
    return <String, dynamic>{}; // Return empty map if no bucket found
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
      {'title': 'Files', 'icon': Icons.folder},
      {'title': 'Tasks', 'icon': Icons.task},
    ];
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  // Load project data
  Future<void> _loadProjectData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // If project details were passed, use them immediately
      if (widget.projectDetails != null && widget.projectDetails!.isNotEmpty) {
        _projectData = Map<String, dynamic>.from(widget.projectDetails!);
      } else {
        // Otherwise load from API
        final projects = await _apiService.getProjects();
        
        // Convert both IDs to string for comparison
        final projectIdString = widget.projectId.toString();
        final project = projects.firstWhere(
          (p) => p['id'].toString() == projectIdString || p['guid'].toString() == projectIdString,
          orElse: () => <String, dynamic>{},
        );
        
        if (project.isNotEmpty) {
          _projectData = project;
        } else {
          throw Exception('Project not found');
        }
      }
      
      setState(() {
        _isLoading = false;
      });
      
      // After loading project data, load the buckets
      await _loadProjectBuckets();
    } catch (e) {
      debugPrint('Error loading project data: $e');
      setState(() {
        _errorMessage = 'Failed to load project data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(),
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
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = '';
                          });
                          _loadProjectData();
                          _loadProjectBuckets();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Project Header with back button
                    _buildProjectHeader(),
                    
                    // Project Info Card
                    _buildProjectInfoCard(),
                    
                    // Tabs and Content
                    _buildTabsAndContent(),
                  ],
                ),
    );
  }

  Widget _buildProjectInfoCard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _projectData['description'] ?? 'No description available',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status: ${_projectData['status'] ?? 'Unknown'}',
                  style: TextStyle(
                    color: _getStatusColor(_projectData['status'] ?? ''),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Location: ${_projectData['location'] ?? 'Not specified'}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsAndContent() {
    if (_tabs.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            'No buckets found for this project',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: _tabs.map((tab) => Tab(
              icon: Icon(tab['icon'] as IconData),
              text: tab['title'] as String,
            )).toList(),
          ),
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

  // Build project header with back button and edit button
  Widget _buildProjectHeader() {
    return Container(
      color: const Color(0xFF1976D2),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _projectData['name'] ?? 'Unknown Project',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _navigateToEditProject,
          ),
        ],
      ),
    );
  }
} 