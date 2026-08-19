import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/theme_toggle_button.dart';
import '../services/title_generator_service.dart';
import '../theme/app_typography.dart';

// The fields a capstone can sit in. Every chip is tagged with the domains it
// belongs to, which is what keeps a set of picks coherent: "Healthcare Workers"
// and "Agriculture" have nothing to do with each other, and a student shouldn't
// be nudged toward pairing them.
enum Domain {
  education,
  healthcare,
  agriculture,
  commerce,
  government,
  environment,
  transport,
  tourism,
  finance,
}

// How a domain is named to the student. The enum is internal; these strings are
// what appears in the cross-field confirmation, so they have to read as fields
// of study rather than identifiers.
String _domainLabel(Domain domain) => switch (domain) {
      Domain.education => 'Education',
      Domain.healthcare => 'Healthcare',
      Domain.agriculture => 'Agriculture',
      Domain.commerce => 'E-Commerce',
      Domain.government => 'Local Governance',
      Domain.environment => 'Environment',
      Domain.transport => 'Transportation',
      Domain.tourism => 'Tourism',
      Domain.finance => 'Finance',
    };

// "Education", "Education and Healthcare", "Education, Healthcare and Tourism".
// Iterates Domain.values rather than the set so the order is stable between
// builds - a Set<Domain> has no meaningful order of its own.
String _fieldList(Set<Domain> domains) {
  final names = <String>[
    for (final domain in Domain.values)
      if (domains.contains(domain)) _domainLabel(domain),
  ];
  if (names.isEmpty) return 'no particular field';
  if (names.length == 1) return names.single;
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

// One selectable filter chip.
//
// An EMPTY domain set means "fits anywhere". Most project types and
// technologies are genuinely field-agnostic - a Mobile Application or Data
// Analytics is at home in any capstone - so those are never treated as
// unrelated. Only chips that really do belong to a field carry tags.
class ChipOption {
  const ChipOption(this.label, [this.domains = const {}]);

  final String label;
  final Set<Domain> domains;

  // Related to what's currently picked? Universal chips always are, and with
  // nothing picked yet everything is fair game.
  bool isRelatedTo(Set<Domain> active) =>
      active.isEmpty ||
      domains.isEmpty ||
      domains.intersection(active).isNotEmpty;
}

// Motion + metrics for the filter chips. The height and label style are fixed
// on purpose: the layout below measures chips itself, so their size has to be
// something we can predict rather than discover.
const double _chipHeight = 38;
const double _chipSpacing = 8;
const double _chipRunSpacing = 8;
const Duration _chipMotion = Duration(milliseconds: 260);
const Curve _chipCurve = Curves.easeOutCubic;

// The font is pinned here on purpose, and this is load-bearing.
//
// _chipWidth() below measures labels with a TextPainter using this exact
// style, while _FilterChip renders them with it. If the style leaves the font
// unset, the two disagree: the painter falls back to the platform default,
// but the rendered Text merges onto DefaultTextStyle and picks up the theme's
// family instead. The chip then paints wider than the layout reserved for it
// and silently overflows. Naming the family (and the weight) keeps the
// measurement and the paint on the same font.
const TextStyle _chipLabelStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontFamilyFallback: AppTypography.fontFamilyFallback,
  fontSize: 14,
  fontWeight: AppTypography.medium,
  fontVariations: <FontVariation>[FontVariation('wght', 500)],
);

// Chip labels are a fixed list, so measuring each one once is plenty.
final Map<String, double> _chipWidthCache = {};

// How wide a chip needs to be to hold its label.
//
// We force this width on the chip rather than letting it size itself, so the
// hand-rolled layout below is authoritative and can't drift out of step with
// what Material actually paints. The slack covers the chip's own label and
// content padding - erring wide is harmless (a slightly roomier chip), erring
// narrow would overflow.
double _chipWidth(String label, double textScale) {
  return _chipWidthCache.putIfAbsent('$label@$textScale', () {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _chipLabelStyle),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(textScale),
    )..layout();
    return painter.width + 34;
  });
}

// Simple title generator.
// Students pick filters (or let it roll one for them) and get title ideas back.
class TitleGeneratorScreen extends StatefulWidget {
  const TitleGeneratorScreen({super.key});

  @override
  State<TitleGeneratorScreen> createState() => _TitleGeneratorScreenState();
}

class _TitleGeneratorScreenState extends State<TitleGeneratorScreen> {
  final Set<String> selected = {};
  final _othersController = TextEditingController();
  final _service = TitleGeneratorService();
  bool isGenerating = false;

