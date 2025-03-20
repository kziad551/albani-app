import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import '../services/api_service.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import 'project_details_screen.dart';

class BucketsScreen extends StatefulWidget {
  const BucketsScreen({super.key});

  @override
  State<BucketsScreen> createState() => _BucketsScreenState();
}

class _BucketsScreenState extends State<BucketsScreen> {
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
      // Using the same endpoint as the website (BucketConfigs)
      final buckets = await _apiService.getBuckets();
      
      // Sort buckets by line number
      buckets.sort((a, b) {
        final lineA = int.tryParse((a['line'] ?? '0').toString()) ?? 0;
        final lineB = int.tryParse((b['line'] ?? '0').toString()) ?? 0;
        return lineA.compareTo(lineB);
      });
      
      setState(() {
        _buckets = buckets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load buckets: $e';
        _isLoading = false;
      });
    }
  }

  void _showAddBucketDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final lineController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bucket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name*',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lineController,
              decoration: InputDecoration(
                labelText: 'Line',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
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
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }

              final bucketData = {
                'name': nameController.text.trim(),
                'description': descriptionController.text.trim(),
                'line': int.tryParse(lineController.text) ?? 1,
                'title': nameController.text.trim(),
              };

              Navigator.pop(context);

              setState(() {
                _isLoading = true;
              });

              try {
                await _apiService.createBucket(bucketData);
                _loadBuckets();
              } catch (e) {
                setState(() {
                  _errorMessage = 'Failed to add bucket: $e';
                  _isLoading = false;
                });
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showEditBucketDialog({
    required String id,
    required String name,
    required String description,
    required String line,
  }) {
    final nameController = TextEditingController(text: name);
    final descriptionController = TextEditingController(text: description);
    final lineController = TextEditingController(text: line);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bucket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name*',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lineController,
              decoration: InputDecoration(
                labelText: 'Line',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
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
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }

              final bucketData = {
                'id': id,
                'name': nameController.text.trim(),
                'description': descriptionController.text.trim(),
                'line': int.tryParse(lineController.text) ?? 1,
                'title': nameController.text.trim(),
              };

              Navigator.pop(context);

              setState(() {
                _isLoading = true;
              });

              try {
                await _apiService.updateBucket(bucketData);
                _loadBuckets();
              } catch (e) {
                setState(() {
                  _errorMessage = 'Failed to update bucket: $e';
                  _isLoading = false;
                });
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBucket(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bucket'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              setState(() {
                _isLoading = true;
              });

              try {
                await _apiService.deleteBucket(id);
                _loadBuckets();
              } catch (e) {
                setState(() {
                  _errorMessage = 'Failed to delete bucket: $e';
                  _isLoading = false;
                });
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBucketDialog,
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('ADD BUCKET', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading buckets...')
          : _errorMessage != null
              ? CustomErrorWidget(
                  message: _errorMessage!,
                  onRetry: _loadBuckets,
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage Buckets',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buckets.isEmpty
                            ? const Center(
                                child: Text(
                                  'No buckets found.\nClick "ADD BUCKET" to create one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadBuckets,
                                child: ListView.builder(
                                  itemCount: _buckets.length,
                                  itemBuilder: (context, index) {
                                    final bucket = _buckets[index];
                                    final bucketId = bucket['id']?.toString() ?? '';
                                    final bucketName = bucket['name'] ?? bucket['title'] ?? 'Untitled Bucket';
                                    final bucketDescription = bucket['description'] ?? '$bucketName Bucket';
                                    final bucketLine = bucket['line']?.toString() ?? '0';
                                    
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      color: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          '$bucketName (Line: $bucketLine)',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(bucketDescription),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              onPressed: () => _showEditBucketDialog(
                                                id: bucketId,
                                                name: bucketName,
                                                description: bucketDescription,
                                                line: bucketLine,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _confirmDeleteBucket(bucketId, bucketName),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
} 