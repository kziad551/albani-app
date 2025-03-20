import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';

class ProjectBucketsScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ProjectBucketsScreen({
    super.key, 
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectBucketsScreen> createState() => _ProjectBucketsScreenState();
}

class _ProjectBucketsScreenState extends State<ProjectBucketsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _buckets = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBuckets();
  }

  Future<void> _loadBuckets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final buckets = await _apiService.getBuckets(projectId: widget.projectId);
      if (mounted) {
        setState(() {
          _buckets = buckets;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading buckets: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load buckets: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddBucketDialog({Map<String, dynamic>? bucketToEdit}) async {
    final nameController = TextEditingController(text: bucketToEdit?['name'] ?? '');
    final descriptionController = TextEditingController(text: bucketToEdit?['description'] ?? '');
    final isEditing = bucketToEdit != null;
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Bucket' : 'Add New Bucket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Bucket Name',
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
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bucket name is required')),
                );
                return;
              }
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'description': descriptionController.text.trim(),
              });
            },
            child: Text(isEditing ? 'SAVE' : 'ADD'),
          ),
        ],
      ),
    );

    if (result != null) {
      if (isEditing) {
        _updateBucket(bucketToEdit!, result['name']!, result['description']!);
      } else {
        _addBucket(result['name']!, result['description']!);
      }
    }

    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _addBucket(String name, String description) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bucketData = {
        'name': name,
        'description': description,
        'projectId': widget.projectId,
        'line': _buckets.length + 1,
      };
      
      // Use the createBucket method from ApiService
      final newBucket = await _apiService.createBucket(bucketData);
      
      if (mounted) {
        setState(() {
          _buckets.add(newBucket);
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bucket added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to add bucket: $e';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add bucket: $e')),
        );
      }
    }
  }

  Future<void> _updateBucket(Map<String, dynamic> bucket, String name, String description) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedBucketData = {
        ...bucket,
        'name': name,
        'description': description,
      };
      
      final updatedBucket = await _apiService.createBucket(updatedBucketData);
      
      if (mounted) {
        setState(() {
          _buckets = _buckets.map((b) => 
            b['guid'] == bucket['guid'] ? updatedBucket : b
          ).toList();
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bucket updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update bucket: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteBucket(Map<String, dynamic> bucket) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bucket'),
        content: Text('Are you sure you want to delete "${bucket['name']}"?'),
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

    if (result == true) {
      _deleteBucket(bucket);
    }
  }

  Future<void> _deleteBucket(Map<String, dynamic> bucket) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.deleteBucket(bucket['guid']);
      
      if (mounted) {
        setState(() {
          _buckets = _buckets.where((b) => b['guid'] != bucket['guid']).toList();
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bucket deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete bucket: $e')),
        );
      }
    }
  }

  Future<void> _showBucketDetails(Map<String, dynamic> bucket) async {
    final bucketEmployees = await _apiService.getBucketEmployees(bucket['guid']);
    
    if (!mounted) return;
    
    // This would typically navigate to a bucket details screen
    // For now, we'll just show a dialog with the bucket details
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(bucket['name']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description: ${bucket['description'] ?? 'No description'}'),
              const SizedBox(height: 16),
              Text('ID: ${bucket['id']}'),
              const SizedBox(height: 8),
              Text('GUID: ${bucket['guid']}'),
              if (bucketEmployees.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Assigned Employees:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...bucketEmployees.map((employee) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text('• ${employee['name'] ?? employee['username'] ?? 'Unknown User'}'),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showAddBucketDialog(bucketToEdit: bucket);
            }, 
            child: const Text('EDIT'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteBucket(bucket);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(),
      endDrawer: const AppDrawer(),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading buckets...')
          : _errorMessage != null
              ? CustomErrorWidget(
                  message: _errorMessage!,
                  onRetry: _loadBuckets,
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Project: ${widget.projectName}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Buckets (${_buckets.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddBucketDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('ADD BUCKET'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buckets.isEmpty
                          ? const Center(
                              child: Text(
                                'No buckets found.\nClick "ADD BUCKET" to create one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.5,
                              ),
                              itemCount: _buckets.length,
                              itemBuilder: (context, index) {
                                final bucket = _buckets[index];
                                return InkWell(
                                  onTap: () => _showBucketDetails(bucket),
                                  child: Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  bucket['name'] ?? 'Unnamed Bucket',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert, size: 20),
                                                onSelected: (value) {
                                                  if (value == 'edit') {
                                                    _showAddBucketDialog(bucketToEdit: bucket);
                                                  } else if (value == 'delete') {
                                                    _confirmDeleteBucket(bucket);
                                                  } else if (value == 'details') {
                                                    _showBucketDetails(bucket);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                    value: 'details',
                                                    child: Text('View Details'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text('Edit Bucket'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('Delete Bucket'),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const Divider(),
                                          Expanded(
                                            child: Text(
                                              bucket['description'] ?? 'No description',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Line: ${bucket['line'] ?? index + 1}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                              Text(
                                                '${bucket['employees']?.length ?? 0} employees',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
} 