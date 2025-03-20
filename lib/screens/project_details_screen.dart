import 'package:flutter/material.dart';
import 'create_task_screen.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import 'edit_project_screen.dart';
import '../widgets/app_drawer.dart';
import 'project_buckets_screen.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ProjectDetailsScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _projectData = {};
  bool _isLoading = true;
  String _errorMessage = '';
  bool _showTaskFilter = false;
  String? _sortBy;
  String? _status;
  String? _assignee;
  String? _priority;
  String? _groupBy;
  final _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _loadProjectDetails();
  }

  Future<void> _loadProjectDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final projectData = await _apiService.getProjectById(widget.projectId);
      if (mounted) {
        setState(() {
          _projectData = projectData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading project details: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load project details: $e';
          _isLoading = false;
        });
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

  Widget _buildTabContent(String title) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '$title Bucket',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
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
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            // TODO: Implement file upload
                          },
                          icon: const Icon(
                            Icons.cloud_upload_outlined,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                    if (title == 'Architecture') ...[
                      const ListTile(
                        leading: Icon(Icons.insert_drive_file),
                        title: Text('LE MILLENIUM-All Blocks -Arc...'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Icon(Icons.delete),
                          ],
                        ),
                      ),
                    ] else if (title == 'Electro-Mechanical Design') ...[
                      const ListTile(
                        leading: Icon(Icons.insert_drive_file),
                        title: Text('MILLENIUM-MEP-28-10-2024'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Icon(Icons.delete),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (context) => const CreateTaskScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('ADD TASK'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1976D2),
                      ),
                    ),
                    IconButton(
                      onPressed: _showTaskFilterDialog,
                      icon: const Icon(Icons.filter_list),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  void _navigateToEdit() {
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
    ).then((_) => _loadProjectDetails());
  }

  Future<void> _showDeleteConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
          'Are you sure you want to delete this project? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _apiService.deleteProject(widget.projectId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Project deleted successfully'),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete project: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isLoading ? 'Project Details' : (_projectData['name'] ?? _projectData['title'] ?? 'Project Details'),
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          if (!_isLoading && _errorMessage.isEmpty)
            IconButton(
              icon: const Icon(Icons.folder_special, color: Colors.blue),
              tooltip: 'View Buckets',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/project_buckets',
                  arguments: {
                    'projectId': widget.projectId,
                    'projectName': widget.projectName,
                  },
                );
              },
            ),
          if (!_isLoading && _errorMessage.isEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToEdit();
                } else if (value == 'delete') {
                  _showDeleteConfirmation();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit Project'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Project', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProjectDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status and location row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_projectData['status'] ?? 'In Progress'),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _projectData['status'] ?? 'In Progress',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_projectData['location'] != null && _projectData['location'].toString().isNotEmpty)
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _projectData['location'].toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Description section
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _projectData['description']?.toString() ?? 'No description available',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Manager section
                      const Text(
                        'Managed By',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1976D2),
                          child: Text(
                            (_projectData['managedBy'] ?? 'OT').toString().substring(0, 1),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(_projectData['managedBy'] ?? 'Oussama Tahmaz'),
                        subtitle: const Text('Project Manager'),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Created Date and Last Updated
                      if (_projectData['createdAt'] != null || _projectData['updatedAt'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Project Timeline',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_projectData['createdAt'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Created: ',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(_projectData['createdAt'].toString()),
                                  ],
                                ),
                              ),
                            if (_projectData['updatedAt'] != null)
                              Row(
                                children: [
                                  const Icon(Icons.update, size: 16),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Last Updated: ',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(_projectData['updatedAt'].toString()),
                                ],
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
} 