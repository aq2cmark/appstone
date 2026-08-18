import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/reading_scale.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/theme_toggle_button.dart';
import '../services/paper_checker_service.dart'
    show manuscriptRubric, rubricMaxScore;

// Capstone manual home page.
// Content below is a simplified, organized rewrite of the DCT CCS Capstone
// Manual - not a line-by-line copy - broken into short topics with bullet
// points so it's easy to scan. Edit the section list in _buildSections()
// to change the content.
class CapstoneManualScreen extends StatefulWidget {
  const CapstoneManualScreen({super.key});

  @override
  State<CapstoneManualScreen> createState() => _CapstoneManualScreenState();
}

class _CapstoneManualScreenState extends State<CapstoneManualScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  late final List<ManualSection> _sections = _buildSections();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final query = _query.trim();
    final results = query.isEmpty ? null : _search(query);

    return Scaffold(
            appBar: AppBar(
                title: const Text('Capstone Manual'),
        actions: const <Widget>[ThemeToggleButton()],
        bottom: appBarAccent(colors.moduleManual),
      ),
      body: StudentListBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Two coarse steps rather than one per card: the section/result list
          // can be long, and animating every single card would mean waiting
          // out a growing delay chain each time the search query changes.
          children: StaggeredEntrance.list(<Widget>[
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search the manual... e.g. "grading", "format"',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: colors.surface,
                border: const OutlineInputBorder(),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                if (results == null) ...[
                  const SectionLabel('CONTENTS'),
                  const SizedBox(height: 8),
                  for (final section in _sections)
                    ManualCard(
                      number: section.number,
                      title: section.title,
                      subtitle:
                          '${section.subtitle} - ${section.topics.length} topics',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ManualTopicListScreen(section: section),
                        ),
                      ),
                    ),
                ] else if (results.isEmpty) ...[
                  _buildNoResults(query),
                ] else ...[
                  SectionLabel(
                    '${results.length} RESULT${results.length == 1 ? '' : 'S'}',
                  ),
                  const SizedBox(height: 8),
                  for (final result in results)
                    ManualCard(
                      number: result.section.number,
                      title: result.topic.title,
                      subtitle:
                          'In ${result.section.title} - ${result.topic.subtitle}',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManualDetailScreen(topic: result.topic),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildNoResults(String query) {
    final colors = AppColors.of(context);
    return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: colors.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different word, like "grading", "format", or "roles".',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // Matches a topic if the search text appears anywhere in its own title,
  // subtitle, content, or bullet items - or in the section it belongs to, so
  // searching "grading" also surfaces topics filed under a "Grading" section
  // even if that exact word isn't repeated in the topic itself.
  List<_ManualSearchResult> _search(String query) {
    final q = query.toLowerCase();
    final results = <_ManualSearchResult>[];
    for (final section in _sections) {
      for (final topic in section.topics) {
        final haystack = [
          section.title,
          section.subtitle,
          topic.title,
          topic.subtitle,
          topic.content,
          ...topic.items,
        ].join(' ').toLowerCase();
        if (haystack.contains(q)) {
          results.add(_ManualSearchResult(section: section, topic: topic));
        }
      }
    }
    return results;
  }

  List<ManualSection> _buildSections() {
    return [
      ManualSection(
        number: '01',
        title: 'Introduction & Scope',
        subtitle: 'What a capstone project is for',
        topics: [
          ManualTopic(
            title: 'What is a Capstone Project?',
            subtitle: 'Your program\'s terminal requirement',
            content:
                'Based on CHED\'s CMO 25 s. 2015, your capstone project is the final '
                'requirement of the BSIT program. It should prove you can apply '
                'everything you learned - not just describe a problem, but actually '
                'build a computing solution for it. Surveys and statistics are only '
                'needed if your specific topic calls for them.',
          ),
          ManualTopic(
            title: 'What Your Project Should Cover',
            subtitle: 'Integrating what you learned',
            content:
                'Your capstone should bring together the courses and skills from '
                'your whole curriculum, and ideally introduce something new - a new '
                'feature, approach, or use of technology. If your project involves '
                'IT infrastructure, explain it clearly in your introduction. Your '
                'adviser decides how complex your project should be based on your '
                'team size, timeline, and available resources.',
          ),
        ],
      ),
      ManualSection(
        number: '02',
        title: 'Choosing Your Project Type',
        subtitle: 'Accepted areas and quick references',
        topics: [
          ManualTopic(
            title: 'Broad Project Categories',
            subtitle: 'The four main areas',
            items: [
              'Software Development - custom systems, information systems for a real client, web apps (with live testing), mobile apps',
              'Multimedia Systems - games, e-learning systems, interactive systems, information kiosks',
              'Network Design & Implementation - network or server-farm setups',
              'IT Management - IT strategic plans, IT security analysis and implementation',
            ],
          ),
          ManualTopic(
            title: 'Transaction Processing Systems',
            subtitle: 'Common system types and their minimum scale',
            items: [
              'Payroll System - needs at least 50 employees worth of test data',
              'Sales & Inventory System - at least 1,000 items across 5-10 product lines',
              'Library System - at least 2,000 titles and 500 members (a CHED requirement)',
              'Accounting System - at least 30 accounts',
              'Enrollment System - at least 200 students across 2+ sections per year level',
              'Hotel Reservation & Billing - at least 20 rooms and 100 customers',
              'Hospital / Patient Billing System - at least 20 beds and 50 patients',
            ],
          ),
          ManualTopic(
            title: 'Other System Types',
            subtitle: 'MIS, DSS, GIS, and web applications',
            items: [
              'Management Information System - generates standard reports for decision-makers',
              'Decision Support System - needs a database, a model base, and a dialogue module',
              'Geographic Information System - stores and analyzes location-based data',
              'Web Applications (online ordering, hotel booking, job application, pre-enrollment) - each needs an actual host company or client to be acceptable',
              'Artificial Intelligence - expert systems, neural networks, robotics, or intelligent agents',
            ],
          ),
          ManualTopic(
            title: 'Projects That Won\'t Be Accepted',
            subtitle: 'Avoid these outright',
            content:
                'This isn\'t the full list - the college can still reject a project '
                'for being too simple, impractical, or unoriginal.',
            items: [
              'DAMATH',
              'Video rental systems',
              'Card games or other non-educational games',
              'Basic record-keeping systems',
              'Simple monitoring systems',
              'Government websites (barangay, municipal, city, or provincial)',
            ],
          ),
        ],
      ),
      ManualSection(
        number: '03',
        title: 'Timeline & Phases',
        subtitle: 'How the project is structured over time',
        topics: [
          ManualTopic(
            title: 'How Long You Have',
            subtitle: 'Duration and units',
            content:
                'You\'re given 1 to 3 terms/semesters to finish, worth up to 9 '
                'units total. The work is normally split into two parts: Capstone '
                '1 (the proposal) and Capstone 2 (development and final defense).',
          ),
          ManualTopic(
            title: 'Capstone 1 - Proposal Stage',
            subtitle: 'From orientation to your first defense',
            items: [
              'Course enrollment and orientation',
              'Shortlisting possible project ideas',
              'Title proposal (with a patentability check if possible)',
              'Writing Chapters 1-4 (planning/design portions only)',
              'Submitting the proposal manuscript',
              'Oral defense of the proposal',
              'Revisions after the defense',
            ],
          ),
          ManualTopic(
            title: 'Capstone 2 - Final Stage',
            subtitle: 'Building and defending the finished system',
            items: [
              'Analysis, design, development, and testing',
              'Submitting the full capstone manuscript',
              'Final defense',
              'Manuscript revisions',
              'Public presentation',
              'Submitting all final requirements',
            ],
          ),
          ManualTopic(
            title: 'Optional: Patent Process',
            subtitle: 'Only if your project is patentable',
            content:
                'This stage comes after everything else and is entirely optional: '
                'drafting the patent, applying for it, and going through technology '
                'transfer.',
          ),
        ],
      ),
      ManualSection(
        number: '04',
        title: 'Your Team',
        subtitle: 'Roles, responsibilities, and regrouping',
        topics: [
          ManualTopic(
            title: 'Group Size & Roles',
            subtitle: '2 to 5 members, each with a job',
            content:
                'Teams should have 2 to 5 members - your adviser decides if your '
                'team can realistically finish on time at that size.',
            items: [
              'Project Manager (PM) - owns the plan, budget, and overall success of the project',
              'Systems Analyst / Database Designer (SA/DD) - keeps the system and database design solid and coordinated',
              'Network Designer / UI Designer (ND/UID) - handles the network design and the user interface',
              'Software Engineer / Programmer (SE/P) - writes and tests the code (a group can have two)',
              'QA Tester / Technical Writer (QA/TW) - tests for bugs and finalizes the written manuscript',
            ],
          ),
          ManualTopic(
            title: 'Your Responsibilities',
            subtitle: 'What\'s expected of every member',
            items: [
              'Stay updated on guidelines, schedules, and deliverables',
              'Submit everything on time - to your adviser, your panel, and your dean',
              'Meet your adviser at least once a month (book a proper appointment)',
              'Meet your dean at least once a semester',
            ],
          ),
          ManualTopic(
            title: 'If Your Group Loses Members',
            subtitle: 'The regrouping policy',
            content:
                'If your group drops below 3 members between Capstone 1 and 2, you '
                'can be merged into another group, as long as it doesn\'t exceed the '
                'max size. If the remaining member(s) want to continue alone '
                'instead, that needs sign-off from both your adviser and the dean, '
                'and your scope may need to shrink.',
          ),
        ],
      ),
      ManualSection(
        number: '05',
        title: 'Advisers & Panel',
        subtitle: 'Who evaluates your work',
        topics: [
          ManualTopic(
            title: 'Who\'s on Your Panel',
            subtitle: 'Composition and qualifications',
            content:
                'Your panel has 1 chairman plus 2 members, and may include content '
                'experts or a recorder. At least one panel member should have a '
                'master\'s degree in computing or a related field, and for IT '
                'specifically, at least one should have real industry experience.',
          ),
          ManualTopic(
            title: 'What Your Panel Does',
            subtitle: 'Their role in your defense',
            items: [
              'The chairman briefs you before the defense and delivers the final verdict',
              'A verdict is unanimous among all 3 panelists, and final once given',
              'Panel members validate your adviser\'s endorsement and evaluate your work',
              'Any panelist can nominate a strong project for a Capstone Award',
            ],
          ),
          ManualTopic(
            title: 'What Your Adviser Does For You',
            subtitle: 'Guidance throughout the project',
            content:
                'If you fail your Title Proposal or Oral Defense, it\'s considered '
                'partly on the adviser too - they\'re expected to only send you in '
                'once they think you\'re ready.',
            items: [
              'Makes sure your project meets college standards',
              'Helps you define the problem, build your research background, and choose a methodology',
              'Meets your team monthly to help resolve issues',
              'Reviews every deliverable before it goes to the panel',
            ],
          ),
        ],
      ),
      ManualSection(
        number: '06',
        title: 'Presenting Your Work',
        subtitle: 'The public presentation requirement',
        topics: [
          ManualTopic(
            title: 'The Public Presentation Requirement',
            subtitle: 'Beyond the panel defense',
            content:
                'On top of defending in front of your panel, your capstone must '
                'also be presented in a public forum - a conference, seminar, or '
                'school-organized colloquium open to outsiders. Presenting at an '
                'actual conference (like NCITE) is encouraged, but a school '
                'colloquium is enough to satisfy the requirement.',
          ),
        ],
      ),
      ManualSection(
        number: '07',
        title: 'How You\'re Graded',
        subtitle: 'Grade breakdown and rubrics',
        topics: [
          ManualTopic(
            title: 'Your Final Grade Breakdown',
            subtitle: 'Who contributes to your score',
            items: [
              'Panel members (average, including chairman) - 60%',
              'Your adviser - 30%',
              'Co-researcher / peer grading - 10%',
            ],
          ),
          ManualTopic(
            title: 'Capstone 1 Grading (Proposal)',
            subtitle: 'Per-panelist breakdown',
            items: [
              'Manuscript (group grade) - 40%',
              'Oral exam (individual grade) - 20%',
            ],
          ),
          ManualTopic(
            title: 'Capstone 2 Grading (Final)',
            subtitle: 'Per-panelist breakdown',
            items: [
              'Manuscript (group grade) - 10%',
              'Software (group grade) - 30%',
              'Oral exam (individual grade) - 20%',
            ],
          ),
          ManualTopic(
            title: 'Manuscript Rubric ($rubricMaxScore pts)',
            subtitle: 'What each chapter is scored on',
            content:
                'This is the exact rubric the app\'s Paper Checker feature uses to '
                'grade an uploaded manuscript automatically - upload your paper '
                'there to get a score and a list of issues per section.',
            items: [
              for (final section in manuscriptRubric)
                '${section.name} - up to ${section.max} pts',
            ],
          ),
          ManualTopic(
            title: 'Software Rubric (30 pts, Capstone 2)',
            subtitle: 'How your working system is scored',
            items: [
              'Output matches your original proposed objectives - 10 pts',
              'All major features/modules are delivered - 10 pts',
              'System design & aesthetics - 3 pts',
              'Group debugging (fixing planted bugs) - 7 pts',
            ],
          ),
          ManualTopic(
            title: 'Oral Exam Rubric (20 pts)',
            subtitle: 'How your defense answers are scored',
            items: [
              'Comprehensiveness of your answers - 10 pts',
              'Contribution / support to your team - 7 pts',
              'Delivery / command of English - 3 pts',
            ],
          ),
        ],
      ),
      ManualSection(
        number: '08',
        title: 'Possible Verdicts',
        subtitle: 'What can happen after a defense',
        topics: [
          ManualTopic(
            title: 'Capstone 1 Verdicts',
            subtitle: 'After the proposal defense',
            items: [
              'APPROVED (35-40) - only minor revisions, no need to re-present',
              'APPROVED WITH REVISIONS (24-34) - major revisions, checked by the panel',
              'DISAPPROVED (below 24) - not researchable or scholarly enough',
            ],
          ),
          ManualTopic(
            title: 'Capstone 2 Verdicts',
            subtitle: 'After the final defense',
            content:
                'A verdict is a unanimous decision by all 3 panel members. Once '
                'given, it\'s final.',
            items: [
              'ACCEPTED WITH REVISIONS (31-50) - revisions needed, no need to re-present',
              'REORAL DEFENSE (21-30) - you defend again in front of the full panel',
              'NOT ACCEPTED (below 21) - objectives weren\'t achieved',
            ],
          ),
        ],
      ),
      ManualSection(
        number: '09',
        title: 'Writing Your Manuscript',
        subtitle: 'Structure and formatting',
        topics: [
          ManualTopic(
            title: 'Document Outline',
            subtitle: 'What order things go in',
            items: [
              'Preliminary pages - title page, sign-off sheets, acknowledgement, abstract, table of contents',
              'Chapter 1 - Introduction (project context, objectives, scope & limitations)',
              'Chapter 2 - Review of Related Literature/Systems',
              'Chapter 3 - Technical Background',
              'Chapter 4 - Methodology, Results & Discussion',
              'Chapter 5 - Conclusion & Recommendations',
              'References, Resource Persons, Glossary, Appendices',
            ],
          ),
          ManualTopic(
            title: 'Formatting Standards',
            subtitle: 'The exact layout rules',
            content:
                'Upload your .docx to the app\'s Paper Checker feature to have all '
                'of this verified automatically.',
            items: [
              'Paper size: 8.5 x 11 inches, portrait',
              'Margins: 1" top, 1.5" left, 1" right, 1" bottom, 0.5" header & footer',
              'Line spacing: 1.5',
              'Font: Times New Roman - 11pt body text, 12pt headings',
              'Page numbers: bottom right, hidden on the first page of each chapter',
            ],
          ),
          ManualTopic(
            title: 'Abstract & Citations',
            subtitle: 'Small but easy-to-miss rules',
            content:
                'Your abstract should be 150-200 words - informative enough to '
                'stand in for the whole paper. State your rationale and '
                'objectives, skip citations/quotes, and don\'t start with "This '
                'paper/study/project...". For in-text citations, use the '
                'author\'s first 4 letters plus year (e.g. [MILL1991]) instead of '
                'traditional footnotes.',
          ),
        ],
      ),
      ManualSection(
        number: '10',
        title: 'Ownership & Ethics',
        subtitle: 'Who owns your work, and academic integrity',
        topics: [
          ManualTopic(
            title: 'Who Owns Your Project',
            subtitle: 'Intellectual property basics',
            content:
                'Your project starts out as your own intellectual property. Once '
                'it\'s approved and submitted, ownership transfers to the college '
                '(source code, docs, multimedia assets, the right to deploy or '
                'maintain it) - but you keep the right to further develop, '
                'publish, or even commercialize it afterward. The school won\'t '
                'claim financial rights unless you agree to that in writing.',
          ),
          ManualTopic(
            title: 'If Your Adviser or Panel Contributed Directly',
            subtitle: 'Co-authorship rules',
            content:
                'If an adviser or panelist did real technical or creative work '
                'beyond just supervising - not just consultation - they\'re '
                'considered a co-author and must be credited in all official '
                'outputs.',
          ),
          ManualTopic(
            title: 'Academic Integrity',
            subtitle: 'Plagiarism checks and consequences',
            content:
                'All plagiarism checking happens through the Research Office or '
                'Library before your oral defense - you can\'t defend until '
                'you\'re cleared, and it happens again before final publication. '
                'Plagiarism covers copied text, code, designs, or data, including '
                'reusing your own past work without disclosing it. Confirmed '
                'violations can mean a mandatory redo, a re-defense, failing the '
                'subject, or worse.',
          ),
        ],
      ),
    ];
  }
}

class _ManualSearchResult {
  const _ManualSearchResult({required this.section, required this.topic});

  final ManualSection section;
  final ManualTopic topic;
}

class ManualTopicListScreen extends StatelessWidget {
  // Shows the topic list inside one manual section.
  const ManualTopicListScreen({super.key, required this.section});

  final ManualSection section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
                title: Text(section.title),
      ),
      body: StudentListBody(
        child: Column(
          children: [
            for (int i = 0; i < section.topics.length; i++)
              ManualCard(
                number: '${i + 1}',
                title: section.topics[i].title,
                subtitle: section.topics[i].subtitle,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ManualDetailScreen(topic: section.topics[i]),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// One topic's content, laid out for sustained reading rather than scanning.
///
/// The manual is the only long-form reading surface in the app, so it gets
/// treatment the rest of the app does not: a narrower measure (~68 characters,
/// where the eye reliably finds the next line), larger body text with open
/// line-height, and a reader-controlled size step.
///
/// The previous version rendered each bullet as its own `Card`, so an
/// eight-point list became eight stacked boxes and roughly doubled the
/// scrolling on a phone.
class ManualDetailScreen extends StatefulWidget {
  const ManualDetailScreen({super.key, required this.topic});

  final ManualTopic topic;

  @override
  State<ManualDetailScreen> createState() => _ManualDetailScreenState();
}

class _ManualDetailScreenState extends State<ManualDetailScreen> {
  final _scrollController = ScrollController();

  /// 0..1 through the topic. Drives the thin bar under the app bar so a long
  /// section shows how much is left.
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    // A topic shorter than the viewport never scrolls; showing a 0% bar there
    // would suggest the reader had not started.
    final next = max <= 0
        ? 1.0
        : (_scrollController.offset / max).clamp(0.0, 1.0);
    if ((next - _progress).abs() < 0.005) return;
    setState(() => _progress = next);
  }

  /// Splits the topic body into paragraphs so the first can lead.
  List<String> get _paragraphs => widget.topic.content
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  /// True when an item states an obligation.
  ///
  /// Matched on wording the manual already uses - nothing is invented, and
  /// nothing is downgraded: an item that does not match simply renders as a
  /// normal bullet. This only changes emphasis, never meaning, which matters
  /// because the content mirrors an official institutional document.
  static bool _isRequirement(String item) {
    final lower = item.toLowerCase();
    return lower.contains('must ') ||
        lower.contains('required') ||
        lower.contains('shall ') ||
        lower.contains('not allowed') ||
        lower.contains('mandatory');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ValueListenableBuilder<double>(
      valueListenable: ReadingScale.instance,
      builder: (context, scale, _) {
        final paragraphs = _paragraphs;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.topic.title),
            actions: <Widget>[
              _ReadingSizeButtons(scale: scale),
              const ThemeToggleButton(),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: _ReadingProgressBar(
                value: _progress,
                color: colors.moduleManual,
              ),
            ),
          ),
          body: ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              AppSpacing.lg,
              context.pagePadding,
              AppSpacing.xxxl,
            ),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  // Narrower than the app's usual reading width: this is the
                  // one screen people read paragraph after paragraph on.
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: StaggeredEntrance.list(<Widget>[
                      _buildHeader(colors, scale),
                      if (paragraphs.isNotEmpty)
                        _buildBody(colors, scale, paragraphs),
                      if (widget.topic.items.isNotEmpty)
                        _buildItems(colors, scale),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppColors colors, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.topic.title,
          style: AppTypography.headlineLarge.copyWith(
            color: colors.textPrimary,
            fontSize: AppTypography.headlineLarge.fontSize! * scale,
            height: 1.25,
          ),
        ),
        AppSpacing.vSm,
        Text(
          widget.topic.subtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: colors.moduleManual,
            fontSize: AppTypography.bodyMedium.fontSize! * scale,
          ),
        ),
        AppSpacing.vLg,
        Divider(height: 1, color: colors.divider),
        AppSpacing.vLg,
      ],
    );
  }

  Widget _buildBody(AppColors colors, double scale, List<String> paragraphs) {
    // 17px base at scale 1.0 with 1.7 line-height. The lead paragraph runs a
    // little larger to give the eye somewhere to start.
    final body = AppTypography.bodyLarge.copyWith(
      color: colors.textPrimary,
      fontSize: 17 * scale,
      height: 1.7,
    );
    final lead = body.copyWith(
      fontSize: 19 * scale,
      height: 1.6,
      color: colors.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < paragraphs.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == paragraphs.length - 1 ? 0 : AppSpacing.lg,
            ),
            child: Text(paragraphs[i], style: i == 0 ? lead : body),
          ),
      ],
    );
  }

  Widget _buildItems(AppColors colors, double scale) {
    final itemStyle = AppTypography.bodyLarge.copyWith(
      color: colors.textPrimary,
      fontSize: 16 * scale,
      height: 1.6,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < widget.topic.items.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == widget.topic.items.length - 1
                        ? 0
                        : AppSpacing.md,
                  ),
                  child: _isRequirement(widget.topic.items[i])
                      ? _RequirementCallout(
                          text: widget.topic.items[i],
                          style: itemStyle,
                        )
                      : _Bullet(
                          text: widget.topic.items[i],
                          style: itemStyle,
                          color: colors.moduleManual,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A- / A+ pair for the manual's body size.
class _ReadingSizeButtons extends StatelessWidget {
  const _ReadingSizeButtons({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final reading = ReadingScale.instance;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: 'Smaller text',
          onPressed: reading.canDecrease ? reading.decrease : null,
          icon: const Icon(Icons.text_decrease_rounded),
        ),
        IconButton(
          tooltip: 'Larger text',
          onPressed: reading.canIncrease ? reading.increase : null,
          icon: const Icon(Icons.text_increase_rounded),
        ),
      ],
    );
  }
}

/// Thin scroll-position bar that doubles as the module accent line.
class _ReadingProgressBar extends StatelessWidget {
  const _ReadingProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: (value * 1000).round().clamp(1, 1000),
            child: ColoredBox(color: color),
          ),
          Expanded(
            flex: (1000 - value * 1000).round().clamp(1, 1000),
            child: ColoredBox(color: color.withValues(alpha: 0.18)),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.text,
    required this.style,
    required this.color,
  });

  final String text;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          // Sits on the first line's optical centre; follows the text size so
          // the marker does not drift as the reader scales up.
          padding: EdgeInsets.only(top: (style.fontSize ?? 16) * 0.55),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
        AppSpacing.hMd,
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// A bullet the manual states as an obligation, given a tinted block so it is
/// not lost among the surrounding descriptive points.
class _RequirementCallout extends StatelessWidget {
  const _RequirementCallout({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.warningTint,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.tintBorder(colors.warning)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: (style.fontSize ?? 16) * 0.15),
            child: Icon(
              Icons.priority_high_rounded,
              size: (style.fontSize ?? 16) * 1.05,
              color: colors.warning,
            ),
          ),
          AppSpacing.hMd,
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

class StudentListBody extends StatelessWidget {
  // Shared body wrapper for student pages.
  // It stops web/desktop layouts from becoming extremely wide.
  const StudentListBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: child,
          ),
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  // Small uppercase label used above grouped content.
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(
        color: colors.textSecondary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }
}

class ManualCard extends StatelessWidget {
  // Shared manual row so the section list and topic list stay consistent.
  const ManualCard({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String number;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: colors.brand,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            number.padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class ManualSection {
  // Simple model for one manual section.
  const ManualSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.topics,
  });

  final String number;
  final String title;
  final String subtitle;
  final List<ManualTopic> topics;
}

class ManualTopic {
  // Simple model for one topic inside a manual section.
  const ManualTopic({
    required this.title,
    required this.subtitle,
    this.content = '',
    this.items = const [],
  });

  final String title;
  final String subtitle;
  final String content;
  final List<String> items;
}
