import 'package:appstone/screens/login_page.dart';
import 'package:appstone/services/admin_repository.dart';
import 'package:flutter/material.dart';

class AdminPortalPage extends StatefulWidget {
  const AdminPortalPage({super.key});

  @override
  State<AdminPortalPage> createState() => _AdminPortalPageState();
}

class _AdminPortalPageState extends State<AdminPortalPage> {
  final _repo = AdminRepository();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        title: const Text('AppStone Admin'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<CapstoneGroup>>(
        stream: _repo.groupsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Firebase error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data!;
          return Column(
            children: [
              NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (index) => setState(() => _tab = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard),
                    label: 'Groups',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_add),
                    label: 'Register',
                  ),
                ],
              ),
              Expanded(
                child: _tab == 0
                    ? GroupsTab(
                        groups: groups,
                        onCreateGroup: _createGroup,
                        onTogglePremium: _togglePremium,
                        onDeleteStudent: _deleteStudent,
                      )
                    : RegisterStudentTab(
                        groups: groups,
                        onRegister: _registerStudent,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Group name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    await _run(() => _repo.createGroup(name), 'Group created.');
  }

  Future<void> _registerStudent(StudentDraft draft) async {
    await _run(() async {
      final student = await _repo.registerStudent(draft);
      _showMessage(
        'Created ${student.name}: ${student.studentId} / ${student.password}',
      );
    }, null);
  }

  Future<void> _togglePremium(CapstoneGroup group) async {
    await _run(() => _repo.togglePremium(group), 'Premium updated.');
  }

  Future<void> _deleteStudent(
    CapstoneGroup group,
    StudentAccount student,
  ) async {
    await _run(
      () => _repo.deleteStudent(group: group, student: student),
      'Student deleted.',
    );
  }

  Future<void> _logout() async {
    await _repo.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _run(Future<void> Function() action, String? success) async {
    try {
      await action();
      if (success != null) _showMessage(success);
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class GroupsTab extends StatelessWidget {
  const GroupsTab({
    super.key,
    required this.groups,
    required this.onCreateGroup,
    required this.onTogglePremium,
    required this.onDeleteStudent,
  });

  final List<CapstoneGroup> groups;
  final VoidCallback onCreateGroup;
  final ValueChanged<CapstoneGroup> onTogglePremium;
  final void Function(CapstoneGroup group, StudentAccount student)
  onDeleteStudent;

  @override
  Widget build(BuildContext context) {
    final studentCount = groups.fold<int>(
      0,
      (total, group) => total + group.students.length,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: onCreateGroup,
          icon: const Icon(Icons.add),
          label: const Text('Create Group'),
        ),
        const SizedBox(height: 16),
        Text('Groups: ${groups.length}'),
        Text('Students: $studentCount'),
        const SizedBox(height: 16),
        if (groups.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No groups yet. Create one first.'),
            ),
          ),
        for (final group in groups)
          Card(
            child: ExpansionTile(
              title: Text(group.name),
              subtitle: Text(
                '${group.students.length}/5 members - ${group.isPremium ? 'Premium' : 'Free'}',
              ),
              trailing: IconButton(
                tooltip: 'Toggle premium',
                onPressed: () => onTogglePremium(group),
                icon: Icon(
                  group.isPremium ? Icons.star : Icons.star_border,
                  color: AppColors.gold,
                ),
              ),
              children: [
                if (group.students.isEmpty)
                  const ListTile(title: Text('No students yet.')),
                for (final student in group.students)
                  ListTile(
                    title: Text(student.name),
                    subtitle: Text(
                      '${student.email}\n${student.studentId} / ${student.password}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      onPressed: () => onDeleteStudent(group, student),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class RegisterStudentTab extends StatefulWidget {
  const RegisterStudentTab({
    super.key,
    required this.groups,
    required this.onRegister,
  });

  final List<CapstoneGroup> groups;
  final ValueChanged<StudentDraft> onRegister;

  @override
  State<RegisterStudentTab> createState() => _RegisterStudentTabState();
}

class _RegisterStudentTabState extends State<RegisterStudentTab> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _groupId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Student name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Student email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _groupId,
          decoration: const InputDecoration(
            labelText: 'Assign to group',
            border: OutlineInputBorder(),
          ),
          items: widget.groups
              .map(
                (group) =>
                    DropdownMenuItem(value: group.id, child: Text(group.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => _groupId = value),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: _submit,
          icon: const Icon(Icons.person_add),
          label: const Text('Register Student'),
        ),
      ],
    );
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all fields first.')),
      );
      return;
    }

    widget.onRegister(
      StudentDraft(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        groupId: _groupId!,
      ),
    );

    _nameController.clear();
    _emailController.clear();
  }
}
