import 'package:flutter/material.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  String? _selectedStatus = 'Pending';
  String? _selectedAssignee;
  String? _selectedPriority = 'None';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Task',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Implement task creation
              Navigator.pop(context);
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                          DropdownMenuItem(value: 'Done', child: Text('Done')),
                        ],
                        onChanged: (value) => setState(() => _selectedStatus = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expiry Date'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            '${_expiryDate.day}/${_expiryDate.month}/${_expiryDate.year}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assignee'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedAssignee,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'oussama', child: Text('Oussama Tahmaz')),
                          DropdownMenuItem(value: 'nabih', child: Text('Nabih Darwich')),
                          DropdownMenuItem(value: 'hassan', child: Text('Hassan Bassam')),
                          DropdownMenuItem(value: 'hatoum', child: Text('Hassan Hatoum')),
                        ],
                        onChanged: (value) => setState(() => _selectedAssignee = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Priority'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'None', child: Text('None')),
                          DropdownMenuItem(value: 'Low', child: Text('Low')),
                          DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'High', child: Text('High')),
                        ],
                        onChanged: (value) => setState(() => _selectedPriority = value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        DropdownButton<String>(
                          value: 'Normal',
                          items: const [
                            DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'H1', child: Text('Heading 1')),
                            DropdownMenuItem(value: 'H2', child: Text('Heading 2')),
                          ],
                          onChanged: (value) {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_bold),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_italic),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_underline),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.link),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_list_bulleted),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_list_numbered),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  TextField(
                    maxLines: 10,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 