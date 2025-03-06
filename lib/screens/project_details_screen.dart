import 'package:flutter/material.dart';
import 'create_task_screen.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final String projectName;

  const ProjectDetailsScreen({
    super.key,
    required this.projectName,
  });

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.projectName,
          style: const TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(
              icon: Icon(Icons.people),
              text: 'Project Management',
            ),
            Tab(
              icon: Icon(Icons.architecture),
              text: 'Architecture',
            ),
            Tab(
              icon: Icon(Icons.engineering),
              text: 'Civil',
            ),
            Tab(
              icon: Icon(Icons.calculate),
              text: 'Bill Of Quantities',
            ),
            Tab(
              icon: Icon(Icons.electrical_services),
              text: 'Electro-Mechanical Design',
            ),
            Tab(
              icon: Icon(Icons.location_on),
              text: 'On Site',
            ),
            Tab(
              icon: Icon(Icons.people_outline),
              text: 'Client Section',
            ),
            Tab(
              icon: Icon(Icons.home_work),
              text: 'Exterior and Interior Architecture',
            ),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent('Project Management'),
          _buildTabContent('Architecture'),
          _buildTabContent('Civil'),
          _buildTabContent('Bill Of Quantities'),
          _buildTabContent('Electro-Mechanical Design'),
          _buildTabContent('On Site'),
          _buildTabContent('Client Section'),
          _buildTabContent('Exterior and Interior Architecture'),
        ],
      ),
    );
  }
} 