import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../utils/html_parser.dart';

class CommentSection extends StatefulWidget {
  final String taskGuid;
  final ApiService apiService;

  const CommentSection({
    Key? key,
    required this.taskGuid,
    required this.apiService,
  }) : super(key: key);

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<PlatformFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await widget.apiService.getTaskComments(widget.taskGuid);
      
      // Load attachments for each comment
      for (final comment in comments) {
        if (comment['guid'] != null) {
          final attachments = await widget.apiService.getCommentAttachments(comment['guid']);
          comment['attachments'] = attachments;
        }
      }
      
      setState(() {
        _comments = comments;
      });
    } catch (e) {
      debugPrint('Error loading comments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

    Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Create the comment first (text only)
      final createdComment = await widget.apiService.createTaskComment(widget.taskGuid, text);
      // Try to get guid from nested data or top-level
      final commentGuid = (createdComment['data']?['guid'] ?? createdComment['guid'] ?? createdComment['id'])?.toString();
      
      // 2. Upload files if any are selected, linking to the comment
      if (_selectedFiles.isNotEmpty && commentGuid != null) {
        for (final file in _selectedFiles) {
          try {
            if (kIsWeb) {
              if (file.bytes != null) {
                await widget.apiService.uploadFileToTaskFromBytes(
                  widget.taskGuid,
                  file.bytes!,
                  file.name,
                  extra: {'SecondaryText': 'COMMENT:$commentGuid'},
                );
              }
            } else {
              await widget.apiService.uploadFileToTask(
                widget.taskGuid,
                file.path!,
                extra: {'SecondaryText': 'COMMENT:$commentGuid'},
              );
            }
          } catch (e) {
            debugPrint('Error uploading file for comment: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload attachment: $e')),
            );
          }
        }
      }
      _commentController.clear();
      _selectedFiles.clear();
      await _loadComments();
    } catch (e) {
      debugPrint('Error submitting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting comment: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: kIsWeb, // Load bytes for web platform
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting files: $e')),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _downloadAttachment(Map<String, dynamic> attachment) async {
    try {
      final fileGuid = attachment['guid']?.toString();
      if (fileGuid != null) {
        final downloadUrl = await widget.apiService.getFileDownloadUrl(fileGuid);
        debugPrint('Download URL: $downloadUrl');
        // Note: Actual download implementation depends on platform
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download started for ${attachment['fileName']}')),
        );
      }
    } catch (e) {
      debugPrint('Error downloading attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        
        // Comments list
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_comments.isEmpty)
          const Text(
            'No comments yet. Be the first one to comment!',
            style: TextStyle(color: Colors.grey),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              final author = comment['author'] ?? comment['owner'];
              final attachments = comment['attachments'] ?? [];
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Author and date
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue,
                            child: Text(
                              (author?['displayName']?.toString() ?? 'U').substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      author?['displayName']?.toString() ?? 'Unknown User',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    if (comment['isLocal'] == true) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[100],
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'SYNCING',
                                          style: TextStyle(fontSize: 8, color: Colors.orange),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  _formatDate(comment['createdAt']?.toString()),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Comment text
                      Text(
                        HtmlParser.stripHtml(comment['text']?.toString() ?? ''),
                        style: const TextStyle(fontSize: 14),
                      ),
                      
                      // Attachments
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Attachments:',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        ...attachments.map<Widget>((attachment) {
                          return InkWell(
                            onTap: () => _downloadAttachment(attachment),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    attachment['fileName']?.toString() ?? 'Unknown file',
                                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                                  ),
                                  if (attachment['fileSize'] != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${_formatFileSize(attachment['fileSize'])})',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  const Icon(Icons.download, size: 14, color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        
        const SizedBox(height: 16),
        
        // Comment input section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected files display
            if (_selectedFiles.isNotEmpty) ...[
              const Text(
                'Selected files:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selectedFiles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          file.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (file.size > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${_formatFileSize(file.size)})',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _removeFile(index),
                          child: const Icon(Icons.close, size: 14, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            
            // Comment input field
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Type a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _isSubmitting ? null : _pickFiles,
                      icon: const Icon(Icons.attach_file),
                      tooltip: 'Attach files',
                    ),
                    TextButton(
                      onPressed: _isSubmitting ? null : _submitComment,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('POST'),
                    ),
                  ],
                ),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
} 