import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/admin_repository.dart';

// Lets the admin choose exactly which students to print credentials for:
// exclude whole groups, pick individual students, or narrow to just the ones
// who still have a temp password to hand out. Returns the chosen groups (each
// trimmed to the selected students), or null if cancelled.
class PrintOptionsDialog extends StatefulWidget {
  const PrintOptionsDialog({super.key, required this.groups});

  final List<CapstoneGroup> groups;

  @override
  State<PrintOptionsDialog> createState() => _PrintOptionsDialogState();
}

class _PrintOptionsDialogState extends State<PrintOptionsDialog> {
  // Keys of the currently selected students. All selected to start.
  late final Set<String> _selected;
  // On by default: the usual task is handing temp passwords to students who
  // haven't logged in yet. The admin can turn it off to include everyone.
  bool _onlyTemp = true;

  String _key(StudentAccount s) => s.uid.isNotEmpty ? s.uid : s.id;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final g in widget.groups)
        for (final s in g.students) _key(s),
    };
  }

  // A student is "visible" when it passes the temp-password filter.
  bool _visible(StudentAccount s) => !_onlyTemp || s.tempPassword.isNotEmpty;

  List<StudentAccount> _visibleStudents(CapstoneGroup g) =>
      g.students.where(_visible).toList();

  int get _selectedCount => widget.groups
      .expand((g) => g.students)
      .where((s) => _visible(s) && _selected.contains(_key(s)))
      .length;

  void _toggleStudent(StudentAccount s, bool on) {
    setState(() => on ? _selected.add(_key(s)) : _selected.remove(_key(s)));
  }

  void _toggleGroup(CapstoneGroup g, bool on) {
    setState(() {
      for (final s in _visibleStudents(g)) {
        on ? _selected.add(_key(s)) : _selected.remove(_key(s));
      }
    });
  }

  void _setAll(bool on) {
    setState(() {
      for (final g in widget.groups) {
        for (final s in _visibleStudents(g)) {
          on ? _selected.add(_key(s)) : _selected.remove(_key(s));
        }
      }
    });
  }

  // The chosen groups, each trimmed to only its selected + visible students,
  // with empty groups dropped.
  List<CapstoneGroup> _result() {
    final result = <CapstoneGroup>[];
    for (final g in widget.groups) {
      final chosen = g.students
          .where((s) => _visible(s) && _selected.contains(_key(s)))
          .toList();
      if (chosen.isNotEmpty) {
        result.add(CapstoneGroup(
          id: g.id,
          name: g.name,
          isPremium: g.isPremium,
          students: chosen,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final visibleGroups =
        widget.groups.where((g) => _visibleStudents(g).isNotEmpty).toList();

    return AlertDialog(
      title: const Text('Print Credentials'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$_selectedCount selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => _setAll(true),
                  child: const Text('Select all'),
                ),
                TextButton(
                  onPressed: () => _setAll(false),
                  child: const Text('Clear'),
                ),
              ],
            ),
            CheckboxListTile(
              value: _onlyTemp,
              onChanged: (v) => setState(() => _onlyTemp = v ?? false),
              title: const Text('Only students who still have a temp password'),
              subtitle: const Text('Hides students who already set their own'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            const Divider(height: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: visibleGroups.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No students match this filter.'),
                      )
                    : Theme(
                        // Drop the ExpansionTile divider lines for a cleaner list.
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final g in visibleGroups) _groupTile(g),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed:
              _selectedCount == 0 ? null : () => Navigator.pop(context, _result()),
          icon: const Icon(Icons.print),
          label: Text('Print ($_selectedCount)'),
        ),
      ],
    );
  }

  Widget _groupTile(CapstoneGroup g) {
    final visible = _visibleStudents(g);
    final selectedInGroup =
        visible.where((s) => _selected.contains(_key(s))).length;
    final allSelected = selectedInGroup == visible.length;
    final noneSelected = selectedInGroup == 0;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 16),
      leading: Checkbox(
        // Tri-state: checked (all), dash (some), empty (none).
        value: noneSelected ? false : (allSelected ? true : null),
        tristate: true,
        onChanged: (_) => _toggleGroup(g, !allSelected),
      ),
      title: Text(
        g.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '$selectedInGroup of ${visible.length} selected',
        style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
      ),
      children: [
        for (final s in visible)
          CheckboxListTile(
            value: _selected.contains(_key(s)),
            onChanged: (v) => _toggleStudent(s, v ?? false),
            title: Text(s.name),
            subtitle: Text(
              '${s.studentId} — '
              '${s.tempPassword.isEmpty ? 'password set' : 'temp: ${s.tempPassword}'}',
              style: const TextStyle(fontSize: 12),
            ),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
      ],
    );
  }
}
