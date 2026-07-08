import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';
import '../widgets/icon_tile.dart';
import '../widgets/section_header.dart';
import 'admin_management_page.dart';
import 'audit_log_page.dart';
import 'import_students_page.dart';
import 'login_page.dart';

// AdminPortalPage is the main admin area.
// It listens to Firestore groups in real time, then shows the group dashboard,
// the register/import student pages, and (for owners) the admin manager.
class AdminPortalPage extends StatefulWidget {
  const AdminPortalPage({super.key, this.role = AdminRole.admin});

  // The signed-in admin's role. Owners additionally see the Admins page.
  final AdminRole role;

  @override
  State<AdminPortalPage> createState() => _AdminPortalPageState();
}

class _AdminPortalPageState extends State<AdminPortalPage> {
  final _repo = AdminRepository();
  int selectedPage = 0;

  @override
  Widget build(BuildContext context) {
    // Desktop/tablet shows the sidebar. Phones use a drawer opened by menu.
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: isWide ? null : Drawer(child: buildSidebarContent()),
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

          return Row(
            children: [
              if (isWide) buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    buildHeader(showMenuButton: !isWide),
                    Expanded(
                      child: selectedPage == 0
                          ? buildDashboard(groups)
                          : selectedPage == 1
                          ? buildRegisterStudent(groups)
                          : selectedPage == 2
                          ? ImportStudentsPage(repo: _repo, groups: groups)
                          : selectedPage == 3 &&
                                widget.role == AdminRole.owner
                          ? AdminManagementPage(
                              repo: _repo,
                              currentEmail:
                                  FirebaseAuth.instance.currentUser?.email ?? '',
                            )
                          : selectedPage == 4 &&
                                widget.role == AdminRole.owner
                          ? AuditLogPage(repo: _repo)
                          : buildDashboard(groups),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildSidebar() {
    return Container(
      width: 250,
      color: AppColors.primary,
      child: buildSidebarContent(),
    );
  }

  Widget buildSidebarContent() {
    // Kept as a separate widget so the same menu can be used
    // in the desktop sidebar and the mobile drawer.
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.school, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APPSTONE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Admin Portal',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            navButton(0, Icons.dashboard, 'Dashboard'),
            navButton(1, Icons.person_add, 'Register Student'),
            navButton(2, Icons.upload_file, 'Import Students'),
            if (widget.role == AdminRole.owner)
              navButton(3, Icons.admin_panel_settings, 'Admins'),
            if (widget.role == AdminRole.owner)
              navButton(4, Icons.history, 'Audit Log'),
            const Spacer(),
            navButton(-1, Icons.logout, 'Logout'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget navButton(int index, IconData icon, String label) {
    final selected = selectedPage == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        selected: selected,
        selectedTileColor: Colors.white24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: Colors.white),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () {
          if (index == -1) {
            logout();
          } else {
            setState(() => selectedPage = index);
            if (Navigator.canPop(context)) Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget buildHeader({required bool showMenuButton}) {
    // Header text changes depending on the selected admin page.
    final title = selectedPage == 0
        ? 'Capstone Groups Overview'
        : selectedPage == 1
        ? 'Register New Student'
        : selectedPage == 2
        ? 'Import Students'
        : selectedPage == 3
        ? 'Manage Admins'
        : 'Audit Log';

    final subtitle = selectedPage == 0
        ? 'Manage student groups and monitor premium feature subscriptions'
        : selectedPage == 1
        ? 'Add a student to a capstone group and generate credentials'
        : selectedPage == 2
        ? 'Add many students at once from an Excel or CSV roster'
        : selectedPage == 3
        ? 'Invite admins and control who has access'
        : 'Review a history of admin actions';

    return SectionHeader(
      title: title,
      subtitle: subtitle,
      leading: showMenuButton
          ? Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget buildDashboard(List<CapstoneGroup> groups) {
    // Summary values are calculated from the Firestore group list.
    final totalStudents = groups.fold<int>(
      0,
      (sum, group) => sum + group.students.length,
    );
    final premiumGroups = groups.where((group) => group.isPremium).length;
    // Students who used "Forgot password" and are waiting for a reset.
    final pendingResets = groups
        .expand((group) => group.students)
        .where((student) => student.resetRequested)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final pagePadding = isWide ? 32.0 : 16.0;
        final availableWidth = constraints.maxWidth - (pagePadding * 2);
        final statWidth = isWide ? (availableWidth - 40) / 3 : availableWidth;

        return ListView(
          padding: EdgeInsets.all(pagePadding),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: createGroup,
                icon: const Icon(Icons.add),
                label: const Text('Create New Group'),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              children: [
                statCard(
                  'Total Groups',
                  groups.length.toString(),
                  Icons.groups,
                  AppColors.primary,
                  statWidth,
                ),
                statCard(
                  'Total Students',
                  totalStudents.toString(),
                  Icons.person_add,
                  AppColors.gold,
                  statWidth,
                ),
                statCard(
                  'Premium Groups',
                  premiumGroups.toString(),
                  Icons.workspace_premium,
                  AppColors.primaryDark,
                  statWidth,
                ),
              ],
            ),
            if (pendingResets > 0) ...[
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.notification_important,
                    color: Colors.red,
                  ),
                  title: Text(
                    '$pendingResets password reset '
                    '${pendingResets == 1 ? 'request' : 'requests'} pending',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Look for the red bell next to a student, then use Reset '
                    'password to generate a new temporary password.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            if (groups.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No groups yet. Click Create New Group first.'),
                ),
              ),
            for (final group in groups) buildGroupCard(group, groups),
          ],
        );
      },
    );
  }

  Widget statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    // The parent calculates width so the cards fill the row on desktop
    // and become full-width blocks on mobile. Same white card + icon-badge
    // language as the student dashboard's feature cards.
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconBadge(icon: icon, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildGroupCard(CapstoneGroup group, List<CapstoneGroup> groups) {
    // One card per capstone group.
    // The DataTable is horizontally scrollable so it still works on mobile.
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wideHeader = constraints.maxWidth >= 650;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rename group',
                        onPressed: () => renameGroup(group),
                        icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Chip(
                        label: Text(group.isPremium ? 'Premium' : 'Free Plan'),
                        backgroundColor: group.isPremium
                            ? AppColors.gold
                            : AppColors.grey,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${group.students.length} of 5 members - ${5 - group.students.length} spots available',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              );

              // Premium is one-way: once granted there is no revoke button, only the chip above.
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!group.isPremium)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => grantPremium(group),
                      child: const Text('Grant Premium'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete group',
                    onPressed: () => deleteGroup(group),
                    icon: const Icon(Icons.delete, color: Colors.white),
                  ),
                ],
              );

              return Container(
                width: double.infinity,
                color: AppColors.primary,
                padding: const EdgeInsets.all(20),
                child: wideHeader
                    ? Row(
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 16),
                          actions,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          details,
                          const SizedBox(height: 14),
                          actions,
                        ],
                      ),
              );
            },
          ),
          if (group.students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No students in this group yet.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Student Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Student ID')),
                        DataColumn(label: Text('Temp Password')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final student in group.students)
                          DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Notification icon on the exact student
                                    // who asked for a password reset, so the
                                    // admin can spot them at a glance.
                                    if (student.resetRequested) ...[
                                      const Tooltip(
                                        message: 'Password reset requested',
                                        child: Icon(
                                          Icons.notification_important,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(student.name),
                                  ],
                                ),
                              ),
                              DataCell(Text(student.email)),
                              DataCell(Text(student.studentId)),
                              // Only the admin-generated temp password is shown.
                              // If a student changed their own password it is
                              // never surfaced here - only in [password].
                              DataCell(SelectableText(student.tempPassword)),
                              DataCell(
                                student.mustChangePassword
                                    ? statusChip(
                                        'Temp not changed',
                                        AppColors.gold,
                                      )
                                    : statusChip(
                                        'Student set own',
                                        Colors.green,
                                      ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit student',
                                      onPressed: () =>
                                          editStudent(group, student, groups),
                                      icon: const Icon(
                                        Icons.edit,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Reset password',
                                      onPressed: () =>
                                          resetStudentPassword(group, student),
                                      icon: const Icon(
                                        Icons.lock_reset,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete student',
                                      onPressed: () =>
                                          deleteStudent(group, student),
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget buildRegisterStudent(List<CapstoneGroup> groups) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: RegisterStudentForm(
                groups: groups,
                onRegister: registerStudent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> createGroup() async {
    // Dialog returns the typed group name, then Firestore creates the group.
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Capstone Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Capstone Group 3',
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
            child: const Text('Create Group'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    await runAction(() => _repo.createGroup(name), 'Group created.');
  }

  Future<void> registerStudent(StudentDraft draft) async {
    await runAction(() async {
      final student = await _repo.registerStudent(draft);
      showMessage(
        'Created ${student.name}: ${student.studentId} / ${student.password}',
      );
    }, null);
  }

  Future<void> grantPremium(CapstoneGroup group) async {
    // Premium has no revoke path, so granting it deserves a confirmation.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant Premium'),
        content: Text(
          'Grant Premium to "${group.name}"? This unlocks the premium '
          'features for all its members and cannot be reverted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant Premium'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await runAction(() => _repo.grantPremium(group), 'Premium granted.');
  }

  Future<void> renameGroup(CapstoneGroup group) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == group.name) return;

    await runAction(
      () => _repo.renameGroup(groupId: group.id, newName: name),
      'Group renamed.',
    );
  }

  // Lets an admin fix a typo in a student's name, or move them into a
  // different group entirely (e.g. they were registered into the wrong one).
  Future<void> editStudent(
    CapstoneGroup group,
    StudentAccount student,
    List<CapstoneGroup> groups,
  ) async {
    final nameController = TextEditingController(text: student.name);
    var targetGroupId = group.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: targetGroupId,
                decoration: const InputDecoration(
                  labelText: 'Group',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final g in groups)
                    DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: (value) =>
                    setState(() => targetGroupId = value ?? targetGroupId),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    final newName = nameController.text;
    nameController.dispose();
    if (confirmed != true) return;

    await runAction(
      () => _repo.editStudent(
        fromGroup: group,
        student: student,
        newName: newName,
        newGroupId: targetGroupId,
      ),
      'Student updated.',
    );
  }

  Future<void> deleteGroup(CapstoneGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Delete "${group.name}" and all ${group.students.length} student accounts in it? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await runAction(() => _repo.deleteGroup(group.id), 'Group deleted.');
  }

  Future<void> deleteStudent(
    CapstoneGroup group,
    StudentAccount student,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Delete ${student.name} (${student.studentId}) from '
          '"${group.name}"? They will no longer be able to log in. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await runAction(
      () => _repo.deleteStudent(group: group, student: student),
      'Student deleted.',
    );
  }

  Future<void> resetStudentPassword(
    CapstoneGroup group,
    StudentAccount student,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Student Password'),
        content: Text('Generate a new temporary password for ${student.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final newPassword = await _repo.resetStudentPassword(
        group: group,
        student: student,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New Temporary Password'),
          content: SelectableText('${student.name}: $newPassword'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      showMessage(error.toString());
    }
  }

  Future<void> logout() async {
    await _repo.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> runAction(
    Future<void> Function() action,
    String? success,
  ) async {
    try {
      await action();
      if (success != null) showMessage(success);
    } catch (error) {
      showMessage(error.toString());
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class RegisterStudentForm extends StatefulWidget {
  // Separate form widget so the parent admin page handles Firebase actions,
  // while this widget only handles text fields and validation.
  const RegisterStudentForm({
    super.key,
    required this.groups,
    required this.onRegister,
  });

  final List<CapstoneGroup> groups;
  final ValueChanged<StudentDraft> onRegister;

  @override
  State<RegisterStudentForm> createState() => _RegisterStudentFormState();
}

class _RegisterStudentFormState extends State<RegisterStudentForm> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  String? groupId;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Enter student name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'student@university.edu',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: groupId,
          decoration: const InputDecoration(
            hintText: 'Assign to Group',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final group in widget.groups)
              DropdownMenuItem(value: group.id, child: Text(group.name)),
          ],
          onChanged: (value) => setState(() => groupId = value),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'A unique Student ID and temporary password will be automatically generated upon registration.',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: submit,
          icon: const Icon(Icons.person_add),
          label: const Text('Register Student'),
        ),
      ],
    );
  }

  void submit() {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all fields first.')),
      );
      return;
    }

    widget.onRegister(
      StudentDraft(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        groupId: groupId!,
      ),
    );

    nameController.clear();
    emailController.clear();
  }
}
