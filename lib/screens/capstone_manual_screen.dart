import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/reading_scale.dart';
import '../widgets/app_motion_widgets.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/offline_notice.dart';
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
                // Every word below is compiled into the app bundle, so this
                // screen is complete with no connection. Saying so turns a
                // moment students would otherwise read as "the app is broken"
                // into the one place they can still work.
                const OfflineNotice(
                  message:
                      'The whole manual is saved on this device, so search and '
                      'every topic still work.',
                ),
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
                'requirement of the BSIT program. It\'s an undertaking appropriate '
                'to a professional field, and it should significantly address an '
                'existing problem or need - not just describe it, but actually '
                'build a computing solution for it, focusing on the '
                'infrastructure, application, or processes involved in '
                'implementing that solution. Surveys, statistics, and descriptive '
                'methods are only needed if your specific topic calls for them.',
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
          ManualTopic(
            title: 'About the College & Program',
            subtitle: 'Vision, mission, and what BSIT graduates should be able to do',
            content:
                'The Capstone Manual opens with the College of Computer Studies\' '
                'own identity. Vision: "A God-loving educational community with '
                'passion for truth and compassion for humanity." Mission: the '
                'total formation of the person, the promotion of truth, and the '
                'transformation of values for the service of humanity. Its goal '
                'is transformative education responsive to Wisdom, Social '
                'Responsibility, and Christian Witness - the three areas every '
                'BSIT graduate is formed in, each measured cognitively, '
                'affectively, and through action (psychomotor).\n\n'
                'More concretely, your program defines 13 Graduate Outcomes '
                '(IT01-IT13) your capstone is meant to demonstrate:',
            items: [
              'Knowledge for Solving Computing Problems (IT01-IT02) - apply computing, science, and math knowledge; understand best practices and standards',
              'Problem Analysis (IT03) - analyze complex problems and define the computing requirements they need',
              'Design/Development of Solutions (IT04-IT06) - analyze user needs, design and evaluate computer-based systems, and integrate solutions into the user\'s environment',
              'Modern Tool Usage (IT07) - apply current techniques, skills, tools, and practices used in the IT profession',
              'Individual and Team Work (IT08-IT09) - work as a member or leader of a development team, and help build an effective project plan',
              'Communication (IT10) - communicate clearly with the computing community and the public through writing, presentations, and instructions',
              'Computing Professionalism & Social Responsibility (IT11-IT12) - understand the local and global impact of IT, and its professional, ethical, legal, and security responsibilities',
              'Life-Long Learning (IT13) - recognize the need to keep learning and improving as a professional after graduation',
            ],
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
            subtitle: 'General requirements, then each type\'s minimum scale',
            content:
                'Whatever kind of TPS you build, reviewers expect all of the '
                'following: a complete, normalized file structure using master '
                'and transaction files; back-up and recovery (unless your DBMS '
                'already has it); archiving; complete data entry with '
                'validation and error trapping; proper maintenance features; '
                'complete reports; security and data-integrity checks; and a '
                'working network set-up.',
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
              'Management Information System - generates standard reports for managers, such as trend analysis, summary, exception, on-demand, and ad-hoc reports',
              'Decision Support System - needs a database, a model base, and a dialogue module',
              'Geographic Information System - assembles, stores, manipulates, and displays geographically-referenced data; think information retrieval, topological modeling, map overlays, and algorithms like shortest-path routing',
              'Web Applications (online ordering, hotel booking, job application, pre-enrollment) - each needs an actual host company or client to be acceptable',
              'Artificial Intelligence - expert systems, neural networks, robotics, or intelligent agents',
            ],
          ),
          ManualTopic(
            title: 'Multimedia & Learning Systems',
            subtitle: 'What reviewers look for in these two areas',
            items: [
              'Multimedia System - incorporate at least 4 media types (text, graphics, audio, video), maintenance features for dynamic content, and a database for storing the media',
              'Multimedia System - define your users and user levels (e.g. administrator vs. viewer), plus search, save, and print functions, and respect copyright on every asset you use',
              'Computer-Aided Instruction (CAI) - fits one clear category: drills & practice, tutorials, simulation, or games',
              'Computer-Aided Instruction (CAI) - presents its topic through 2-3 methods, targets a specific age bracket, and includes at least 50 test items per topic with randomized generation and performance feedback',
              'CAI projects use storyboards, flowcharts, or HIPO for design - data flow diagrams are not accepted for modeling a CAI\'s features and functions',
            ],
          ),
          ManualTopic(
            title: 'Web Application Projects',
            subtitle: 'General rules, plus the 4 pre-approved project types',
            content:
                'On top of the multimedia requirements above, a web app needs '
                'dynamic pages backed by a database, standards-compliant markup '
                'with clear navigation, a search engine, report generation, meta '
                'tags and hyperlinks, an e-consultation feature (a bulletin '
                'board, message board, or email inquiry), and proper security.',
            items: [
              'Online Ordering System with Inventory Management - a real host company, a product catalog, inventory monitoring, order approval/cancellation, and a FAQ module',
              'Online Hotel Reservation & Billing System - a real host hotel, interactive location maps, facility listings, and online reservation approval/cancellation',
              'Online Job Application System - a real host company, at least 100 applicants and 10 job postings, an applicant tracker, and a job-fit assessment feature',
              'Online Registration System (Pre-Enrollment) - tertiary schools only, with online registration, assessment, curriculum tracking, and class scheduling',
              'All four need an actual host company or school willing to use the system - a web app without a real client isn\'t acceptable',
            ],
          ),
          ManualTopic(
            title: 'AI & Other Research Areas',
            subtitle: 'Artificial intelligence, engineering, and networking',
            items: [
              'Expert Systems - mimic a human expert\'s decisions; need a database, a dialogue module, an inference engine, and a knowledge acquisition technique',
              'Neural Networks - modeled after biological neurons to simulate how the brain learns and remembers',
              'Robotics - integrates computers with industrial robots, often for unmanned assembly lines',
              'Intelligent Agents and ICAI (Intelligent Computer-Aided Instruction) are also accepted AI focuses',
              'Software Engineering - new programming paradigms, cost models, or systems software such as operating systems, compilers, and interpreters',
              'Systems Analysis & Design - an automated tool that combines both the process and data views of a system',
              'Networking - focuses on network topology implementation',
              'Information Research Management - an information systems plan for an organization',
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
                'team can realistically finish on time at that size. '
                'Multidisciplinary teams are welcome too, as long as each '
                'member documents their own program\'s part separately.',
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
              'Keep informed of the Capstone Project guidelines and policies',
              'Keep informed of the schedule of activities, deliverables, and deadlines posted by your adviser and dean',
              'Submit on time every deliverable specified in the manual, plus anything else your adviser or dean specifies',
              'Submit on time any requirement identified by the Oral Defense Panel during your defense',
              'Submit on time any requirement identified by your adviser throughout the project',
              'Schedule regular meetings with your adviser - at least once a month, and always through a proper appointment',
              'Schedule regular meetings with your dean - at least once a semester',
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
            subtitle: 'Composition',
            content:
                'Your panel has 1 chairman plus 2 members, and may include '
                'content experts or a recorder as needed.',
          ),
          ManualTopic(
            title: 'Adviser & Panel Qualifications',
            subtitle: 'Who\'s allowed to guide or evaluate you',
            items: [
              'Your adviser must have completed a computing project beyond their own bachelor\'s degree, and should be a full-time faculty member - otherwise a full-time co-adviser is required',
              'Advisers and panel members need a degree in Computing or an allied field, or must be a domain expert in your project\'s area',
              'At least one panel member should hold a master\'s degree in computing or a related field; for IT specifically, at least one should have real industry experience',
              'Your adviser guides you through the whole project life cycle, including your defense and possible deployment',
              'To keep their attention spread reasonably: advisers handle at most 5 projects at a time (never more than 10), and panel members handle at most 10 projects at a time (never more than 20) in one semester',
              'If your project involves an external client, that organization should be represented as much as possible',
            ],
          ),
          ManualTopic(
            title: 'What Your Panel Does',
            subtitle: 'Their role in your defense',
            content:
                'The chairman and the two panel members have distinct jobs, '
                'but they act as one unit once a verdict is reached.',
            items: [
              'The chairman briefs you before the defense begins, and is the one who formally issues the final verdict',
              'A verdict is unanimous among all 3 panelists - once issued, it\'s final and irrevocable',
              'Panel members validate your adviser\'s endorsement, evaluate your deliverables, and recommend a verdict to the chairman',
              'Panel members also listen to and consider requests from your adviser or your team during the process',
              'Any panelist - chairman or member - can nominate a strong project for a Capstone Award',
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
              'Points out errors in your development, analysis, or documentation, and expects them fixed properly',
              'Reviews every deliverable before it goes to the panel',
              'Clarifies points during your Title Proposal and Oral Defense, and makes sure required revisions actually get incorporated',
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
            subtitle: 'A second presentation, separate from your panel defense',
            content:
                'On top of defending in front of your Adviser & Panel, your '
                'capstone must also be presented in a public forum - a separate '
                'requirement, not a repeat of the same defense.',
          ),
          ManualTopic(
            title: 'What Counts as a Public Forum',
            subtitle: 'Your options, from a school colloquium to a real conference',
            items: [
              'It can be an international, national, regional, or school-based conference, meeting, or seminar',
              'It must be announced and open to interested parties - not a closed, invitation-only session',
              'A school-based colloquium organized for this purpose is enough to satisfy the requirement on its own',
              'Presenting at an actual outside conference - such as the National Conference on IT Education (NCITE) of PSITE - is encouraged, though not required',
            ],
          ),
        ],
      ),
      ManualSection(
        number: '07',
        title: 'How You\'re Graded',
        subtitle: 'Grade breakdown and rubrics',
        topics: [
          ManualTopic(
            title: 'How It All Adds Up',
            subtitle: 'From individual rubrics to your one final grade',
            content:
                'Every panel member grades you using the same rubrics below - '
                'the Manuscript Rubric, plus the Software Rubric and Oral Exam '
                'Rubric in Capstone 2. Their scores are averaged into the '
                '"Panel Members" share of your grade. That share is then '
                'combined with your Adviser\'s Grade Rubric and your peer '
                'grade to produce your one final grade, using the percentages '
                'below.',
          ),
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
          ManualTopic(
            title: 'Adviser\'s Grade Rubric (30 pts)',
            subtitle: 'How your adviser\'s 30% share is broken down',
            items: [
              'Deliverables - 20 pts',
              'Attendance - 5 pts',
              'Journal entries / attitude / behavior - 5 pts',
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
            content:
                'A verdict is a unanimous decision by all 3 panel members. Once '
                'given, it\'s final and irrevocable. It\'s based on your '
                'proposal manuscript score.',
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
                'given, it\'s final. It\'s based on your lowest score between '
                'your Capstone Software and Oral Examination results.',
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
              'Preliminary pages - title page, adviser\'s recommendation sheet, dean\'s acceptance sheet, panel\'s approval sheet, acknowledgement, abstract, table of contents, list of tables, list of figures',
              'Chapter 1 - Introduction (project context, objectives, scope & limitations)',
              'Chapter 2 - Review of Related Literature/Systems',
              'Chapter 3 - Technical Background',
              'Chapter 4 - Methodology, Results & Discussion',
              'Chapter 5 - Conclusion & Recommendations',
              'References, Resource Persons, and Glossary',
              'Appendices A-J - work assignment, definition of terms, evaluation tools, user\'s manual, program listing, certifications, accomplished forms, and screen designs',
            ],
          ),
          ManualTopic(
            title: 'Chapter 1: Introduction, In Depth',
            subtitle: 'Project context, objectives, and the SMART test',
            content:
                'Project Context introduces the problem you\'re solving - at '
                'least two pages describing the existing situation, why it '
                'matters, and your justification for choosing it. Objectives '
                'split into one General Objective (a single paragraph) and '
                'several Specific Objectives that add up to it. Scope and '
                'Limitations states how far your prototype goes and what\'s '
                'outside your control, with each limitation justified.\n\n'
                'Your objectives are checked against SMART:',
            items: [
              'Specific - the problem is stated precisely, not in vague terms',
              'Measurable - you can check it with a research instrument, apparatus, or equipment',
              'Achievable - realistically solvable given your resources',
              'Realistic - your results come from real data, not manipulated to fit',
              'Time-Bound - every activity has a deadline; shorter is better',
            ],
          ),
          ManualTopic(
            title: 'Chapters 2 & 3: Literature and Technical Background',
            subtitle: 'What to research and document before you build',
            content:
                'Chapter 2 (Review of Related Literature/Systems) has two '
                'parts: Related Theories, leading with one anchor theory and '
                'supporting theories that elaborate it, properly cited; and '
                'Related Projects, an overview and inventory of similar '
                'existing systems, ideally in a comparative matrix with '
                'screenshots, covering 3 to 6 related studies.\n\n'
                'Chapter 3 (Technical Background) discusses the hardware, '
                'software, peopleware, and network involved - both in the '
                'current setup and in the technology you\'re proposing to use.',
          ),
          ManualTopic(
            title: 'Chapter 4: Methodology, In Depth',
            subtitle: 'The chapter worth the most points - what each part covers',
            content:
                'Chapter 4 is graded as its own rubric section worth 10 '
                'points, and it has eight parts:',
            items: [
              '4.1 Methodology - the formal, SDLC-based method you\'ll follow to meet your objectives',
              '4.2 Environment - locale, population, and organizational chart (only for projects built for a specific organization)',
              '4.3 Requirements Specification - feasibility studies (operational, technical, schedule, economic), requirements modeling with a Gantt chart plus either data-flow diagrams/flowcharts or UML diagrams (use case, class, sequence, activity), and a risk assessment',
              '4.4 Design - UI design (colors, typography, icons), data design (ERD and data dictionary), and system architecture (network model, topology, security)',
              '4.5 Development - software/hardware/program specifications, front-end and back-end environment, a deployment diagram, and your test plan',
              '4.6 Verification, Validation, Testing - unit testing, integration testing (compatibility, performance, stress, load), system testing, and acceptance testing',
              '4.7 Implementation Plan - the physical environment, interfaces, functionality, data handling, and security your system needs once deployed',
              '4.8 Installation Processes - your changeover approach: immediate/direct, gradual step-by-step, or parallel',
            ],
          ),
          ManualTopic(
            title: 'Chapter 5 & the Appendices',
            subtitle: 'Closing your manuscript and what goes at the back',
            content:
                'Chapter 5 (Conclusion & Recommendations) states what your '
                'study accomplished, written against your objectives so every '
                'significant aspect is addressed - it may separate findings '
                'about your results from decisions about a course of action, '
                'numbered against your problems and sub-problems if that '
                'helps. Recommendations then point to future work: potential '
                'applications, other solutions, or enhancements building on '
                'what you built.\n\n'
                'After References, Resource Persons, and the Glossary, your '
                'appendices are lettered A through J (or further):',
            items: [
              'Appendix A: Work Assignment - each member\'s actual involvement and participation in the project',
              'Appendix B: Definition of Terms',
              'Appendix C: Evaluation Tool or Test Documents',
              'Appendix D: User\'s Manual - sample screens with their descriptions, task instructions, and a full walkthrough of the system\'s usage',
              'Appendix E: Program Listing - a printed copy of every program, module, function, and procedure you wrote',
              'Appendix F: Certifications - Certificate of Interview, Certificate to Use the Company\'s Data/Information, and Certificate of Acceptance',
              'Appendix G: Accomplished Forms',
              'Appendix H: Screen Design - one entry per screen, each following "Screen No.", "Screen Name", "Narrative Overview" (what the screen does), and "Screen Layout" (the actual design)',
              'Appendix I/J and beyond: anything else relevant - transcripts of interviews, survey forms/questionnaires, data-gathering photos, and a one-page Curriculum Vitae per member',
            ],
          ),
          ManualTopic(
            title: 'Bibliography & Reference Formats',
            subtitle: 'The exact template for each source type',
            content:
                'In-text citations use the author\'s first 4 letters plus '
                'year, like [MILL1991] - a second Miller source from the same '
                'year becomes [MILL1991a], a third [MILL1991b]. Never use '
                'traditional footnoting. Your Bibliography then spells each '
                'one out in full using the matching format below:',
            items: [
              'Book - Author (Year). Book Title, City of publication: Publisher. e.g. J M Chiclov (1986). An Introduction to Distributed and Parallel Computing, Hemel Hempstead: Prentice-Hall International (UK), Ltd.',
              'Journal - Author (Year). \'Article title\', Journal Title, volume(issue), pages. e.g. J C M Baeten & J A Bergstra (1988). \'Global Renaming Operators in Concrete Process Algebra\', Information and Computation, 78(3), pp 205-245.',
              'Conference - Author (Year). \'Article title\', In: Conference Name (editors, ed), pages. City: Publisher. e.g. D H E Park (1981). \'Concurrency and Automata on Infinite Sequences\', In: Fifth GI Conference (P Deussen, ed), pp 167-183. Berlin: Springer-Verlag.',
              'World Wide Web - Author (Year). \'Homepage title\'. URL. e.g. J Cruz (1996). \'The Home Page of Juan De La Cruz\'. http://dlsu.edu.ph/aguinaldo.',
            ],
          ),
          ManualTopic(
            title: 'Formatting Standards',
            subtitle: 'The exact layout rules',
            content:
                'Upload your .docx to the app\'s Paper Checker feature to have all '
                'of this verified automatically.',
            items: [
              'Paper: 8.5 x 11 inches, portrait orientation (except for special diagrams), Substance 20 bond paper',
              'Margins: 1" top, 1.5" left, 1" right, 1" bottom, 0.5" header & footer',
              'Line spacing: 1.5, with 1" paragraph indentation',
              'Font: Times New Roman - 11pt body text, 12pt headings',
              'Page numbers: bottom right, no extra characters, hidden on the first page of each chapter',
              'New chapters always start on a new page - page breaks are used only when a chapter begins',
              'Sub-headings follow decimal numbering (e.g. 2.0, then 2.1, then 2.1.1) and indent progressively under their parent heading',
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
            items: [
              'Tables and figures are captioned "Table <chapter>-<number> <Caption>" or "Figure <chapter>-<number> <Caption>" (e.g. Table 3-1, Figure 2-2), each listed on a bold, size-14 List of Tables / List of Figures page',
            ],
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
                'publish, or even commercialize it afterward, including '
                'registering your own copyrights, patents, or trademarks. The '
                'school won\'t claim financial rights unless you agree to that '
                'in writing.',
            items: [
              'The college may still archive, display, or demonstrate your project - and use its screenshots or description in official publications - as long as you\'re properly credited',
              'A project built with an industry partner, government agency, or other external organization follows a separate Memorandum of Agreement instead - you must be informed in writing of any different terms before approval',
              'Any third-party library, API, dataset, image, or other material you use must be properly licensed and cited - violating someone else\'s intellectual property is on you, not the school',
              'A system that handles sensitive, proprietary, or personal data must comply with the Data Privacy Act of 2012 (RA 10173) - don\'t disclose confidential information without authorization',
              'Any public presentation, deployment, or publication of your project must credit Dominican College of Tarlac, the College of Computer Studies, and your academic program',
            ],
          ),
          ManualTopic(
            title: 'If Your Adviser or Panel Contributed Directly',
            subtitle: 'Co-authorship rules',
            content:
                'If an adviser or panelist did real technical or creative work '
                'beyond just supervising - not just consultation - they\'re '
                'considered a co-author and must be credited in all official '
                'outputs.',
            items: [
              'Advisers and faculty contributors are also granted the right to use your project and its outputs for legitimate academic purposes - instruction, research, publication, presentation, accreditation, training, and professional development',
              'That academic use has to stay non-commercial and must credit you and the institution properly - unless a separate written agreement says otherwise',
            ],
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
            items: [
              'Beyond plagiarism, fabricating data or results, misrepresenting what your system actually does, using AI or automated tools in ways that violate course rules, or submitting tampered documents all count as academic anomalies too',
              'A low similarity score doesn\'t automatically clear you - the Research Office can still investigate if something looks intentionally copied',
              'If you\'re accused of a violation, you\'re entitled to due process: written notice, a chance to respond, and a decision based on documented evidence',
              'Your adviser and panel share this responsibility too - they\'re expected to guide you on proper citation and originality, and to report suspected violations rather than let them slide',
            ],
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
            constraints: const BoxConstraints(maxWidth: AppContentWidth.reading),
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
