import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import 'add_project_screen.dart';
import 'project_details_screen.dart';
import 'edit_project_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _showFilter = false;
  final _searchController = TextEditingController();
  String? _sortBy;
  String? _status;
  String? _assignee;
  String? _priority;
  String? _groupBy;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return const Color(0xFF1976D2);
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(),
      endDrawer: const AppDrawer(),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showFilter ? 320 : 0,
            color: Colors.white,
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _sortBy,
                      decoration: const InputDecoration(
                        labelText: 'Sort By',
                        border: OutlineInputBorder(),
                      ),
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
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
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
                      decoration: const InputDecoration(
                        labelText: 'Group By',
                        border: OutlineInputBorder(),
                      ),
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
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddProjectScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'ADD NEW PROJECT',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _showFilter = !_showFilter),
                  icon: const Icon(Icons.filter_list),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) {
                final List<Map<String, String>> projects = [
                  {
                    'title': 'KP02-Tchatche',
                    'status': 'Pending',
                    'location': 'Democratic Republic of the Congo',
                    'manager': 'Oussama Tahmaz'
                  },
                  {
                    'title': 'L003-CALLA (M-4151)',
                    'status': 'In Progress',
                    'location': 'Lebanon',
                    'manager': 'Oussama Tahmaz'
                  },
                  {
                    'title': 'Ab001-La Reine',
                    'status': 'Completed',
                    'location': "Côte d'Ivoire",
                    'manager': 'Oussama Tahmaz'
                  },
                ];

                final project = projects[index];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    color: const Color(0xFF1E293E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.folder_outlined,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project['title']!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(project['status']!),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        project['status']!.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                ),
                                onSelected: (value) {
                                  if (value == 'expand') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProjectDetailsScreen(
                                          projectName: project['title']!,
                                        ),
                                      ),
                                    );
                                  } else if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        fullscreenDialog: true,
                                        builder: (context) => EditProjectScreen(
                                          title: project['title']!,
                                          description: '',
                                          location: project['location']!,
                                          status: project['status']!,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(
                                    value: 'expand',
                                    child: Text('Expand'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Managed By: ${project['manager']}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Location: ${project['location']}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
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