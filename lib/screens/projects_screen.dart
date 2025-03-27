import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import 'add_project_screen.dart';
import 'project_details_screen.dart';
import 'edit_project_screen.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import '../models/project.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _filteredProjects = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _needsRefresh = false;
  bool _showFilters = false;
  
  // Filter controllers
  final TextEditingController _titleSearchController = TextEditingController();
  final TextEditingController _managerSearchController = TextEditingController();
  String _groupByValue = 'None';
  final List<String> _groupByOptions = ['None', 'Status', 'Location', 'Manager'];
  
  // Map to store expanded state of grouped projects
  final Map<String, bool> _groupExpandedState = {};

  // Additional state variables for pagination
  int _currentPage = 1;
  int _itemsPerPage = 7; // Show 7 projects per page
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProjects();
    
    // Listen to filter text changes
    _titleSearchController.addListener(_applyFilters);
    _managerSearchController.addListener(_applyFilters);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleSearchController.dispose();
    _managerSearchController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needsRefresh) {
      _loadProjects();
      _needsRefresh = false;
    } else if (state == AppLifecycleState.paused) {
      _needsRefresh = true;
    }
  }
  
  Future<void> _loadProjects() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final projects = await _apiService.getProjects();
      
      if (mounted) {
        setState(() {
          _projects = projects;
          _filteredProjects = List.from(projects);
          _isLoading = false;
        });
        
        // Apply any existing filters
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load projects: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  void _applyFilters() {
    final String titleFilter = _titleSearchController.text.toLowerCase();
    final String managerFilter = _managerSearchController.text.toLowerCase();
    
    setState(() {
      _filteredProjects = _projects.where((project) {
        // Filter by title/description
        final bool matchesTitle = titleFilter.isEmpty || 
          (project['name'] ?? '').toString().toLowerCase().contains(titleFilter) ||
          (project['title'] ?? '').toString().toLowerCase().contains(titleFilter) ||
          (project['description'] ?? '').toString().toLowerCase().contains(titleFilter);
        
        // Filter by manager
        final bool matchesManager = managerFilter.isEmpty ||
          (project['managedBy'] ?? '').toString().toLowerCase().contains(managerFilter);
        
        return matchesTitle && matchesManager;
      }).toList();
    });
  }
  
  void _toggleGroupByOption(String value) {
    setState(() {
      _groupByValue = value;
      // Reset expanded state when grouping changes
      _groupExpandedState.clear();
    });
  }
  
  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }
  
  void _clearFilters() {
    setState(() {
      _titleSearchController.clear();
      _managerSearchController.clear();
      _groupByValue = 'None';
      _filteredProjects = List.from(_projects);
      _groupExpandedState.clear();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return const Color.fromRGBO(25, 118, 210, 1); // rgb(25, 118, 210)
      case 'completed':
        return const Color.fromRGBO(46, 125, 50, 1); // rgb(46, 125, 50)
      case 'on hold':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return const Color.fromRGBO(237, 108, 2, 1); // rgb(237, 108, 2)
      default:
        return Colors.grey;
    }
  }

  // Method to get current page projects
  List<Map<String, dynamic>> _getCurrentPageProjects() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    
    if (startIndex >= _filteredProjects.length) {
      // If current page is out of range, go back to page 1
      _currentPage = 1;
      return _filteredProjects.take(_itemsPerPage).toList();
    }
    
    return _filteredProjects.sublist(
      startIndex, 
      endIndex > _filteredProjects.length ? _filteredProjects.length : endIndex
    );
  }
  
  // Method to calculate total pages
  int _getTotalPages() {
    return (_filteredProjects.length / _itemsPerPage).ceil();
  }
  
  // Method to handle page changes
  void _changePage(int page) {
    if (page < 1 || page > _getTotalPages()) return;
    
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(),
      endDrawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddProjectScreen(),
            ),
          );
          
          if (result == true) {
            // Refresh the projects list when returning from add screen
            _loadProjects();
          }
        },
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading projects...')
          : _errorMessage != null
              ? CustomErrorWidget(
                  message: _errorMessage!,
                  onRetry: _loadProjects,
                )
              : Column(
                  children: [
                    // Filter section that slides down
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _showFilters ? 190 : 0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: _showFilters 
                          ? [BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 3),
                            )]
                          : [],
                      ),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Search by Title / Description',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _titleSearchController,
                                decoration: InputDecoration(
                                  hintText: 'Enter title or description',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.grey),
                                  ),
                                  suffixIcon: _titleSearchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => _titleSearchController.clear(),
                                      )
                                    : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              const Text(
                                'Search by Manager',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _managerSearchController,
                                decoration: InputDecoration(
                                  hintText: 'Enter manager name',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Colors.grey),
                                  ),
                                  suffixIcon: _managerSearchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => _managerSearchController.clear(),
                                      )
                                    : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              Row(
                                children: [
                                  const Text(
                                    'Grouped by',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _groupByValue,
                                          isExpanded: true,
                                          icon: const Icon(Icons.arrow_drop_down),
                                          iconSize: 24,
                                          elevation: 16,
                                          style: const TextStyle(color: Colors.black),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              _toggleGroupByOption(newValue);
                                            }
                                          },
                                          items: _groupByOptions.map<DropdownMenuItem<String>>((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _clearFilters,
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Projects count with filter icon
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Projects (${_filteredProjects.length})',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _showFilters ? Icons.filter_list_off : Icons.filter_list,
                              color: const Color(0xFF1976D2),
                            ),
                            onPressed: _toggleFilters,
                            tooltip: 'Filter projects',
                          ),
                        ],
                      ),
                    ),
                    
                    // Projects list
                    Expanded(
                      child: _filteredProjects.isEmpty
                          ? const Center(
                              child: Text(
                                'No projects found.\nClick "ADD NEW PROJECT" to create one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : _groupByValue == 'None'
                              ? _buildProjectList(_filteredProjects)
                              : _buildGroupedProjectList(),
                    ),
                  ],
                ),
    );
  }
  
  Widget _buildProjectList(List<Map<String, dynamic>> projects) {
    final currentPageProjects = _getCurrentPageProjects();
    final totalPages = _getTotalPages();
    
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProjects,
            child: ListView.builder(
              itemCount: currentPageProjects.length,
              padding: const EdgeInsets.all(8.0),
              itemBuilder: (context, index) {
                final project = currentPageProjects[index];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    color: const Color(0xFF1E293E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  project['name'] ?? project['title'] ?? 'Untitled Project',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onSelected: (value) {
                                  final projectId = project['id'] ?? 0;
                                  final projectName = project['name'] ?? project['title'] ?? 'Untitled Project';
                                  
                                  if (value == 'view') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProjectDetailsScreen(
                                          projectId: project['id'] ?? project['guid'] ?? "0",
                                          projectDetails: project,
                                          projectName: projectName,
                                        ),
                                      ),
                                    ).then((_) => setState(() => _needsRefresh = true));
                                  } else if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditProjectScreen(
                                          projectId: projectId,
                                          title: project['name'] ?? project['title'] ?? '',
                                          description: project['description'] ?? '',
                                          location: project['location'] ?? '',
                                          status: project['status'] ?? 'In Progress',
                                        ),
                                      ),
                                    ).then((_) => setState(() => _needsRefresh = true));
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        Icon(Icons.visibility, size: 18),
                                        SizedBox(width: 8),
                                        Text('View'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Status tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(project['status'] ?? 'In Progress'),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              project['status'] ?? 'In Progress',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Location
                          if (project['location'] != null && project['location'].toString().isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    project['location'].toString(),
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(200),
                                      fontSize: 12,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          // Manager
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${project['managedBy'] ?? 'Oussama Tahmaz'}",
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(200),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              // View details link
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProjectDetailsScreen(
                                        projectId: project['id'] ?? project['guid'] ?? "0",
                                        projectName: project['name'] ?? project['title'] ?? 'Untitled Project',
                                        projectDetails: project,
                                      ),
                                    ),
                                  ).then((_) => setState(() => _needsRefresh = true));
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('EXPAND', style: TextStyle(fontSize: 12)),
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
        ),
        
        // Pagination controls - only show if we have more than 1 page
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                ),
                Text(
                  'Page $_currentPage of $totalPages',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: _currentPage < totalPages ? () => _changePage(_currentPage + 1) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildGroupedProjectList() {
    // Group projects by the selected field
    final Map<String, List<Map<String, dynamic>>> groupedProjects = {};
    
    String groupField;
    switch (_groupByValue) {
      case 'Status':
        groupField = 'status';
        break;
      case 'Location':
        groupField = 'location';
        break;
      case 'Manager':
        groupField = 'managedBy';
        break;
      default:
        groupField = '';
    }
    
    for (final project in _filteredProjects) {
      final groupValue = (project[groupField] ?? 'Unknown').toString();
      if (!groupedProjects.containsKey(groupValue)) {
        groupedProjects[groupValue] = [];
        // Initialize expanded state if not already set
        _groupExpandedState[groupValue] ??= true;
      }
      groupedProjects[groupValue]!.add(project);
    }
    
    // Convert grouped projects to a list of widgets
    List<Widget> groupWidgets = [];
    
    groupedProjects.forEach((groupName, projects) {
      // Add group header
      groupWidgets.add(
        Container(
          color: Colors.grey.shade200,
          child: ListTile(
            title: Text(
              '$_groupByValue: $groupName (${projects.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Icon(
              _groupExpandedState[groupName]! ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                _groupExpandedState[groupName] = !_groupExpandedState[groupName]!;
              });
            },
          ),
        ),
      );
      
      // Add projects in this group if expanded
      if (_groupExpandedState[groupName]!) {
        for (final project in projects) {
          groupWidgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Card(
                color: const Color(0xFF1E293E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  title: Text(
                    (project['name'] ?? project['title'] ?? 'Untitled Project').toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (groupField != 'status') 
                        Text(
                          'Status: ${project['status'] ?? 'Unknown'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (groupField != 'location') 
                        Text(
                          'Location: ${project['location'] ?? 'N/A'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (groupField != 'managedBy' && project['managedBy'] != null) 
                        Text(
                          'Manager: ${project['managedBy']}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailsScreen(
                          projectId: project['id'] ?? project['guid'] ?? "0",
                          projectName: project['name'] ?? project['title'] ?? 'Untitled Project',
                          projectDetails: project,
                        ),
                      ),
                    );
                    
                    setState(() {
                      _needsRefresh = true;
                    });
                  },
                ),
              ),
            ),
          );
        }
      }
    });
    
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView(
        padding: const EdgeInsets.all(8.0),
        children: groupWidgets,
      ),
    );
  }
} 