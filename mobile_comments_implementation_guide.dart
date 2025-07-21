// MOBILE COMMENTS IMPLEMENTATION GUIDE

// 1. COMMENT DATA MODEL
// Add this to lib/models/comment.dart
class Comment {
  final String id;
  final String guid;
  final String text;
  final String authorId;
  final String bucketTaskGuid;
  final String? parentId;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Author? author;
  final List<Comment> replies;
  final List<CommentAttachment> attachments;

  Comment({
    required this.id,
    required this.guid,
    required this.text,
    required this.authorId,
    required this.bucketTaskGuid,
    this.parentId,
    required this.isEdited,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.replies = const [],
    this.attachments = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      guid: json['guid'] ?? '',
      text: json['text'] ?? '',
      authorId: json['authorId'] ?? '',
      bucketTaskGuid: json['bucketTaskGuid'] ?? '',
      parentId: json['parentId'],
      isEdited: json['isEdited'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      author: json['author'] != null ? Author.fromJson(json['author']) : null,
      replies: json['children'] != null 
          ? (json['children'] as List).map((reply) => Comment.fromJson(reply)).toList()
          : [],
      attachments: json['attachments'] != null
          ? (json['attachments'] as List).map((att) => CommentAttachment.fromJson(att)).toList()
          : [],
    );
  }
}

class Author {
  final String id;
  final String name;
  final String? displayName;
  final String? profileUrl;

  Author({
    required this.id,
    required this.name,
    this.displayName,
    this.profileUrl,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'] ?? '',
      name: json['name'] ?? json['userName'] ?? '',
      displayName: json['displayName'],
      profileUrl: json['profileUrl'],
    );
  }
}

class CommentAttachment {
  final String id;
  final String guid;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String path;

  CommentAttachment({
    required this.id,
    required this.guid,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.path,
  });

  factory CommentAttachment.fromJson(Map<String, dynamic> json) {
    return CommentAttachment(
      id: json['id']?.toString() ?? '',
      guid: json['guid'] ?? '',
      fileName: json['fileName'] ?? '',
      fileType: json['fileType'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      path: json['path'] ?? '',
    );
  }
}

// 2. COMMENTS WIDGET IMPLEMENTATION
// Create lib/widgets/comments_section.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/html_parser.dart';

class CommentsSection extends StatefulWidget {
  final String taskGuid;
  
  const CommentsSection({Key? key, required this.taskGuid}) : super(key: key);
  
  @override
  _CommentsSectionState createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  List<Comment> comments = [];
  bool isLoading = false;
  bool isPosting = false;
  String? selectedFilePath;
  String? selectedFileName;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      isLoading = true;
    });

    try {
      final commentsData = await _apiService.getTaskComments(widget.taskGuid);
      setState(() {
        comments = commentsData.map((data) => Comment.fromJson(data)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load comments: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null) {
        setState(() {
          selectedFilePath = result.files.single.path;
          selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty && selectedFilePath == null) {
      return;
    }

    setState(() {
      isPosting = true;
    });

    try {
      if (selectedFilePath != null) {
        // Post comment with file
        await _apiService.addCommentWithFile(
          widget.taskGuid,
          _commentController.text.trim(),
          selectedFilePath!,
        );
      } else {
        // Post text-only comment
        await _apiService.addCommentToTask(
          widget.taskGuid,
          _commentController.text.trim(),
        );
      }

      _commentController.clear();
      setState(() {
        selectedFilePath = null;
        selectedFileName = null;
      });
      
      await _loadComments();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment posted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
    } finally {
      setState(() {
        isPosting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Comment input section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  border: InputBorder.none,
                ),
                maxLines: 3,
              ),
              if (selectedFileName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(selectedFileName!)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          setState(() {
                            selectedFilePath = null;
                            selectedFileName = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _pickFile,
                  ),
                  ElevatedButton(
                    onPressed: isPosting ? null : _submitComment,
                    child: isPosting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Post'),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Comments list
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (comments.isEmpty)
          const Text('No comments yet')
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              return CommentItem(comment: comments[index]);
            },
          ),
      ],
    );
  }
}

class CommentItem extends StatelessWidget {
  final Comment comment;
  
  const CommentItem({Key? key, required this.comment}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: comment.author?.profileUrl != null
                    ? NetworkImage(comment.author!.profileUrl!)
                    : null,
                child: comment.author?.profileUrl == null
                    ? Text(comment.author?.displayName?.substring(0, 1) ?? 'U')
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                comment.author?.displayName ?? comment.author?.name ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                _formatDateTime(comment.createdAt),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(HtmlParser.stripHtml(comment.text)),
          
          // Show attachments if any
          if (comment.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...comment.attachments.map((attachment) => Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attachment.fileName),
                        Text(
                          HtmlParser.formatFileSize(attachment.fileSize),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, size: 16),
                    onPressed: () {
                      // Implement download functionality
                    },
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// 3. HTML PARSER UTILITY
// Create lib/utils/html_parser.dart
class HtmlParser {
  static String stripHtml(String htmlText) {
    if (htmlText.isEmpty) return htmlText;
    
    String cleanText = htmlText.replaceAll(RegExp(r'<[^>]*>'), '');
    
    cleanText = cleanText
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    
    return cleanText.trim();
  }
  
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// 4. USAGE IN TASK DETAIL SCREEN
// Add this to your task detail screen after task attachments
CommentsSection(taskGuid: task.guid),

// 5. REQUIRED DEPENDENCIES
// Add to pubspec.yaml:
dependencies:
  file_picker: ^5.5.0
  image_picker: ^1.0.4 