import 'package:flutter/material.dart';

import '../app_colors.dart';

// Capstone manual home page.
// Edit the sections/topics below to change the manual content.
class CapstoneManualScreen extends StatelessWidget {
  const CapstoneManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Manual content is intentionally stored as simple Dart objects.
    // Your group can edit titles, subtitles, and content here without Firebase.
    final sections = [
      ManualSection(
        number: '01',
        title: 'Introduction',
        subtitle: 'Overview and purpose',
        topics: [
          ManualTopic(
            title: 'What is a capstone project?',
            subtitle: 'What it is, and why you are doing it',
            content:
                'Write your explanation here. This is the template area for the Introduction topic.',
          ),
          ManualTopic(
            title: 'Scope of the project',
            subtitle: 'How big or small it should be',
            content:
                'Write scope rules here. You can add bullet points, examples, or school requirements.',
          ),
          ManualTopic(
            title: 'Suggested project areas',
            subtitle: 'Ideas you are allowed to build',
            content:
                'Use this page for accepted project areas and not-allowed topics.',
            items: [
              'Software development - Custom systems, web apps, mobile apps',
              'Multimedia systems - Games, e-learning, interactive systems',
              'Network / server - Network design and server setup',
              'IT management - IT plans, security analysis, implementation',
              'Not allowed - DAMATH, video rental, non-educational games, simple record keeping',
            ],
          ),
        ],
      ),
      ManualSection(
        number: '02',
        title: 'Objectives',
        subtitle: 'Goals and outcomes',
        topics: [
          ManualTopic(
            title: 'General objective',
            subtitle: 'Main goal of the project',
            content: 'Write the general objective template here.',
          ),
          ManualTopic(
            title: 'Specific objectives',
            subtitle: 'Smaller goals to complete',
            content: 'Write the specific objectives template here.',
          ),
        ],
      ),
      ManualSection(
        number: '03',
        title: 'Scope and Limitations',
        subtitle: 'Boundaries and constraints',
        topics: [
          ManualTopic(
            title: 'Scope',
            subtitle: 'Included features and users',
            content: 'Write scope details here.',
          ),
          ManualTopic(
            title: 'Limitations',
            subtitle: 'What the project will not cover',
            content: 'Write limitations here.',
          ),
        ],
      ),
      ManualSection(
        number: '04',
        title: 'Guidelines and Procedures',
        subtitle: 'Rules and submission steps',
        topics: [
          ManualTopic(
            title: 'Submission rules',
            subtitle: 'Files and deadlines',
            content: 'Write submission rules here.',
          ),
          ManualTopic(
            title: 'Documentation format',
            subtitle: 'Formatting requirements',
            content: 'Write documentation format here.',
          ),
        ],
      ),
      ManualSection(
        number: '05',
        title: 'Defense Preparation',
        subtitle: 'Presentation tips and format',
        topics: [
          ManualTopic(
            title: 'Presentation flow',
            subtitle: 'Recommended order of discussion',
            content: 'Write presentation flow here.',
          ),
          ManualTopic(
            title: 'Common panel questions',
            subtitle: 'Questions to prepare for',
            content: 'Write common questions here.',
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Capstone Manual'),
      ),
      body: StudentListBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TextField(
              decoration: InputDecoration(
                hintText: 'Search manual...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const SectionLabel('CONTENTS'),
            const SizedBox(height: 8),
            for (final section in sections)
              ManualCard(
                number: section.number,
                title: section.title,
                subtitle:
                    '${section.subtitle} - ${section.topics.length} topics',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManualTopicListScreen(section: section),
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

class ManualTopicListScreen extends StatelessWidget {
  // Shows the topic list inside one manual section.
  const ManualTopicListScreen({super.key, required this.section});

  final ManualSection section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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

class ManualDetailScreen extends StatelessWidget {
  // Shows one topic's template/content.
  // Replace topic.content and topic.items in the section list above.
  const ManualDetailScreen({super.key, required this.topic});

  final ManualTopic topic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(topic.title),
      ),
      body: StudentListBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      topic.subtitle,
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                    const Divider(height: 28),
                    Text(topic.content),
                  ],
                ),
              ),
            ),
            if (topic.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final item in topic.items)
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(title: Text(item)),
                ),
            ],
          ],
        ),
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
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textGrey,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary,
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
          style: const TextStyle(color: AppColors.textGrey),
        ),
        trailing: const Icon(Icons.chevron_right),
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
    required this.content,
    this.items = const [],
  });

  final String title;
  final String subtitle;
  final String content;
  final List<String> items;
}