  // Edit these lists to change the available filter chips. Labels must stay
  // unique across ALL four lists - selection is tracked by label.
  static const List<ChipOption> projectTypes = [
    ChipOption('Mobile Application'),
    ChipOption('Web Application'),
    ChipOption('Desktop Software'),
    ChipOption('Management System'),
    ChipOption('IoT System', {
      Domain.agriculture,
      Domain.healthcare,
      Domain.environment,
      Domain.transport,
    }),
    ChipOption('E-Learning Platform', {Domain.education}),
    ChipOption('Marketplace Platform', {
      Domain.commerce,
      Domain.agriculture,
      Domain.tourism,
    }),
    ChipOption('Monitoring Dashboard', {
      Domain.healthcare,
      Domain.environment,
      Domain.agriculture,
      Domain.government,
      Domain.transport,
    }),
  ];

  static const List<ChipOption> targetUsers = [
    ChipOption('Students', {Domain.education}),
    ChipOption('Teachers', {Domain.education}),
    ChipOption('School Administrators', {Domain.education}),
    ChipOption('Healthcare Workers', {Domain.healthcare}),
    ChipOption('Patients', {Domain.healthcare}),
    ChipOption('Farmers', {Domain.agriculture}),
    ChipOption('Fisherfolk', {Domain.agriculture, Domain.environment}),
    ChipOption('Small Business Owners', {Domain.commerce, Domain.finance}),
    ChipOption('Online Sellers', {Domain.commerce}),
    ChipOption('Barangay Officials', {Domain.government}),
    ChipOption('Commuters', {Domain.transport}),
    ChipOption('Travelers', {Domain.tourism, Domain.transport}),
    ChipOption('Disaster Responders', {Domain.environment, Domain.government}),
  ];

  static const List<ChipOption> problemAreas = [
    ChipOption('Education', {Domain.education}),
    ChipOption('Healthcare', {Domain.healthcare}),
    ChipOption('E-Commerce', {Domain.commerce}),
    ChipOption('Agriculture', {Domain.agriculture}),
    ChipOption('Local Governance', {Domain.government}),
    ChipOption('Disaster Preparedness', {
      Domain.environment,
      Domain.government,
    }),
    ChipOption('Transportation', {Domain.transport}),
    ChipOption('Tourism', {Domain.tourism}),
    ChipOption('Financial Literacy', {Domain.finance, Domain.commerce}),
    ChipOption('Environmental Sustainability', {Domain.environment}),
  ];

  static const List<ChipOption> technologies = [
    ChipOption('Artificial Intelligence'),
    ChipOption('Machine Learning'),
    ChipOption('Data Analytics'),
    ChipOption('Chatbot / NLP', {
      Domain.education,
      Domain.healthcare,
      Domain.government,
      Domain.commerce,
    }),
    ChipOption('Computer Vision', {
      Domain.healthcare,
      Domain.agriculture,
      Domain.environment,
      Domain.transport,
    }),
    ChipOption('Internet of Things', {
      Domain.agriculture,
      Domain.healthcare,
      Domain.environment,
      Domain.transport,
    }),
    ChipOption('Blockchain', {
      Domain.finance,
      Domain.commerce,
      Domain.government,
      Domain.healthcare,
    }),
    ChipOption('Geotagging / GIS', {
      Domain.transport,
      Domain.tourism,
      Domain.environment,
      Domain.agriculture,
      Domain.government,
    }),
    ChipOption('Augmented Reality', {Domain.education, Domain.tourism}),
    ChipOption('SMS / Offline-First', {
      Domain.agriculture,
      Domain.government,
      Domain.environment,
    }),
  ];

  static const List<List<ChipOption>> categories = [
    projectTypes,
    targetUsers,
    problemAreas,
    technologies,
  ];

  // Every domain carried by the chips picked so far. This is what the other
  // categories reorder themselves around.
  Set<Domain> get activeDomains {
    final active = <Domain>{};
    for (final options in categories) {
      for (final option in options) {
        if (selected.contains(option.label)) active.addAll(option.domains);
      }
    }
    return active;
  }

