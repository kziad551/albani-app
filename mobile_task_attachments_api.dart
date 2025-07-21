// MOBILE TASK ATTACHMENTS API METHODS
// Add these methods to lib/services/api_service.dart

// 1. GET TASK ATTACHMENTS
Future<List<Map<String, dynamic>>> getTaskAttachments(String taskGuid) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }

    debugPrint('Getting attachments for task: $taskGuid');
    
    final response = await get('api/Attachments/GetTaskAttachments?TaskGuid=$taskGuid');
    
    if (response is List) {
      return List<Map<String, dynamic>>.from(response.map((item) => Map<String, dynamic>.from(item)));
    }
    
    return [];
  } catch (e) {
    debugPrint('Error getting task attachments: $e');
    return [];
  }
}

// 2. UPLOAD FILE TO TASK
Future<Map<String, dynamic>> uploadFileToTask(String taskGuid, String filePath) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }
    
    debugPrint('Uploading file to task: $taskGuid');
    debugPrint('File path: $filePath');
    
    // Get the file name from the path
    final fileName = filePath.split('/').last;
    
    // Create form data with the file
    final formData = FormData.fromMap({
      'BucketTaskGuid': taskGuid,
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
    
    debugPrint('Making task file upload request to: $baseUrl/api/BucketTasks/AddFileToTask');
    debugPrint('FormData: BucketTaskGuid=$taskGuid, filename=$fileName');
    
    final response = await _dio.post(
      '$baseUrl/api/BucketTasks/AddFileToTask',
      data: formData,
      options: Options(
        headers: headers,
        followRedirects: true,
        validateStatus: (status) => status! < 500,
      ),
    );
    
    debugPrint('Task file upload response: ${response.statusCode}');
    debugPrint('Response data: ${response.data}');
    
    if (response.statusCode! >= 200 && response.statusCode! < 300) {
      if (response.data is Map) {
        final uploadedFile = Map<String, dynamic>.from(response.data);
        debugPrint('File uploaded to task successfully: ${uploadedFile['id'] ?? uploadedFile['guid']}');
        return uploadedFile;
      } else if (response.data is String && response.data.toString().isNotEmpty) {
        try {
          final uploadedFile = jsonDecode(response.data);
          return Map<String, dynamic>.from(uploadedFile);
        } catch (e) {
          debugPrint('Could not parse response as JSON: $e');
        }
      }
    }
    
    throw Exception('Failed to upload file to task: Status ${response.statusCode}');
  } catch (e) {
    debugPrint('Error uploading file to task: $e');
    throw Exception('Failed to upload file to task: $e');
  }
}

// 3. DELETE TASK ATTACHMENT
Future<bool> deleteTaskAttachment(String attachmentGuid) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }

    debugPrint('Deleting task attachment: $attachmentGuid');
    
    final data = {
      'Guid': attachmentGuid,
    };
    
    final response = await post('api/BucketTasks/DeleteAttachmentFromTask', data);
    
    debugPrint('Task attachment deleted successfully');
    return true;
  } catch (e) {
    debugPrint('Error deleting task attachment: $e');
    return false;
  }
}

// 4. DOWNLOAD TASK ATTACHMENT
Future<String?> downloadTaskAttachment(String attachmentGuid, String fileName) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }

    debugPrint('Downloading task attachment: $attachmentGuid');
    
    // Use your existing downloadFile method if available
    return await downloadFile(attachmentGuid, fileName);
  } catch (e) {
    debugPrint('Error downloading task attachment: $e');
    return null;
  }
} 