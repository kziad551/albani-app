# MOBILE COMMENTS IMPLEMENTATION PROMPT

## OVERVIEW
You need to implement a complete comments system for tasks in the mobile app. Users should be able to:
1. View all comments for a task
2. Post text comments
3. Post comments with file attachments
4. Edit their own comments
5. Delete their own comments
6. See user mentions in comments
7. Download comment attachments

## BACKEND API ENDPOINTS AVAILABLE

### 1. Get Task Comments
```
GET /api/BucketTasks/TaskComments?TaskGuid={taskGuid}
```
Returns array of comment objects with nested structure for replies

### 2. Add Comment (Text Only)
```
POST /api/BucketTasks/AddCommentToTask
Body: {
  "BucketTaskGuid": "task-guid",
  "Text": "comment text"
}
```

### 3. Add Comment with File
```
POST /api/BucketTasks/AddCommentToTask
Content-Type: multipart/form-data
FormData:
- BucketTaskGuid: "task-guid"
- Text: "comment text"
- File: (file upload)
```

### 4. Edit Comment
```
POST /api/BucketTasks/EditComment
Body: {
  "CommentGuid": "comment-guid",
  "Text": "new text"
}
```

### 5. Delete Comment
```
POST /api/BucketTasks/DeleteComment
Body: {
  "Guid": "comment-guid"
}
```

### 6. Get Users for Mentions
```
GET /api/Employees/getUsersForMention?query={searchText}
```

## COMMENT DATA STRUCTURE
```json
{
  "id": "123",
  "guid": "comment-guid",
  "text": "Comment text with possible <p>HTML tags</p>",
  "authorId": "user-id",
  "bucketTaskGuid": "task-guid",
  "parentId": null,
  "isEdited": false,
  "createdAt": "2024-01-01T10:00:00Z",
  "updatedAt": "2024-01-01T10:00:00Z",
  "author": {
    "id": "user-id",
    "name": "username",
    "displayName": "Display Name",
    "profileUrl": "path/to/avatar.jpg"
  },
  "children": [],
  "attachments": [
    {
      "id": "att-id",
      "guid": "att-guid",
      "fileName": "document.pdf",
      "fileType": "application/pdf",
      "fileSize": 1024000,
      "path": "uploads/document.pdf"
    }
  ]
}
```

## IMPORTANT IMPLEMENTATION NOTES

### 1. HTML Content Handling
- Comments may contain HTML tags like `<p>`, `<br>`, etc.
- You MUST strip HTML tags before displaying
- Use the provided HtmlParser utility to clean the text

### 2. File Upload Format
- Use multipart/form-data for comments with files
- Include both text and file in the same request
- Support all file types (documents, images, etc.)

### 3. UI Requirements
- Show comments in chronological order (oldest first)
- Display author avatar, name, and timestamp
- Show file attachments with download option
- Include file picker for attaching files
- Support text input with mention functionality (@username)

### 4. Error Handling
- Handle network errors gracefully
- Show loading states during API calls
- Display appropriate error messages
- Validate file size limits

### 5. Real-time Updates
- Refresh comments after posting new ones
- Consider implementing pull-to-refresh
- Update comment list after edits/deletes

## FILES TO IMPLEMENT

### 1. API Methods (add to lib/services/api_service.dart)
```dart
// See mobile_comments_api_methods.dart for complete implementation
```

### 2. Comment Models (lib/models/comment.dart)
```dart
// See mobile_comments_implementation_guide.dart for complete models
```

### 3. Comments Widget (lib/widgets/comments_section.dart)
```dart
// See mobile_comments_implementation_guide.dart for complete widget
```

### 4. HTML Parser Utility (lib/utils/html_parser.dart)
```dart
// See mobile_comments_implementation_guide.dart for utility functions
```

## TESTING CHECKLIST
- [ ] Load and display existing comments
- [ ] Post text-only comments
- [ ] Post comments with file attachments
- [ ] Download comment attachments
- [ ] Edit own comments
- [ ] Delete own comments
- [ ] Handle HTML content in comment text
- [ ] Show proper loading states
- [ ] Handle error cases
- [ ] Test with different file types
- [ ] Verify mentions functionality

## INTEGRATION STEPS
1. Add the API methods to your existing ApiService
2. Create the Comment data models
3. Implement the CommentsSection widget
4. Add HTML parser utility
5. Integrate CommentsSection into your task detail screen
6. Add required dependencies to pubspec.yaml
7. Test all functionality thoroughly

## DEPENDENCIES TO ADD
```yaml
dependencies:
  file_picker: ^5.5.0
  image_picker: ^1.0.4
```

This implementation will provide a complete comments system that matches the web app functionality and properly handles file attachments and HTML content. 