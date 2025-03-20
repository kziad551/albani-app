/// Project model class for representing projects in the application
class Project {
  final int id;
  final String title;
  final String description;
  final String location;
  final String status;
  final String managedBy;
  final String guid;
  final bool isDeleted;
  final bool isInactive;

  /// Constructor
  Project({
    required this.id,
    required this.title,
    this.description = '',
    this.location = '',
    this.status = 'In Progress',
    this.managedBy = '',
    this.guid = '',
    this.isDeleted = false,
    this.isInactive = false,
  });

  /// Factory constructor to create a Project from a JSON map
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? 'Untitled Project',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      status: json['status'] ?? 'In Progress',
      managedBy: json['managedBy'] ?? '',
      guid: json['guid'] ?? '',
      isDeleted: json['isDeleted'] == true || json['isDeleted'] == 'true',
      isInactive: json['isInactive'] == true || json['isInactive'] == 'true',
    );
  }

  /// Convert Project to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'status': status,
      'managedBy': managedBy,
      'guid': guid,
      'isDeleted': isDeleted,
      'isInactive': isInactive,
    };
  }

  /// Create a copy of this Project with the provided changes
  Project copyWith({
    int? id,
    String? title,
    String? description,
    String? location,
    String? status,
    String? managedBy,
    String? guid,
    bool? isDeleted,
    bool? isInactive,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      status: status ?? this.status,
      managedBy: managedBy ?? this.managedBy,
      guid: guid ?? this.guid,
      isDeleted: isDeleted ?? this.isDeleted,
      isInactive: isInactive ?? this.isInactive,
    );
  }
} 