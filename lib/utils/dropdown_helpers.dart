import 'package:flutter/material.dart';

/// Utility class to provide standardized dropdown values and helpers
/// across the application to prevent inconsistencies and dropdown errors.
class DropdownHelpers {
  // Standard status options for projects
  static const List<String> projectStatusOptions = [
    'Pending',
    'In Progress',
    'Completed',
    'On Hold',
    'Cancelled'
  ];

  // Standard status options for tasks
  static const List<String> taskStatusOptions = [
    'Pending',
    'In Progress',
    'Done',
    'On Hold',
    'Cancelled',
    'Review'
  ];

  // Standard priority options
  static const List<String> priorityOptions = [
    'None',
    'Low',
    'Medium',
    'High'
  ];
  
  // Task filter status options
  static const List<Map<String, dynamic>> taskFilterStatusOptions = [
    {'value': 'all', 'label': 'All'},
    {'value': 'pending', 'label': 'Pending', 'icon': Icons.pending, 'color': Colors.orange},
    {'value': 'in_progress', 'label': 'In Progress', 'icon': Icons.trending_up, 'color': Colors.blue},
    {'value': 'completed', 'label': 'Done', 'icon': Icons.check_circle, 'color': Colors.green},
  ];
  
  // Normalizes a status value to ensure it matches one of the valid options
  static String normalizeProjectStatus(String? status) {
    if (status == null || status.isEmpty) {
      return 'In Progress';  // Default value
    }
    
    // Check exact match first
    if (projectStatusOptions.contains(status)) {
      return status;
    }
    
    // Try case-insensitive match
    for (var option in projectStatusOptions) {
      if (option.toLowerCase() == status.toLowerCase()) {
        return option;  // Return the properly cased version
      }
    }
    
    // Handle common variations
    switch (status.toLowerCase()) {
      case 'done':
        return 'Completed';
      case 'in-progress':
      case 'inprogress':
        return 'In Progress';
      default:
        return 'In Progress';  // Default fallback
    }
  }
  
  // Normalizes a task status value
  static String normalizeTaskStatus(String? status) {
    if (status == null || status.isEmpty) {
      return 'Pending';  // Default value
    }
    
    // Check exact match first
    if (taskStatusOptions.contains(status)) {
      return status;
    }
    
    // Try case-insensitive match
    for (var option in taskStatusOptions) {
      if (option.toLowerCase() == status.toLowerCase()) {
        return option;  // Return the properly cased version
      }
    }
    
    // Handle common variations
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Done';
      case 'in-progress':
      case 'inprogress':
        return 'In Progress';
      case 'to do':
      case 'todo':
      case 'new':
        return 'Pending';
      case 'in review':
        return 'Review';
      default:
        return 'Pending';  // Default fallback
    }
  }
  
  // Normalizes a priority value
  static String normalizePriority(String? priority) {
    if (priority == null || priority.isEmpty) {
      return 'Medium';  // Default value
    }
    
    // Check exact match first
    if (priorityOptions.contains(priority)) {
      return priority;
    }
    
    // Try case-insensitive match
    for (var option in priorityOptions) {
      if (option.toLowerCase() == priority.toLowerCase()) {
        return option;  // Return the properly cased version
      }
    }
    
    // Handle numeric priorities
    switch (priority) {
      case '0':
        return 'None';
      case '1':
        return 'Low';
      case '2':
        return 'Medium';
      case '3':
        return 'High';
      default:
        return 'Medium';  // Default fallback
    }
  }
  
  // Builds a standard set of priority DropdownMenuItems
  static List<DropdownMenuItem<String>> buildPriorityItems() {
    return priorityOptions.map((String value) {
      IconData icon;
      Color color;
      
      switch (value) {
        case 'High':
          icon = Icons.arrow_upward;
          color = Colors.red;
          break;
        case 'Medium':
          icon = Icons.remove;
          color = Colors.orange;
          break;
        case 'Low':
          icon = Icons.arrow_downward;
          color = Colors.green;
          break;
        default:
          icon = Icons.remove;
          color = Colors.grey;
      }
      
      return DropdownMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(value),
          ],
        ),
      );
    }).toList();
  }
} 