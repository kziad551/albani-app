import 'package:flutter/material.dart';

class EditProjectScreen extends StatefulWidget {
  final String title;
  final String description;
  final String location;
  final String status;

  const EditProjectScreen({
    super.key,
    required this.title,
    required this.description,
    required this.location,
    required this.status,
  });

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _selectedLocation;
  late String _selectedStatus;
  bool _isBucketExpanded = true;

  final List<Map<String, dynamic>> _buckets = [
    {
      'title': 'Project Management',
      'subtitle': 'Project Management Bucket',
      'isExpanded': false,
    },
    {
      'title': 'Architecture',
      'subtitle': 'Architecture Bucket',
      'isExpanded': false,
      'subItems': ['Plans', 'Sections-Elevations'],
    },
    {
      'title': 'Civil',
      'subtitle': 'Civil Bucket',
      'isExpanded': false,
    },
    {
      'title': 'Bill Of Quantities',
      'subtitle': 'Bill Of Quantity Bucket',
      'isExpanded': false,
    },
    {
      'title': 'Electro-Mechanical Design',
      'subtitle': 'Electro-Mechanical Design Bucket',
      'isExpanded': false,
    },
    {
      'title': 'On Site',
      'subtitle': 'On Site Bucket',
      'isExpanded': false,
    },
  ];

  final List<Map<String, String>> _users = [
    {
      'name': 'Oussama Tahmaz',
      'phone': '009610328185',
      'initials': 'OT',
      'color': '1976D2',
    },
    {
      'name': 'Hassan Hatoum',
      'phone': '0096103974633',
      'initials': 'HH',
      'color': '03A9F4',
    },
    {
      'name': 'Alaa Karaki',
      'phone': '009613173362',
      'initials': 'AK',
      'color': '673AB7',
    },
    {
      'name': 'Ali Mostafa',
      'phone': '0096176979823',
      'initials': 'AM',
      'color': '8BC34A',
    },
    {
      'name': 'Test User',
      'phone': '',
      'initials': 'TU',
      'color': '9C27B0',
    },
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _descriptionController = TextEditingController(text: widget.description);
    _selectedLocation = widget.location;
    _selectedStatus = widget.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showAddBucketDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Bucket',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Add Sub Bucket'),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Name',
                  filled: true,
                  fillColor: Color(0xFFF5F5F5),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Description',
                  filled: true,
                  fillColor: Color(0xFFF5F5F5),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Implement add bucket
                      Navigator.pop(context);
                    },
                    child: const Text('ADD'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  hintText: 'Select...',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user1', child: Text('User 1')),
                  DropdownMenuItem(value: 'user2', child: Text('User 2')),
                ],
                onChanged: (value) {},
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Implement add user
                      Navigator.pop(context);
                    },
                    child: const Text('ADD'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Project',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Implement project update
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLocation,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "Côte d'Ivoire", child: Text("Côte d'Ivoire")),
                DropdownMenuItem(value: 'Lebanon', child: Text('Lebanon')),
                DropdownMenuItem(
                  value: 'Democratic Republic of the Congo',
                  child: Text('Democratic Republic of the Congo'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedLocation = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.black, width: 1),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Bucket Configuration'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isBucketExpanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          onPressed: () {
                            setState(() => _isBucketExpanded = !_isBucketExpanded);
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_isBucketExpanded)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _buckets.length,
                      itemBuilder: (context, index) {
                        final bucket = _buckets[index];
                        return ExpansionTile(
                          title: Text(bucket['title']),
                          subtitle: Text(bucket['subtitle']),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _showAddBucketDialog,
                          ),
                          children: [
                            if (bucket['subItems'] != null)
                              ...List.generate(
                                (bucket['subItems'] as List).length,
                                (i) => ListTile(
                                  title: Text(bucket['subItems'][i]),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.black, width: 1),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Users'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _showAddUserDialog,
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(int.parse('0xFF${user['color']}')),
                          child: Text(
                            user['initials']!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(user['name']!),
                        subtitle: Text(user['phone']!),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            // TODO: Implement user removal
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
      ),
    );
  }
} 