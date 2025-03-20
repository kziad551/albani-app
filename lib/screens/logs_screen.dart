import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  String? _errorMessage = null;
  
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
  ScrollController _scrollController = ScrollController();

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
      print('Fetching logs from API...');
      
      final logs = await _apiService.getLogs(
        userName: _userNameController.text.isEmpty ? null : _userNameController.text,
        entityName: _entityNameController.text.isEmpty ? null : _entityNameController.text,
        action: _actionController.text.isEmpty ? null : _actionController.text,
        fromDate: _fromDate,
        toDate: _toDate,
        page: _currentPage,
        pageSize: _logsPerPage,
      );
      
      print('Fetched ${logs.length} logs');
      
      if (mounted) {
        setState(() {
          _logs = logs;
          _filteredLogs = logs;
          _totalLogs = logs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching logs: $e');
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
            _filteredLogs = _logs;
            _totalLogs = _logs.length;
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
  String _getTimestampFromLog(Map<String, dynamic> log) {
    if (log['timestamp'] != null) {
      return _formatDateTime(log['timestamp'].toString());
    } else if (log['timeStamp'] != null) {
      return _formatDateTime(log['timeStamp'].toString());
    } else if (log['createdAt'] != null) {
      return _formatDateTime(log['createdAt'].toString());
    } else if (log['date'] != null) {
      return _formatDateTime(log['date'].toString());
    }
    return 'Unknown Time';
  }
  
  // Helper method to get details from log with different possible field names
  String _getLogDetails(Map<String, dynamic> log) {
    if (log['details'] != null && log['details'].toString().isNotEmpty) {
      return log['details'].toString();
    } else if (log['changes'] != null && log['changes'].toString().isNotEmpty) {
      return log['changes'].toString();
    } else if (log['description'] != null && log['description'].toString().isNotEmpty) {
      return log['description'].toString();
    } else if (log['displayName'] != null && log['displayName'].toString().isNotEmpty) {
      return log['displayName'].toString();
    } else if (log['message'] != null && log['message'].toString().isNotEmpty) {
      return log['message'].toString();
    }
    return '';
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
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Filter Panel
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _showFilters ? 300 : 0,
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
                                    onPressed: _clearFilters,
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
                                    ),
                                    child: const Text('Apply Filters'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Logs Table
                    Expanded(
                      child: _logs.isEmpty
                          ? const Center(
                              child: Text(
                                'No logs found.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadLogs,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _logs.length + 1, // +1 for loading indicator
                                itemBuilder: (context, index) {
                                  if (index == _logs.length) {
                                    // Show loading indicator at the end
                                    return _isLoadingMore
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      : Container();
                                  }
                                  
                                  final log = _logs[index];
                                  
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
                                                  log['action'] ?? 'Unknown Action',
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
                                                  log['entityName'] ?? 'Unknown Entity',
                                                  style: const TextStyle(
                                                    color: Colors.purple,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                _getTimestampFromLog(log),
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
                                                log['userName'] ?? 'Unknown User',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (_getLogDetails(log).isNotEmpty)
                                            Text(
                                              _getLogDetails(log),
                                              style: const TextStyle(fontSize: 14),
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
    );
  }
} 