  bool get hasInput =>
      selected.isNotEmpty || _othersController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _othersController.dispose();
    super.dispose();
  }

  // Finds the chip behind a label. Labels are unique across all four lists, so
  // one match is all there is.
  ChipOption? optionFor(String label) {
    for (final options in categories) {
      for (final option in options) {
        if (option.label == label) return option;
      }
    }
    return null;
  }

  Future<void> toggle(String value) async {
    // Dropping a pick never needs a warning - it can only ever make the set
    // more coherent, and asking would make chips annoying to undo.
    if (selected.contains(value)) {
      setState(() => selected.remove(value));
      return;
    }

    final active = activeDomains;
    final option = optionFor(value);

    // The faded chips at the back of each row are reachable on purpose, but
    // reaching one used to be indistinguishable from a mis-tap: the chip simply
    // joined the set, and the student found out at Generate, when the titles
    // came back trying to serve two unrelated fields at once. Confirming makes
    // the choice deliberate without ever taking it away.
    if (option != null && !option.isRelatedTo(active)) {
      final confirmed = await confirmCrossField(option, active);
      if (!confirmed || !mounted) return;
    }

    setState(() => selected.add(value));
  }

  // Names both sides of the mismatch rather than asking a bare "are you sure?".
  // A student who genuinely wants blockchain for medical records should be able
  // to read this, recognise their own intent, and carry on.
  Future<bool> confirmCrossField(ChipOption option, Set<Domain> active) {
    return showConfirmDialog(
      context: context,
      title: 'Add a chip from another field?',
      message: 'Your picks so far sit in ${_fieldList(active)}. '
          '"${option.label}" belongs to ${_fieldList(option.domains)}.\n\n'
          'You can still choose it - a deliberate cross-field capstone is often '
          'strong work. Just know the title ideas then have to stretch across '
          'every field you have picked, so they tend to come back vaguer than '
          'a focused set.',
      confirmLabel: 'Add anyway',
      icon: Icons.alt_route_rounded,
    );
  }

  void clearSelection() {
    setState(() {
      selected.clear();
      _othersController.clear();
    });
  }

  // Picks the FIELD first, then fills each category from what fits it. Choosing
  // every category independently is what used to produce sets like "healthcare
  // workers + agriculture + blockchain".
  void randomizeSelection() {
    final random = Random();
    final domain = Domain.values[random.nextInt(Domain.values.length)];
    selected.clear();
    for (final options in categories) {
      // Domain-specific chips plus the field-agnostic ones, so broad categories
      // (project type, technology) still offer their full range.
      final pool = options
          .where((o) => o.domains.isEmpty || o.domains.contains(domain))
          .toList();
      if (pool.isEmpty) continue;
      selected.add(pool[random.nextInt(pool.length)].label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = activeDomains;

    return Scaffold(
            appBar: AppBar(
                title: const Text('Title Generator'),
        actions: const <Widget>[ThemeToggleButton()],
        bottom: appBarAccent(colors.moduleTitleGen),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppContentWidth.reading),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select filters to get capstone title ideas, or just press '
                    'Generate and we\'ll pick a set for you.',
                    style: TextStyle(fontSize: 16),
                  ),
                  // Slides open with the chips rather than snapping in the
                  // moment the first filter is picked.
                  AnimatedSize(
                    duration: _chipMotion,
                    curve: _chipCurve,
                    alignment: Alignment.topCenter,
                    child: active.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Options that fit your picks are shown first. '
                              'Faded ones are less related, but you can still '
                              'choose them.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  buildSection('PROJECT TYPE', projectTypes, active),
                  buildSection('TARGET USERS', targetUsers, active),
                  buildSection('PROBLEM AREA', problemAreas, active),
                  buildSection('TECHNOLOGY', technologies, active),
                  buildOthersSection(),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isGenerating ? null : generate,
                    // The AI call takes a few seconds; without this the button
                    // just greys out and the screen looks frozen.
                    icon: isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.bolt),
                    label: Text(
                      isGenerating ? 'Generating...' : 'Generate Titles',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isGenerating || !hasInput ? null : clearSelection,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Selection'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reusable section builder for each filter group. Chips related to what's
  // already picked come first; the rest stay available but faded, since a
  // deliberate cross-field project (blockchain for medical records, say) is a
  // perfectly good capstone and shouldn't be blocked.
  Widget buildSection(
    String title,
    List<ChipOption> options,
    Set<Domain> active,
  ) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              _AnimatedChipWrap(
                options: options,
                active: active,
                selected: selected,
                onToggle: toggle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Free text for a student who already has something specific in mind and
  // can't say it with chips.
  Widget buildOthersSection() {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ANYTHING SPECIFIC? (OPTIONAL)',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _othersController,
                maxLines: 2,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. a scheduling system for our barangay health center',
                  border: OutlineInputBorder(),
                ),
                // Keeps the Clear button's enabled state in step with the text.
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> generate() async {
    // Nothing to go on? Roll a coherent set rather than nagging - the student
    // pressed Generate, so give them something to react to. Typed text counts
    // as intent, so it's left to stand on its own.
    if (!hasInput) setState(randomizeSelection);
    await generateAndShow();
  }

  Future<void> generateAndShow() async {
    setState(() => isGenerating = true);
    try {
      final titles = await _service.generateTitles(
        projectTypes: labelsOf(projectTypes),
        targetUsers: labelsOf(targetUsers),
        problemAreas: labelsOf(problemAreas),
        technologies: labelsOf(technologies),
        others: _othersController.text.trim(),
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Generated Titles'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final title in titles) ...[
                SelectableText('• $title'),
                const SizedBox(height: 8),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Generation Failed'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => isGenerating = false);
    }
  }

  List<String> labelsOf(List<ChipOption> options) => options
      .map((o) => o.label)
      .where(selected.contains)
      .toList();
}

// Lays chips out like a Wrap, but glides them to their new spots when the order
// changes instead of letting them teleport.
//
// Flutter has no animated Wrap: it re-runs its layout and children snap to the
// new positions with nothing to tween. So we run the wrap algorithm ourselves,
// which means we know every chip's target offset, and hand those to
// AnimatedPositioned inside a Stack - the glide then comes for free.
class _AnimatedChipWrap extends StatelessWidget {
  const _AnimatedChipWrap({
    required this.options,
    required this.active,
    required this.selected,
    required this.onToggle,
  });

  final List<ChipOption> options;
  final Set<Domain> active;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Related chips lead; everything else keeps its relative order behind
        // them, so the list only ever splits in two rather than reshuffling.
        final ordered = [
          ...options.where((o) => o.isRelatedTo(active)),
          ...options.where((o) => !o.isRelatedTo(active)),
        ];

        final widths = {
          for (final option in options)
            option.label: _chipWidth(option.label, textScale),
        };

        // The wrap algorithm, run by hand: walk the ordered chips, break to a
        // new row when the next one won't fit, and remember where each landed.
        final spots = <String, Offset>{};
        var x = 0.0;
        var y = 0.0;
        for (final option in ordered) {
          final width = widths[option.label]!;
          if (x > 0 && x + width > constraints.maxWidth) {
            x = 0;
            y += _chipHeight + _chipRunSpacing;
          }
          spots[option.label] = Offset(x, y);
          x += width + _chipSpacing;
        }

        return AnimatedContainer(
          duration: _chipMotion,
          curve: _chipCurve,
          // Reordering can change the row count, so the box grows/shrinks with
          // it rather than jumping.
          height: y + _chipHeight,
          child: Stack(
            children: [
              // Iterate the ORIGINAL order, not the sorted one, so this child
              // list never reshuffles - only each chip's target offset changes.
              // That's what leaves AnimatedPositioned something to tween.
              for (final option in options)
                AnimatedPositioned(
                  key: ValueKey(option.label),
                  duration: _chipMotion,
                  curve: _chipCurve,
                  left: spots[option.label]!.dx,
                  top: spots[option.label]!.dy,
                  width: widths[option.label],
                  height: _chipHeight,
                  child: _FilterChip(
                    option: option,
                    // A picked chip always counts as related to itself, so this
                    // never fades something the student chose.
                    isRelated: option.isRelatedTo(active),
                    isSelected: selected.contains(option.label),
                    onTap: () => onToggle(option.label),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.option,
    required this.isRelated,
    required this.isSelected,
    required this.onTap,
  });

  final ChipOption option;
  final bool isRelated;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      duration: _chipMotion,
      curve: Curves.easeOut,
      opacity: isRelated ? 1 : 0.4,
      child: ChoiceChip(
        label: Text(option.label, softWrap: false, maxLines: 1),
        selected: isSelected,
        // Selection reads from the fill colour instead. A checkmark would make
        // a chip wider when picked, and the layout above needs a width that
        // doesn't change out from under it.
        showCheckmark: false,
        selectedColor: scheme.primary,
        // Only the COLOUR is overridden here. Size, weight and family must stay
        // exactly as _chipLabelStyle declares them, because the same style is
        // what the TextPainter above measures to reserve each chip's width -
        // change a metric here and the chips overflow.
        labelStyle: _chipLabelStyle.copyWith(
          color: isSelected ? scheme.onPrimary : scheme.onSurface,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        // Without this Material reserves a 48px tap target and blows past the
        // fixed height the layout hands us.
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
