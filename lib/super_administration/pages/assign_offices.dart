import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssignOffices extends StatefulWidget {
  const AssignOffices({super.key});

  @override
  State<AssignOffices> createState() => _AssignOfficesState();
}

class _AssignOfficesState extends State<AssignOffices> {
  final _supabase = Supabase.instance.client;

  // Data lists
  List<Map<String, dynamic>> _offices = [];
  List<Map<String, dynamic>> _admins = [];
  List<Map<String, dynamic>> _assignments = [];

  // Selected values
  Map<String, dynamic>? _selectedOffice;
  Map<String, dynamic>? _selectedAdmin;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String _selectedTab = 'Unassigned';

  // For editing
  String? _editingAssignmentId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([_fetchOffices(), _fetchAdmins(), _fetchAssignments()]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _handleErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchOffices() async {
    try {
      final response = await _supabase
          .from('offices')
          .select('*, colleges(name), departments(name)')
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 10));

      setState(() {
        _offices = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _fetchAdmins() async {
    try {
      final response = await _supabase
          .from('admins')
          .select()
          .eq('role', 'makerere_admin')
          .order('full_name', ascending: true)
          .timeout(const Duration(seconds: 10));

      setState(() {
        _admins = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _fetchAssignments() async {
    try {
      final response = await _supabase
          .from('office_assignments')
          .select('*, offices(*)')
          .order('assigned_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      setState(() {
        _assignments =
            _withAdminLookup(List<Map<String, dynamic>>.from(response));
      });
    } catch (e) {
      if (e is PostgrestException && e.code == '42P01') {
        _assignments = [];
      } else {
        rethrow;
      }
    }
  }

  List<Map<String, dynamic>> _withAdminLookup(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      if (row.containsKey('admins')) continue;
      final admin = _admins.firstWhere(
        (a) => a['id'] == row['admin_id'],
        orElse: () => <String, dynamic>{},
      );
      row['admins'] = admin;
    }
    return rows;
  }

  String _safeText(dynamic value) => value?.toString() ?? '';

  String _handleErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      if (error.code == '42P01') {
        return 'Required tables do not exist. Please run the SQL setup script.';
      }
      return 'Database error: ${error.message}';
    }
    return 'Error: $error';
  }

  Future<void> _assignOffice() async {
    if (_selectedOffice == null) {
      _showSnackBar('Please select an office', Colors.orange);
      return;
    }

    if (_selectedAdmin == null) {
      _showSnackBar('Please select an admin', Colors.orange);
      return;
    }

    // Check if office is already assigned
    final isAssigned = _assignments.any(
      (a) => a['office_id'] == _selectedOffice!['id'],
    );
    if (isAssigned) {
      _showSnackBar(
        'This office is already assigned to an admin',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('office_assignments')
          .insert({
            'office_id': _selectedOffice!['id'],
            'admin_id': _selectedAdmin!['id'],
            'assigned_at': DateTime.now().toIso8601String(),
          })
          .select('*, offices(*)')
          .timeout(const Duration(seconds: 10));

      setState(() {
        _assignments.insertAll(
          0,
          _withAdminLookup(List<Map<String, dynamic>>.from(response)),
        );
        _selectedOffice = null;
        _selectedAdmin = null;
        _isSaving = false;
      });

      _showSnackBar('Office assigned successfully!', Colors.green);
    } catch (e) {
      setState(() {
        _errorMessage = _handleErrorMessage(e);
        _isSaving = false;
      });
    }
  }

  Future<void> _reassignOffice(Map<String, dynamic> assignment) async {
    Map<String, dynamic>? selectedAdmin;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Reassign Office',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Office: ${assignment['offices']['name']}'),
                  const SizedBox(height: 16),
                  const Text('Select new admin:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: _admins.map((admin) {
                      return DropdownMenuItem(
                        value: admin,
                        child: Text(admin['full_name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedAdmin = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) return 'Please select an admin';
                      return null;
                    },
                  ),
                ],
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
                  ),
                  onPressed: () {
                    if (selectedAdmin != null) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text(
                    'Reassign',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && selectedAdmin != null) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        await _supabase
            .from('office_assignments')
            .update({
              'admin_id': selectedAdmin!['id'],
              'assigned_at': DateTime.now().toIso8601String(),
            })
            .eq('id', assignment['id'])
            .timeout(const Duration(seconds: 10));

        await _fetchAssignments();

        setState(() {
          _isSaving = false;
        });

        _showSnackBar('Office reassigned successfully!', Colors.green);
      } catch (e) {
        setState(() {
          _errorMessage = _handleErrorMessage(e);
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _unassignOffice(Map<String, dynamic> assignment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Remove Assignment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove admin "${assignment['admins']['full_name']}" from office "${assignment['offices']['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
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
            .from('office_assignments')
            .delete()
            .eq('id', assignment['id'])
            .timeout(const Duration(seconds: 10));

        setState(() {
          _assignments.removeWhere((a) => a['id'] == assignment['id']);
          _isSaving = false;
        });

        _showSnackBar('Assignment removed successfully!', Colors.green);
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

  List<Map<String, dynamic>> get _unassignedOffices {
    final assignedOfficeIds = _assignments.map((a) => a['office_id']).toSet();
    return _offices
        .where((office) => !assignedOfficeIds.contains(office['id']))
        .toList();
  }

  List<Map<String, dynamic>> get _assignedOffices {
    return _assignments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Assign Offices to Admins',
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
          // Assignment Form
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // Office Dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Office',
                    labelStyle: TextStyle(color: Colors.grey[600]),
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
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  value: _selectedOffice != null
                      ? _selectedOffice!['id'].toString()
                      : null,
                  hint: const Text(
                    'Choose an office',
                    style: TextStyle(fontSize: 14),
                  ),
                  isExpanded: true,
                  items: _unassignedOffices.map((office) {
                    return DropdownMenuItem<String>(
                      value: office['id'].toString(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            office['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (office['building'] != null &&
                              office['building'].isNotEmpty)
                            Text(
                              '${office['building']} • Room ${office['room_number'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedOffice = _unassignedOffices.firstWhere(
                        (office) => office['id'].toString() == value,
                      );
                    });
                  },
                  selectedItemBuilder: (BuildContext context) {
                    return _unassignedOffices.map<Widget>((office) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          office['name'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList();
                  },
                ),
                const SizedBox(height: 15),

                // Admin Dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Admin',
                    labelStyle: TextStyle(color: Colors.grey[600]),
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
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  value: _selectedAdmin != null
                      ? _selectedAdmin!['id'].toString()
                      : null,
                  hint: const Text(
                    'Choose an admin',
                    style: TextStyle(fontSize: 14),
                  ),
                  isExpanded: true,
                  items: _admins.map((admin) {
                    return DropdownMenuItem<String>(
                      value: admin['id'].toString(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            admin['full_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (admin['email'] != null)
                            Text(
                              admin['email'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAdmin = _admins.firstWhere(
                        (admin) => admin['id'].toString() == value,
                      );
                    });
                  },
                  selectedItemBuilder: (BuildContext context) {
                    return _admins.map<Widget>((admin) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          admin['full_name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList();
                  },
                ),
                const SizedBox(height: 15),

                // Assign Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _isSaving ? null : _assignOffice,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'ASSIGN OFFICE',
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

          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  _buildTab(
                    'Unassigned',
                    _unassignedOffices.length,
                    Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildTab('Assigned', _assignedOffices.length, Colors.green),
                ],
              ),
            ),
          ),

          // Lists
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  )
                : _selectedTab == 'Unassigned'
                    ? _buildUnassignedList()
                    : _buildAssignedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int count, Color color) {
    final isSelected = _selectedTab == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnassignedList() {
    if (_unassignedOffices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              'All offices are assigned!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All offices have been assigned to admins',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _unassignedOffices.length,
      itemBuilder: (context, index) {
        final office = _unassignedOffices[index];
        return _buildOfficeCard(office, isAssigned: false);
      },
    );
  }

  Widget _buildAssignedList() {
    if (_assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No assignments yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the form above to assign offices to admins',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _assignments.length,
      itemBuilder: (context, index) {
        final assignment = _assignments[index];
        return _buildAssignmentCard(assignment);
      },
    );
  }

  Widget _buildOfficeCard(
    Map<String, dynamic> office, {
    required bool isAssigned,
  }) {
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
            // Office Name
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      _getLevelColor(office['level']).withOpacity(0.2),
                  radius: 20,
                  child: Icon(
                    _getLevelIcon(office['level']),
                    color: _getLevelColor(office['level']),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    office['name'],
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

            // Office Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (office['building'] != null &&
                      office['building'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Building: ${office['building']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (office['room_number'] != null &&
                      office['room_number'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.meeting_room,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Room: ${office['room_number']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (office['colleges'] != null &&
                      office['colleges']['name'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.business,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'College: ${office['colleges']['name']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (office['departments'] != null &&
                      office['departments']['name'] != null)
                    Row(
                      children: [
                        Icon(Icons.account_tree,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Department: ${office['departments']['name']}',
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

            // Bottom Row - Level and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getLevelColor(office['level']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getLevelIcon(office['level']),
                        size: 16,
                        color: _getLevelColor(office['level']),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        office['level'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getLevelColor(office['level']),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Note: For unassigned offices, we don't show edit/delete buttons
                    // as they're managed from the main office management screen
                    Text(
                      'Unassigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
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

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final office = assignment['offices'];
    final admin = assignment['admins'];

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
            // Office Name
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      _getLevelColor(office['level']).withOpacity(0.2),
                  radius: 20,
                  child: Icon(
                    _getLevelIcon(office['level']),
                    color: _getLevelColor(office['level']),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    office['name'] ?? 'Unknown Office',
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

            // Office Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (office['building'] != null &&
                      office['building'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Building: ${office['building']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (office['room_number'] != null &&
                      office['room_number'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.meeting_room,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Room: ${office['room_number']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (office['colleges'] != null &&
                      office['colleges']['name'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.business,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'College: ${office['colleges']['name']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (office['departments'] != null &&
                      office['departments']['name'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.account_tree,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Department: ${office['departments']['name']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 16),
                  // Admin Info
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Assigned to: ${_safeText(admin['full_name'])}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (admin['email'] != null && admin['email'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.email, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              admin['email'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Assigned: ${_formatDate(assignment['assigned_at'])}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bottom Row - Level and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getLevelColor(office['level']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getLevelIcon(office['level']),
                        size: 16,
                        color: _getLevelColor(office['level']),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        office['level'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getLevelColor(office['level']),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.orange),
                      onPressed:
                          _isSaving ? null : () => _reassignOffice(assignment),
                      tooltip: 'Reassign',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed:
                          _isSaving ? null : () => _unassignOffice(assignment),
                      tooltip: 'Remove Assignment',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

  Color _getLevelColor(String? level) {
    switch (level) {
      case 'Top Level':
        return Colors.purple;
      case 'College Level':
        return Colors.blue;
      case 'Department Level':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getLevelIcon(String? level) {
    switch (level) {
      case 'Top Level':
        return Icons.star;
      case 'College Level':
        return Icons.business;
      case 'Department Level':
        return Icons.category;
      default:
        return Icons.location_city;
    }
  }

  String _formatDate(String? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateTime.split('T')[0];
    }
  }
}
