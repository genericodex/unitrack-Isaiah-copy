import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddIssuesCategory extends StatefulWidget {
  const AddIssuesCategory({super.key});

  @override
  State<AddIssuesCategory> createState() => _AddIssuesCategoryState();
}

class _AddIssuesCategoryState extends State<AddIssuesCategory> {
  final _formKey = GlobalKey<FormState>();
  final _categoryNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _priorities = [];

  String? _selectedPriorityId;
  String? _selectedPriorityName;
  int? _selectedPriorityDays;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  String? _editingId;
  final _editCategoryNameController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  String? _editSelectedPriorityId;
  String? _editSelectedPriorityName;
  int? _editSelectedPriorityDays;

  @override
  void initState() {
    super.initState();
    _fetchPriorities();
    _fetchCategories();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    _descriptionController.dispose();
    _editCategoryNameController.dispose();
    _editDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchPriorities() async {
    try {
      final response = await _supabase
          .from('issue_priorities')
          .select()
          .order('days_to_resolve', ascending: true)
          .timeout(const Duration(seconds: 10));

      setState(() {
        _priorities = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {}
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('issue_categories')
          .select('*, issue_priorities(name, days_to_resolve)')
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 10));

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _handleErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String _handleErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      if (error.code == '42P01') {
        return 'Table "issue_categories" does not exist. Please create it in Supabase.';
      }
      return 'Database error: ${error.message}';
    }
    return 'Error: $error';
  }

  Future<void> _addCategory() async {
    if (_selectedPriorityId == null) {
      _showSnackBar('Please select a priority level', Colors.orange);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('issue_categories')
          .insert({
            'name': _categoryNameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'priority_id': int.parse(_selectedPriorityId!),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('*, issue_priorities(name, days_to_resolve)')
          .timeout(const Duration(seconds: 10));

      setState(() {
        _categories.insert(0, Map<String, dynamic>.from(response[0]));
        _categoryNameController.clear();
        _descriptionController.clear();
        _selectedPriorityId = null;
        _selectedPriorityName = null;
        _selectedPriorityDays = null;
        _isSaving = false;
      });

      _showSnackBar('Category added successfully!', Colors.green);
    } catch (e) {
      setState(() {
        _errorMessage = _handleErrorMessage(e);
        _isSaving = false;
      });
    }
  }

  Future<void> _updateCategory(
    String id,
    String oldName,
    String oldDescription,
    int oldPriorityId,
  ) async {
    _editCategoryNameController.text = oldName;
    _editDescriptionController.text = oldDescription;
    _editSelectedPriorityId = oldPriorityId.toString();

    final selectedPriority = _priorities.firstWhere(
      (p) => p['id'] == oldPriorityId,
      orElse: () => {},
    );
    _editSelectedPriorityName = selectedPriority['name'];
    _editSelectedPriorityDays = selectedPriority['days_to_resolve'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text(
              'Edit Category',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _editCategoryNameController,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _editDescriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Priority Level',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                    ),
                    value: _editSelectedPriorityId,
                    hint: const Text('Select priority'),
                    items: _priorities.map((priority) {
                      return DropdownMenuItem<String>(
                        value: priority['id'].toString(),
                        child: Text(
                          priority['name'],
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        _editSelectedPriorityId = value;
                        final selected = _priorities.firstWhere(
                          (p) => p['id'].toString() == value,
                        );
                        _editSelectedPriorityName = selected['name'];
                        _editSelectedPriorityDays = selected['days_to_resolve'];
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      final newName = _editCategoryNameController.text.trim();
      final newDescription = _editDescriptionController.text.trim();
      final newPriorityId = int.parse(_editSelectedPriorityId!);

      if (newName.isNotEmpty &&
          (newName != oldName ||
              newDescription != oldDescription ||
              newPriorityId != oldPriorityId)) {
        setState(() {
          _isSaving = true;
          _errorMessage = null;
        });

        try {
          final updates = <String, dynamic>{};
          if (newName != oldName) updates['name'] = newName;
          if (newDescription != oldDescription)
            updates['description'] = newDescription;
          if (newPriorityId != oldPriorityId)
            updates['priority_id'] = newPriorityId;

          final response = await _supabase
              .from('issue_categories')
              .update(updates)
              .eq('id', id)
              .select('*, issue_priorities(name, days_to_resolve)')
              .timeout(const Duration(seconds: 10));

          setState(() {
            final index = _categories.indexWhere((cat) => cat['id'] == id);
            if (index != -1) {
              _categories[index] = Map<String, dynamic>.from(response[0]);
            }
            _isSaving = false;
          });

          _showSnackBar('Category updated successfully!', Colors.green);
        } catch (e) {
          setState(() {
            _errorMessage = _handleErrorMessage(e);
            _isSaving = false;
          });
        }
      }
    }
  }

  Future<void> _deleteCategory(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        await _supabase
            .from('issue_categories')
            .delete()
            .eq('id', id)
            .timeout(const Duration(seconds: 10));

        setState(() {
          _categories.removeWhere((cat) => cat['id'] == id);
          _isSaving = false;
        });

        _showSnackBar('Category deleted successfully!', Colors.green);
      } catch (e) {
        setState(() {
          _errorMessage = _handleErrorMessage(e);
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getPriorityColor(String priorityName) {
    switch (priorityName.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.deepOrange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    final priority = category['issue_priorities'];
    final priorityName = priority != null ? priority['name'] : 'Not set';
    final priorityDays = priority != null ? priority['days_to_resolve'] : 0;
    final priorityColor = _getPriorityColor(priorityName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[100]!,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Name with Icon
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: priorityColor.withOpacity(0.2),
                  radius: 20,
                  child: Icon(
                    Icons.category,
                    color: priorityColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.description,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category['description'] ?? 'No description',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Priority
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.priority_high,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Priority: $priorityName',
                            style: TextStyle(
                              fontSize: 14,
                              color: priorityColor,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Resolution Time
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Resolution Time: $priorityDays days',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bottom Row - Priority Badge and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Priority Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.priority_high,
                        size: 16,
                        color: priorityColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        priorityName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                      onPressed: _isSaving
                          ? null
                          : () => _updateCategory(
                                category['id'].toString(),
                                category['name'],
                                category['description'] ?? '',
                                category['priority_id'],
                              ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 24,
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _isSaving
                          ? null
                          : () => _deleteCategory(
                                category['id'].toString(),
                                category['name'],
                              ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 24,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Manage Issue Categories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Error Message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red[50],
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.red),
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
                ],
              ),
            ),

          // Main Content - Single ScrollView with Form and Categories
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        // Add Category Form
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Category Name Field
                                TextFormField(
                                  controller: _categoryNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Category Name',
                                    hintText:
                                        'e.g., Network Issue, Hardware Problem, Software Bug',
                                    labelStyle:
                                        TextStyle(color: Colors.grey[600]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(
                                        color: Colors.green,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter category name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),

                                // Description Field
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: InputDecoration(
                                    labelText: 'Description',
                                    hintText:
                                        'Describe what this category covers',
                                    labelStyle:
                                        TextStyle(color: Colors.grey[600]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(
                                        color: Colors.green,
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                  ),
                                  maxLines: 3,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter description';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),

                                // Priority Dropdown
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Priority Level',
                                    labelStyle:
                                        TextStyle(color: Colors.grey[600]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(
                                        color: Colors.green,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 12,
                                    ),
                                  ),
                                  value: _selectedPriorityId,
                                  hint: const Text('Select priority level'),
                                  items: _priorities.map((priority) {
                                    return DropdownMenuItem<String>(
                                      value: priority['id'].toString(),
                                      child: Text(
                                        priority['name'],
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPriorityId = value;
                                      final selected = _priorities.firstWhere(
                                        (p) => p['id'].toString() == value,
                                      );
                                      _selectedPriorityName = selected['name'];
                                      _selectedPriorityDays =
                                          selected['days_to_resolve'];
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select a priority level';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),

                                // Add Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    onPressed: _isSaving ? null : _addCategory,
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Text(
                                            'ADD CATEGORY',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Categories List
                        if (_categories.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.category_outlined,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Categories Added',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add categories to classify different types of issues',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              children: _categories
                                  .asMap()
                                  .entries
                                  .map((entry) => _buildCategoryCard(
                                      entry.value, entry.key))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
