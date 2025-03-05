import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import 'add_project_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _showFilter = false;
  final _titleController = TextEditingController();
  final _managerController = TextEditingController();
  String? _groupedBy;

  @override
  void dispose() {
    _titleController.dispose();
    _managerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top buttons row
            Row(
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
                  onPressed: () {
                    setState(() {
                      _showFilter = !_showFilter;
                    });
                  },
                  icon: const Icon(Icons.filter_list),
                ),
              ],
            ),
            
            // Filter Section
            if (_showFilter) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Search by Title / Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _managerController,
                decoration: InputDecoration(
                  hintText: 'Search by Manager',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _groupedBy,
                decoration: InputDecoration(
                  hintText: 'Grouped by',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'status', child: Text('Status')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'location', child: Text('Location')),
                ],
                onChanged: (value) {
                  setState(() {
                    _groupedBy = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 24),
            
            // Project cards
            Expanded(
              child: ListView.builder(
                itemCount: 3,
                itemBuilder: (context, index) {
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Managed By : Oussama Tahmaz',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    // TODO: Implement more options
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ab014-Centre Ivoire',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
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
                                color: const Color(0xFF1976D2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'IN PROGRESS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Côte d'Ivoire",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    // TODO: Implement details action
                                  },
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
      ),
    );
  }
} 