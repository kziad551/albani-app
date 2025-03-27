import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

// Extension on String to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    return isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
  }
}

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<dynamic, dynamic>> _logs = [];
  List<Map<dynamic, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Filter controllers
  final _userNameController = TextEditingController();
  final _entityNameController = TextEditingController();
  final _actionController = TextEditingController();
  final _changesController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showFilters = false;
  
  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalLogs = 0;
  final int _logsPerPage = 50;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    
    // Add scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        _loadMoreLogs();
      }
    });
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _entityNameController.dispose();
    _actionController.dispose();
    _changesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      debugPrint('Fetching logs from API...');
      
      final logs = await _apiService.getLogs(
        userName: _userNameController.text.isEmpty ? null : _userNameController.text,
        entityName: _entityNameController.text.isEmpty ? null : _entityNameController.text,
        action: _actionController.text.isEmpty ? null : _actionController.text,
        fromDate: _fromDate,
        toDate: _toDate,
        page: 1,
        pageSize: 2500, // Request a very large number of logs
      );
      
      debugPrint('Fetched ${logs.length} logs');
      
      if (mounted) {
        setState(() {
          _logs = logs;
          _applyTextFilter(); // Apply any text filtering
          _totalLogs = _filteredLogs.length;
          _totalPages = (_totalLogs / _logsPerPage).ceil();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load logs: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore || _logs.length < _logsPerPage) {
      return; // No more logs to load
    }
    
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    
    try {
      print('Loading more logs, page: $_currentPage');
      
      final moreLogs = await _apiService.getLogs(
        userName: _userNameController.text.isEmpty ? null : _userNameController.text,
        entityName: _entityNameController.text.isEmpty ? null : _entityNameController.text,
        action: _actionController.text.isEmpty ? null : _actionController.text,
        fromDate: _fromDate,
        toDate: _toDate,
        page: _currentPage,
        pageSize: _logsPerPage,
      );
      
      if (mounted) {
        if (moreLogs.isNotEmpty) {
          setState(() {
            _logs.addAll(moreLogs);
            _applyTextFilter();
            _totalLogs = _filteredLogs.length;
            _isLoadingMore = false;
          });
          print('Added ${moreLogs.length} more logs, total: ${_logs.length}');
        } else {
          setState(() {
            _isLoadingMore = false;
          });
          print('No more logs to load');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
      print('Error loading more logs: $e');
    }
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages) {
      return;
    }
    
    setState(() {
      _currentPage = page;
    });
    
    _loadLogs();
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2025),
    );
    
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _userNameController.clear();
      _entityNameController.clear();
      _actionController.clear();
      _changesController.clear();
      _fromDate = null;
      _toDate = null;
      _currentPage = 1; // Reset to first page when clearing filters
    });
    _loadLogs();
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM d, yyyy HH:mm:ss').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  // Helper method to get timestamp from log with different possible field names
  String _getTimestampFromLog(Map<dynamic, dynamic> log) {
    try {
      // Try various field names that might contain the timestamp
      for (final field in [
        'timestamp', 'timeStamp', 'createdAt', 'date', 'time', 
        'creationDate', 'creationTime', 'updatedAt', 'createDate',
        'dateCreated', 'dateTime'
      ]) {
        if (log[field] != null && log[field].toString().isNotEmpty) {
          // Handle ISO date format or other common formats
          try {
            return _formatDateTime(log[field].toString());
          } catch (e) {
            debugPrint('Error formatting date from $field: $e');
          }
        }
      }
      
      // Look for field names with timestamp in them
      for (final key in log.keys) {
        if ((key.toString().toLowerCase().contains('time') || 
             key.toString().toLowerCase().contains('date') ||
             key.toString().toLowerCase().contains('created')) && 
            log[key] != null && 
            log[key].toString().isNotEmpty) {
          try {
            return _formatDateTime(log[key].toString());
          } catch (e) {
            // Not a valid date format, continue to next field
          }
        }
      }
      
      return 'No timestamp';
    } catch (e) {
      return 'Error: $e';
    }
  }
  
  // Helper method to get details from log with different possible field names
  String _getLogDetails(Map<dynamic, dynamic> log) {
    // Try various field names that might contain details
    for (final field in [
      'details', 'changes', 'description', 'displayName', 'message',
      'detail', 'data', 'properties', 'content', 'summary', 'info'
    ]) {
      if (log[field] != null) {
        var value = log[field].toString();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    
    // If no specific details field found, try to create a meaningful description
    var description = '';
    
    if (log['entityName'] != null && log['action'] != null) {
      var entity = log['entityName'].toString();
      var action = log['action'].toString();
      var targetName = '';
      
      // Try to find a name or identifier for the entity
      for (final field in ['name', 'title', 'label', 'id', 'guid']) {
        if (log[field] != null && log[field].toString().isNotEmpty) {
          targetName = log[field].toString();
          break;
        }
      }
      
      description = '$action $entity';
      if (targetName.isNotEmpty) {
        description += ' "$targetName"';
      }
      
      return description;
    }
    
    // Build description from available fields
    List<String> parts = [];
    for (var key in log.keys) {
      if (!key.toString().toLowerCase().contains('time') && 
          !key.toString().toLowerCase().contains('date') &&
          !key.toString().toLowerCase().contains('id') &&
          log[key] != null && 
          log[key].toString().isNotEmpty &&
          log[key].toString().length < 50) {  // Avoid very long values
        parts.add('${key.toString().replaceAll('_', ' ').capitalize()}: ${log[key]}');
        if (parts.length >= 3) break;  // Limit to 3 parts
      }
    }
    
    if (parts.isNotEmpty) {
      return parts.join(' | ');
    }
    
    return 'No details available';
  }

  // Apply text filtering based on changes text
  void _applyTextFilter() {
    final query = _changesController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredLogs = _logs;
    } else {
      _filteredLogs = _logs.where((log) {
        // Check various fields for the search term
        final details = _getLogDetails(log).toLowerCase();
        final userName = (log['userName'] ?? log['username'] ?? '').toString().toLowerCase();
        final entityName = (log['entityName'] ?? log['entity'] ?? '').toString().toLowerCase();
        final action = (log['action'] ?? '').toString().toLowerCase();
        
        return details.contains(query) || 
               userName.contains(query) || 
               entityName.contains(query) || 
               action.contains(query);
      }).toList();
    }
    
    _totalLogs = _filteredLogs.length;
    _totalPages = (_totalLogs / _logsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(),
      endDrawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLogs,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Filter Toggle Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Logs ($_totalLogs)',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showFilters = !_showFilters;
                              });
                            },
                            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
                            label: Text(_showFilters ? 'Hide Filters' : 'Show Filters'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Filter Panel
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _showFilters ? 370 : 0, // Increased height for the search box
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User Name Filter
                              TextField(
                                controller: _userNameController,
                                decoration: const InputDecoration(
                                  labelText: 'User Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Entity Name Filter
                              TextField(
                                controller: _entityNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Entity Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Action Filter
                              TextField(
                                controller: _actionController,
                                decoration: const InputDecoration(
                                  labelText: 'Action',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Changes/Content Filter
                              TextField(
                                controller: _changesController,
                                decoration: const InputDecoration(
                                  labelText: 'Search in Content',
                                  border: OutlineInputBorder(),
                                  hintText: 'Search in log details...',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _applyTextFilter();
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              
                              // Date Range
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _selectDate(context, true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              _fromDate == null
                                                  ? 'From Date'
                                                  : DateFormat('yyyy-MM-dd').format(_fromDate!),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _selectDate(context, false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              _toDate == null
                                                  ? 'To Date'
                                                  : DateFormat('yyyy-MM-dd').format(_toDate!),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Filter Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      _clearFilters();
                                      _changesController.clear();
                                      setState(() {
                                        _applyTextFilter();
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16, 
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Clear Filters'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentPage = 1; // Reset to first page when applying filters
                                      });
                                      _loadLogs();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1976D2),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16, 
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text('Apply Filters'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8), // Extra padding to prevent button cropping
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Logs Table
                    Expanded(
                      child: _buildLogsList(),
                    ),
                    
                    // Pagination controls similar to Users page
                    if (_totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: _currentPage > 1
                                  ? () => _changePage(_currentPage - 1)
                                  : null,
                            ),
                            Text(
                              'Page $_currentPage of $_totalPages',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: _currentPage < _totalPages
                                  ? () => _changePage(_currentPage + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildLogsList() {
    if (_filteredLogs.isEmpty) {
      return const Center(
        child: Text(
          'No logs found.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _filteredLogs.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the end
          if (index == _filteredLogs.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final log = _filteredLogs[index];
          final timestamp = _getTimestampFromLog(log);
          final details = _getLogDetails(log);
          final userName = log['userName'] ?? log['username'] ?? 'Unknown User';
          final action = log['action'] ?? 'Unknown Action';
          final entityName = log['entityName'] ?? log['entity'] ?? 'Unknown Entity';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
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
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          action.toString(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entityName.toString(),
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timestamp,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        userName.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      style: const TextStyle(fontSize: 14),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 