// MOBILE COMMENTS API METHODS
// Add these methods to lib/services/api_service.dart

// 1. GET TASK COMMENTS
Future<List<Map<String, dynamic>>> getTaskComments(String taskGuid) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }

    debugPrint('Getting comments for task: $taskGuid');
    
    final response = await get('api/BucketTasks/TaskComments?TaskGuid=$taskGuid');
    
    if (response is List) {
      return List<Map<String, dynamic>>.from(response.map((item) => Map<String, dynamic>.from(item)));
    }
    
    return [];
  } catch (e) {
    debugPrint('Error getting task comments: $e');
    return [];
  }
}

// 2. POST COMMENT TO TASK (text only)
Future<Map<String, dynamic>> addCommentToTask(String taskGuid, String commentText) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }

    debugPrint('Adding comment to task: $taskGuid');
    debugPrint('Comment text: $commentText');
    
    final data = {
      'BucketTaskGuid': taskGuid,
      'Text': commentText,
    };
    
    final response = await post('api/BucketTasks/AddCommentToTask', data);
    
    if (response is Map) {
      debugPrint('Comment added successfully');
      return Map<String, dynamic>.from(response);
    }
    
    throw Exception('Invalid response format');
  } catch (e) {
    debugPrint('Error adding comment: $e');
    throw Exception('Failed to add comment: $e');
  }
}

// 3. POST COMMENT WITH FILE ATTACHMENT
Future<Map<String, dynamic>> addCommentWithFile(String taskGuid, String commentText, String filePath) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }
    
    debugPrint('Adding comment with file to task: $taskGuid');
    debugPrint('Comment text: $commentText');
    debugPrint('File path: $filePath');
    
    // Get the file name from the path
    final fileName = filePath.split('/').last;
    
    // Create form data with the comment and file
    final formData = FormData.fromMap({
      'BucketTaskGuid': taskGuid,
      'Text': commentText,
      'File': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType.parse('application/octet-stream'),
      ),
    });
    
    // Get headers and base URL
    final headers = await _getHeaders();
    final baseUrl = await getBaseUrl();
    
    // Add specific headers for multipart uploads, but retain auth
    headers['Content-Type'] = 'multipart/form-data';
    
    debugPrint('Making comment with file upload request to: $baseUrl/api/BucketTasks/AddCommentToTask');
    debugPrint('FormData: BucketTaskGuid=$taskGuid, Text=$commentText, filename=$fileName');
    
    final response = await _dio.post(
      '$baseUrl/api/BucketTasks/AddCommentToTask',
      data: formData,
      options: Options(
        headers: headers,
        followRedirects: true,
        validateStatus: (status) => status! < 500,
      ),
    );
    
    debugPrint('Comment with file upload response: ${response.statusCode}');
    debugPrint('Response data: ${response.data}');
    
    if (response.statusCode! >= 200 && response.statusCode! < 300) {
      if (response.data is Map) {
        final comment = Map<String, dynamic>.from(response.data);
        debugPrint('Comment with file added successfully');
        return comment;
      } else if (response.data is String && response.data.toString().isNotEmpty) {
        try {
          final comment = jsonDecode(response.data);
          return Map<String, dynamic>.from(comment);
        } catch (e) {
          debugPrint('Could not parse response as JSON: $e');
        }
      }
    }
    
    throw Exception('Failed to add comment with file: Status ${response.statusCode}');
  } catch (e) {
    debugPrint('Error adding comment with file: $e');
    throw Exception('Failed to add comment with file: $e');
  }
}

// 4. EDIT COMMENT
Future<Map<String, dynamic>> editComment(String commentGuid, String newText) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }

    debugPrint('Editing comment: $commentGuid');
    debugPrint('New text: $newText');
    
    final data = {
      'CommentGuid': commentGuid,
      'Text': newText,
    };
    
    final response = await post('api/BucketTasks/EditComment', data);
    
    if (response is Map) {
      debugPrint('Comment edited successfully');
      return Map<String, dynamic>.from(response);
    }
    
    throw Exception('Invalid response format');
  } catch (e) {
    debugPrint('Error editing comment: $e');
    throw Exception('Failed to edit comment: $e');
  }
}

// 5. DELETE COMMENT
Future<bool> deleteComment(String commentGuid) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }

    debugPrint('Deleting comment: $commentGuid');
    
    final data = {
      'Guid': commentGuid,
    };
    
    final response = await post('api/BucketTasks/DeleteComment', data);
    
    debugPrint('Comment deleted successfully');
    return true;
  } catch (e) {
    debugPrint('Error deleting comment: $e');
    return false;
  }
}

// 6. GET USERS FOR MENTIONS
Future<List<Map<String, dynamic>>> getUsersForMention(String query) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }

    debugPrint('Getting users for mention with query: $query');
    
    final response = await get('api/Employees/getUsersForMention?query=$query');
    
    if (response is List) {
      return List<Map<String, dynamic>>.from(response.map((item) => Map<String, dynamic>.from(item)));
    }
    
    return [];
  } catch (e) {
    debugPrint('Error getting users for mention: $e');
    return [];
  }
} 