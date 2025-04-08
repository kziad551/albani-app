import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import 'edit_project_screen.dart';

class ProjectSettingsScreen extends StatefulWidget {
  final dynamic projectId;
  final String projectName;
  final Map<String, dynamic>? projectDetails;

  const ProjectSettingsScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.projectDetails,
  });

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _projectData = {};
  List<Map<String, dynamic>> _projectBuckets = [];
  List<Map<String, dynamic>> _projectUsers = [];
  Map<String, bool> _expandedBuckets = {};

  @override
  void initState() {
    super.initState();
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

      // Get project details
      Map<String, dynamic> projectDetails;
      if (widget.projectDetails != null) {
        projectDetails = widget.projectDetails!;
      } else {
        projectDetails = await _apiService.getProjectById(widget.projectId);
      }

      // Load project employees
      final projectGuid = projectDetails['guid'] ?? widget.projectId;
      final employees = await _apiService.getProjectEmployees(projectGuid.toString());

      // Load project buckets with hierarchy
      final bucketsResponse = await _apiService.get('api/buckets/hierarchy/${projectGuid.toString()}');
      List<Map<String, dynamic>> buckets = [];
      
      if (bucketsResponse != null) {
        if (bucketsResponse is List) {
          buckets = List<Map<String, dynamic>>.from(bucketsResponse);
        } else if (bucketsResponse is Map) {
          final data = bucketsResponse['data'] ?? bucketsResponse['items'] ?? bucketsResponse['buckets'] ?? [];
          if (data is List) {
            buckets = List<Map<String, dynamic>>.from(data);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _projectData = projectDetails;
        _projectUsers = employees;
        _projectBuckets = buckets;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showAddBucketDialog({Map<String, dynamic>? parentBucket}) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parentBucket != null ? 'Add Sub Bucket' : 'New Bucket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final projectGuid = _projectData['guid'] ?? widget.projectId;
                
                // Create bucket data with the correct format
                final bucketData = {
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'projectGuid': projectGuid.toString(),
                  if (parentBucket != null) 'parentBucketId': parentBucket['id']?.toString(),
                };

                debugPrint('Creating bucket with data: $bucketData');
                
                // Call API to create bucket
                await _apiService.post('api/buckets', bucketData);
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadProjectData(); // Refresh data
                }
              } catch (e) {
                if (mounted) {
                  debugPrint('Error creating bucket: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating bucket: $e')),
                  );
                }
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final projectGuid = _projectData['guid'] ?? widget.projectId;
                await _apiService.deleteProject(projectGuid.toString());
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to projects screen
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting project: $e')),
                  );
                }
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBucketTree(Map<String, dynamic> bucket, {int level = 0}) {
    final bool hasSubBuckets = (bucket['subBuckets'] as List?)?.isNotEmpty ?? false;
    final String bucketId = (bucket['id'] ?? '').toString();
    final bool isExpanded = _expandedBuckets[bucketId] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasSubBuckets 
            ? () {
                setState(() {
                  _expandedBuckets[bucketId] = !isExpanded;
                });
              }
            : null,
          child: Padding(
            padding: EdgeInsets.only(left: level * 20.0),
            child: Row(
              children: [
                if (hasSubBuckets)
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 24,
                    color: Colors.grey,
                  )
                else
                  const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bucket['name'] ?? bucket['title'] ?? 'Unnamed Bucket',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (bucket['description'] != null && bucket['description'].toString().isNotEmpty)
                        Text(
                          bucket['description'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _showAddBucketDialog(parentBucket: bucket),
                  tooltip: 'Add Sub Bucket',
                ),
              ],
            ),
          ),
        ),
        if (hasSubBuckets && isExpanded)
          Column(
            children: [
              for (var subBucket in bucket['subBuckets'] as List)
                _buildBucketTree(subBucket as Map<String, dynamic>, level: level + 1),
            ],
          ),
      ],
    );
  }

  // Add method to show user selection dialog
  void _showAddUserDialog() async {
    try {
      setState(() => _isLoading = true);
      
      // Fetch all users
      final allUsers = await _apiService.getUsers();
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Filter out users that are already in the project
      final existingUserIds = _projectUsers.map((u) => u['id']?.toString()).toSet();
      final availableUsers = allUsers.where((u) => !existingUserIds.contains(u['id']?.toString())).toList();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add User to Project'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400, // Fixed height for scrollable content
            child: Column(
              children: [
                Expanded(
                  child: availableUsers.isEmpty
                      ? const Center(
                          child: Text(
                            'No available users to add',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableUsers.length,
                          itemBuilder: (context, index) {
                            final user = availableUsers[index];
                            final name = user['name'] ?? 
                                       '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim() ?? 
                                       user['username'] ?? 
                                       'Unknown User';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (user['email'] != null && user['email'].toString().isNotEmpty)
                                    Text(user['email'].toString()),
                                  if (user['role'] != null && user['role'].toString().isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        user['role'].toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () async {
                                try {
                                  final projectGuid = _projectData['guid'] ?? widget.projectId;
                                  await _apiService.post(
                                    'api/projects/$projectGuid/users',
                                    {'userId': user['id']?.toString()},
                                  );
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _loadProjectData(); // Refresh data
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error adding user: $e')),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  // Add method to remove user from project
  Future<void> _removeUser(Map<String, dynamic> user) async {
    try {
      final projectGuid = _projectData['guid'] ?? widget.projectId;
      await _apiService.delete('api/projects/$projectGuid/users/${user['id']}');
      if (mounted) {
        _loadProjectData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing user: $e')),
        );
      }
    }
  }

  // Add method to show remove user confirmation
  void _showRemoveUserConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User'),
        content: Text('Are you sure you want to remove ${user['name']} from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeUser(user);
            },
            child: const Text('REMOVE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _projectUsers.length,
      itemBuilder: (context, index) {
        final user = _projectUsers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                (user['name'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(color: Colors.blue.shade900),
              ),
            ),
            title: Text(user['name'] ?? 'Unknown User'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['email'] ?? ''),
                Text(
                  user['role'] ?? 'No Role',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user['role'] != 'Owner')
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _showRemoveUserConfirmation(user),
                    tooltip: 'Remove User',
                  ),
              ],
            ),
          ),
        );
      },
    );
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
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project Details Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Project Details',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => EditProjectScreen(
                                                  projectId: int.tryParse(_projectData['id']?.toString() ?? '') ?? 0,
                                                  title: _projectData['title'] ?? '',
                                                  description: _projectData['description'] ?? '',
                                                  location: _projectData['location'] ?? '',
                                                  status: _projectData['status'] ?? 'In Progress',
                                                ),
                                              ),
                                            ).then((_) => _loadProjectData());
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: _showDeleteConfirmation,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                _buildDetailRow('Title', _projectData['title'] ?? 'N/A'),
                                _buildDetailRow('Location', _projectData['location'] ?? 'N/A'),
                                _buildDetailRow('Description', _projectData['description'] ?? 'N/A'),
                                _buildDetailRow('Status', _projectData['status'] ?? 'N/A'),
                                _buildDetailRow('Manager', _projectData['managedBy'] ?? 'N/A'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Buckets Configuration Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Bucket Configuration',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () => _showAddBucketDialog(),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _projectBuckets.length,
                                  itemBuilder: (context, index) {
                                    final bucket = _projectBuckets[index];
                                    return _buildBucketTree(bucket);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Project Users Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Project Users',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.person_add),
                                      onPressed: _showAddUserDialog,
                                    ),
                                  ],
                                ),
                                const Divider(),
                                _buildUserList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
} 