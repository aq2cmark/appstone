import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_breakpoints.dart';
import '../services/admin_repository.dart';
import '../services/credentials_printer.dart';
import '../services/functions_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/states/app_states.dart';
import '../widgets/states/skeleton.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/credential_value.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/icon_tile.dart';
import 'admin_management_page.dart';
import 'audit_log_page.dart';
import 'import_students_page.dart';
import 'login_page.dart';
import 'print_options_dialog.dart';

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

  final _searchController = TextEditingController();
  String _query = '';

  /// Group ids whose student list is hidden. Empty by default - groups start
  /// expanded so nothing is hidden from an admin used to the old layout; a
  /// long roster can then be collapsed to make the list scannable.
  final Set<String> _collapsedGroups = <String>{};

  /// The group whose card should flash success, and a counter so the same
  /// group pulsing twice still animates the second time.
  String? _pulsedGroupId;
  int _pulseTick = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Groups matching the current search.
  ///
  /// A group matches on its own name, or on any of its students' name, email
  /// or Student ID - so an admin looking for one student finds the group that
  /// student is in, which is where every action on them lives.
  List<CapstoneGroup> _matchingGroups(List<CapstoneGroup> groups) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return groups;

    return groups.where((group) {
      if (group.name.toLowerCase().contains(q)) return true;
      return group.students.any(
        (student) =>
            student.name.toLowerCase().contains(q) ||
            student.email.toLowerCase().contains(q) ||
            student.studentId.toLowerCase().contains(q),
      );
    }).toList();
  }

  Widget _buildSearchField() {
    final colors = AppColors.of(context);

    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search groups and students by name, email or Student ID',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: colors.surface,
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Desktop/tablet shows the sidebar. Phones use a drawer opened by menu.
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
            drawer: isWide ? null : Drawer(child: buildSidebarContent()),
      body: StreamBuilder<List<CapstoneGroup>>(
        stream: _repo.groupsStream(),
        builder: (context, snapshot) {
          // Raw exception text used to be printed straight to the admin here.
          // AppErrorView maps it to plain English and offers a retry, which
          // for a live stream means re-subscribing by rebuilding this page.
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: AppColors.of(context).background,
              body: AppErrorView(
                error: snapshot.error,
                title: 'Could not load your groups',
                onRetry: () => setState(() {}),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const _AdminLoading();
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
    final colors = AppColors.of(context);
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.divider)),
      ),
      child: buildSidebarContent(),
    );
  }

  /// The admin menu, shared by the desktop sidebar and the phone drawer.
  ///
  /// This used to be a solid slab of `colors.brand` with hardcoded white
  /// labels. That failed WCAG AA in dark mode - the dark palette's brand is a
  /// light salmon, so white-on-it measured 3.55:1 - and it also fought the
  /// neutral app chrome introduced everywhere else. It is now a surface panel
  /// with the admin accent reserved for the active item, which reads as
  /// "staff side" without shouting.
  Widget buildSidebarContent() {
    final colors = AppColors.of(context);

    return Container(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.admin,
                      borderRadius: AppRadius.smAll,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.school_rounded,
                      size: 20,
                      color: colors.onColor,
                    ),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appstone',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Admin Portal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.admin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.divider),
            AppSpacing.vSm,
            navButton(0, Icons.dashboard_rounded, 'Dashboard'),
            navButton(1, Icons.person_add_rounded, 'Register Student'),
            navButton(2, Icons.upload_file_rounded, 'Import Students'),
            if (widget.role == AdminRole.owner)
              navButton(3, Icons.admin_panel_settings_rounded, 'Admins'),
            if (widget.role == AdminRole.owner)
              navButton(4, Icons.history_rounded, 'Audit Log'),
            const Spacer(),
            Divider(height: 1, color: colors.divider),
            AppSpacing.vSm,
            navButton(-1, Icons.logout_rounded, 'Logout'),
            AppSpacing.vMd,
          ],
        ),
      ),
    );
  }

  Widget navButton(int index, IconData icon, String label) {
    final colors = AppColors.of(context);
    final selected = selectedPage == index;
    // Logout is the one destructive-ish entry; it reads in the danger tone so
    // it is never mistaken for a page while scanning the list.
    final isLogout = index == -1;
    final tone = isLogout ? colors.danger : colors.admin;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      child: ListTile(
        selected: selected,
        selectedTileColor: colors.adminSoft,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        leading: Icon(
          icon,
          size: AppSize.iconSm,
          color: selected ? tone : (isLogout ? tone : colors.textSecondary),
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelLarge.copyWith(
            color: selected
                ? tone
                : (isLogout ? tone : colors.textPrimary),
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

    final colors = AppColors.of(context);

    // A neutral header with an admin-accent hair line, matching the chrome the
    // student screens use. The previous full-bleed maroon banner is what made
    // the portal look like it predated the overhaul.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                showMenuButton ? AppSpacing.sm : context.pagePadding,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  if (showMenuButton)
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: 'Menu',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        icon: const Icon(Icons.menu_rounded),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineSmall.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.hSm,
                  const ThemeToggleButton(),
                ],
              ),
            ),
          ),
          Container(height: 3, color: colors.admin.withValues(alpha: 0.85)),
        ],
      ),
    );
  }

  Widget buildDashboard(List<CapstoneGroup> groups) {
    final colors = AppColors.of(context);
    // Summary values are calculated from the Firestore group list.
    final totalStudents = groups.fold<int>(
      0,
      (sum, group) => sum + group.students.length,
    );
    final premiumGroups = groups.where((group) => group.isPremium).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final pagePadding = isWide ? 32.0 : 16.0;
        // Capped so the dashboard does not stretch edge to edge on a 1920px
        // monitor the way it used to - the student screens already do this.
        final contentWidth = constraints.maxWidth > AppContentWidth.max
            ? AppContentWidth.max
            : constraints.maxWidth;
        final availableWidth = contentWidth - (pagePadding * 2);
        final statWidth = isWide ? (availableWidth - 40) / 3 : availableWidth;

        return _CenteredMax(
          maxWidth: AppContentWidth.max,
          child: ListView(
          padding: EdgeInsets.all(pagePadding),
          // Coarse stagger: the action row, the stat row, the search field,
          // then the whole group list as one step. Animating each group card
          // would replay a growing delay chain every time the search changes.
          children: StaggeredEntrance.list(<Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.brand,
                  ),
                  onPressed: createGroup,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create New Group'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _printCredentials(groups),
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Print Credentials'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              children: [
                statCard(
                  'Total Groups',
                  groups.length,
                  Icons.groups_rounded,
                  colors.brand,
                  statWidth,
                ),
                statCard(
                  'Total Students',
                  totalStudents,
                  Icons.person_add_rounded,
                  colors.premium,
                  statWidth,
                ),
                statCard(
                  'Premium Groups',
                  premiumGroups,
                  Icons.workspace_premium_rounded,
                  colors.brandStrong,
                  statWidth,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSearchField(),
            const SizedBox(height: 20),
            if (groups.isEmpty)
              AppEmptyView(
                icon: Icons.groups_rounded,
                accent: colors.admin,
                title: 'No capstone groups yet',
                body: 'Create a group first, then register or import the '
                    'students who belong to it. Each group holds up to five '
                    'members.',
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: colors.admin),
                  onPressed: createGroup,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create the first group'),
                ),
              )
            else if (_matchingGroups(groups).isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No group or student matches "${_query.trim()}".',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
              ),
            // The stat cards above deliberately keep counting the *whole*
            // roster while a search is active - they are a summary of the
            // department, not of the current filter.
            Column(
              children: [
                for (final group in _matchingGroups(groups))
                  buildGroupCard(group, groups),
              ],
            ),
          ]),
          ),
        );
      },
    );
  }

  Widget statCard(
    String label,
    int value,
    IconData icon,
    Color color,
    double width,
  ) {
    final colors = AppColors.of(context);
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
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    // Counts up rather than appearing, matching the student
                    // side's score dials and progress figures.
                    CountUpText(
                      value: value,
                      style: AppTypography.displayMedium.copyWith(
                        color: colors.textPrimary,
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
    final colors = AppColors.of(context);
    final collapsed = _collapsedGroups.contains(group.id);
    final pulse = _pulsedGroupId == group.id ? _pulseTick : 0;
    // One card per capstone group.
    // The DataTable is horizontally scrollable so it still works on mobile.
    return SuccessPulse(
      trigger: pulse,
      child: Card(
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
                        style: AppTypography.titleLarge.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rename group',
                        onPressed: () => renameGroup(group),
                        icon: Icon(
                          Icons.edit_rounded,
                          color: colors.textSecondary,
                          size: 18,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Chip(
                        label: Text(group.isPremium ? 'Premium' : 'Free Plan'),
                        backgroundColor: group.isPremium
                            ? colors.premium
                            : colors.surfaceSunken,
                        labelStyle: TextStyle(
                          color: group.isPremium
                              ? colors.onColor
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${group.students.length} of 5 members - ${5 - group.students.length} spots available',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
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
                        backgroundColor: colors.premium,
                        foregroundColor: colors.onColor,
                      ),
                      onPressed: () => grantPremium(group),
                      child: const Text('Grant Premium'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete group',
                    onPressed: () => deleteGroup(group),
                    icon: Icon(Icons.delete_rounded, color: colors.danger),
                  ),
                  IconButton(
                    tooltip: collapsed ? 'Show students' : 'Hide students',
                    onPressed: () => setState(() {
                      if (collapsed) {
                        _collapsedGroups.remove(group.id);
                      } else {
                        _collapsedGroups.add(group.id);
                      }
                    }),
                    icon: AnimatedRotation(
                      turns: collapsed ? -0.25 : 0,
                      duration: AppMotion.quick,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );

              return Container(
                width: double.infinity,
                // Was a solid `colors.brand` slab with white text - the same
                // 3.55:1 dark-mode failure as the sidebar. A tinted admin
                // surface keeps the group header distinct from the card body
                // while staying legible in both themes.
                color: colors.adminSoft,
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
          if (!collapsed)
            if (group.students.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No students in this group yet.'),
              )
            else if (context.breakpoint.usesDataTable)
              _buildStudentTable(group, groups)
            else
              _buildStudentCards(group, groups),
        ],
      ),
      ),
    );
  }

  /// Edit / reset-password / delete for one student.
  ///
  /// Extracted so the table and the stacked-card layout call the *same*
  /// handlers. Duplicating these into two layouts is how one of them quietly
  /// drifts out of step with the other.
  Widget _studentActions(
    CapstoneGroup group,
    StudentAccount student,
    List<CapstoneGroup> groups,
  ) {
    final colors = AppColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit student',
          onPressed: () => editStudent(group, student, groups),
          icon: Icon(Icons.edit_rounded, color: colors.brand),
        ),
        IconButton(
          tooltip: 'Reset password',
          onPressed: () => resetStudentPassword(group, student),
          icon: Icon(Icons.lock_reset_rounded, color: colors.brand),
        ),
        IconButton(
          tooltip: 'Delete student',
          onPressed: () => deleteStudent(group, student),
          icon: Icon(Icons.delete_rounded, color: colors.danger),
        ),
      ],
    );
  }

  /// The temp password cell, shared by both layouts.
  ///
  /// Shows the issued password until the student sets their own; after that it
  /// reads "Password changed", because their real password lives in Firebase
  /// Auth and can never be read back.
  Widget _tempPasswordText(StudentAccount student) {
    final colors = AppColors.of(context);

    if (student.tempPassword.isEmpty) {
      return Text(
        'Password changed',
        style: TextStyle(
          color: colors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Monospaced plus a copy button: an admin reading this to a student had to
    // drag-select an 8-character password, and 0/O and 1/l are easy to confuse.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SelectableText(
            student.tempPassword,
            maxLines: 1,
            style: AppTypography.numeric.copyWith(color: colors.textPrimary),
          ),
        ),
        IconButton(
          tooltip: 'Copy temporary password',
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          icon: const Icon(Icons.copy_rounded),
          onPressed: () => copyToClipboard(
            context,
            student.tempPassword,
            label: 'Temporary password',
          ),
        ),
      ],
    );
  }

  Widget _studentStatusChip(StudentAccount student) {
    final colors = AppColors.of(context);

    return student.mustChangePassword
        ? statusChip('Temp not changed', colors.premium)
        : statusChip('Student set own', colors.success);
  }

  /// Tablet and desktop: the full six-column table.
  Widget _buildStudentTable(
    CapstoneGroup group,
    List<CapstoneGroup> groups,
  ) {
    return LayoutBuilder(
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
                      DataCell(Text(student.name)),
                      DataCell(Text(student.email)),
                      DataCell(Text(student.studentId)),
                      DataCell(_tempPasswordText(student)),
                      DataCell(_studentStatusChip(student)),
                      DataCell(_studentActions(group, student, groups)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Phones: one card per student instead of a table.
  ///
  /// A six-column table on a 360 px screen could only be read by dragging it
  /// sideways, which meant the actions column - the reason an admin opens this
  /// screen - was off-screen by default. Same data, same actions, no
  /// horizontal scrolling.
  Widget _buildStudentCards(
    CapstoneGroup group,
    List<CapstoneGroup> groups,
  ) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          for (final student in group.students)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: AppTypography.titleSmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              student.email,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _studentStatusChip(student),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _StudentField(
                    label: 'Student ID',
                    child: SelectableText(student.studentId),
                  ),
                  _StudentField(
                    label: 'Temp password',
                    child: _tempPasswordText(student),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _studentActions(group, student, groups),
                  ),
                ],
              ),
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

  Future<void> _printCredentials(List<CapstoneGroup> groups) async {
    if (groups.every((g) => g.students.isEmpty)) {
      showMessage('No students to print yet.');
      return;
    }
    // Let the admin pick which groups/students (and optionally only those who
    // still have a temp password) before printing.
    final selection = await showDialog<List<CapstoneGroup>>(
      context: context,
      builder: (_) => PrintOptionsDialog(groups: groups),
    );
    if (selection == null || selection.isEmpty) return;
    try {
      await CredentialsPrinter.printRoster(selection);
    } catch (error) {
      showMessage('Could not open the print view: $error');
    }
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
    try {
      final created = await _runWithProgress(
        () => FunctionsService().createStudent(
          name: draft.name,
          email: draft.email,
          groupId: draft.groupId,
        ),
      );
      if (!mounted || created == null) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Student registered'),
          // The temporary password is shown here and never again - once the
          // student sets their own, it is gone from Firestore. So this panel
          // is built for accurate transcription: monospaced values, a copy
          // button on each, and an explicit warning.
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  draft.name,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
                AppSpacing.vXs,
                Text(
                  draft.email,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
                AppSpacing.vLg,
                CredentialValue(
                  label: 'Student ID',
                  value: created.studentId,
                ),
                AppSpacing.vSm,
                CredentialValue(
                  label: 'Temporary password',
                  value: created.tempPassword,
                  emphasis: true,
                ),
                AppSpacing.vMd,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).warningTint,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                      color: AppColors.of(context)
                          .tintBorder(AppColors.of(context).warning),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: AppSize.iconSm,
                        color: AppColors.of(context).warning,
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(
                          'Copy this password now. Once the student sets their '
                          'own, it cannot be shown again - you would have to '
                          'reset it.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.of(context).textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => copyToClipboard(
                context,
                '${draft.name}\n'
                'Student ID: ${created.studentId}\n'
                'Temporary password: ${created.tempPassword}',
                label: 'Credentials',
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text('Copy all'),
            ),
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

  Future<void> grantPremium(CapstoneGroup group) async {
    final colors = AppColors.of(context);
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
              backgroundColor: colors.premium,
              foregroundColor: colors.onColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant Premium'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await runAction(() => _repo.grantPremium(group), 'Premium granted.');
    // Pulse the card so the change is visible where it happened, not only in
    // a snack bar that may be read after looking away.
    if (mounted) {
      setState(() {
        _pulsedGroupId = group.id;
        _pulseTick++;
      });
    }
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
          // Scrollable: two fields plus the on-screen keyboard overflows a
          // short phone screen, and an AlertDialog does not scroll by default.
          content: SingleChildScrollView(
            child: Column(
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
    final colors = AppColors.of(context);
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
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
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
    final colors = AppColors.of(context);
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
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (student.uid.isEmpty) {
      showMessage('This student has no login yet. Refresh and try again.');
      return;
    }
    try {
      await _runWithProgress(
        () => FunctionsService().deleteStudent(
          uid: student.uid,
          groupId: group.id,
          studentId: student.studentId,
        ),
      );
      if (mounted) showMessage('Student deleted.');
    } catch (error) {
      showMessage(error.toString());
    }
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
    if (student.uid.isEmpty) {
      showMessage('This student has no login yet. Refresh and try again.');
      return;
    }

    try {
      final newPassword = await _runWithProgress(
        () => FunctionsService().resetStudentPassword(
          uid: student.uid,
          groupId: group.id,
        ),
      );
      if (!mounted || newPassword == null) return;
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
    // Logout sits in the nav list right under the portal's page entries, so it
    // is a plausible mis-tap - and an admin mid-way through registering a class
    // should not lose the screen to one.
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Log out?',
      message: 'You will need to sign in again to manage groups and students.',
      confirmLabel: 'Log out',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

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

  // Shows a blocking spinner while [op] runs. Register/reset/delete call Cloud
  // Functions, which take a moment (a network round-trip, sometimes a cold
  // start), so this keeps the tap from feeling unresponsive.
  Future<T?> _runWithProgress<T>(Future<T> Function() op) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(width: 52, height: 52, child: CircularProgressIndicator()),
      ),
    );
    try {
      return await op();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
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
    final colors = AppColors.of(context);
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
            color: colors.background,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'A unique Student ID and temporary password will be automatically generated upon registration.',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: colors.brand),
          onPressed: submit,
          icon: const Icon(Icons.person_add_rounded),
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

/// A labelled value row inside a student card on the phone layout.
class _StudentField extends StatelessWidget {
  const _StudentField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Skeleton shown while the groups stream delivers its first snapshot.
///
/// Shaped like the dashboard that is about to arrive - the action row, three
/// stat cards, then group cards - rather than a bare spinner that tells the
/// admin nothing about what is loading.
class _AdminLoading extends StatelessWidget {
  const _AdminLoading();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Skeleton(
          child: ListView(
            padding: EdgeInsets.all(context.pagePadding),
            children: const [
              Row(
                children: [
                  SkeletonBox(width: 170, height: 40, radius: AppRadius.md),
                  SizedBox(width: AppSpacing.md),
                  SkeletonBox(width: 150, height: 40, radius: AppRadius.md),
                ],
              ),
              SizedBox(height: AppSpacing.xl),
              SkeletonBox(height: 48, radius: AppRadius.md),
              SizedBox(height: AppSpacing.xl),
              SkeletonCard(lines: 3),
              SizedBox(height: AppSpacing.lg),
              SkeletonCard(lines: 3),
              SizedBox(height: AppSpacing.lg),
              SkeletonCard(lines: 3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Caps and centres admin page content on wide monitors.
///
/// The student screens have used a content measure since the overhaul; the
/// admin dashboard was still stretching edge to edge on a 1920px display.
class _CenteredMax extends StatelessWidget {
  const _CenteredMax({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
