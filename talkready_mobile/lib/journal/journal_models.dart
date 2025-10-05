// journal_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Enhanced JournalEntry model with media support
class JournalEntry {
  final String mood;
  final String? tagId;
  final String? tagName;
  final String title;
  final String content;
  final DateTime timestamp;
  bool isFavorite;
  final String? id;
  final List<MediaAttachment>? mediaAttachments;
  final String? templateId;
  final bool isDraft;
  final DateTime? lastModified;

  JournalEntry({
    required this.mood,
    this.tagId,
    this.tagName,
    required this.title,
    required this.content,
    required this.timestamp,
    this.isFavorite = false,
    this.id,
    this.mediaAttachments,
    this.templateId,
    this.isDraft = false,
    this.lastModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'mood': mood,
      'tagId': tagId,
      'tagName': tagName,
      'title': title,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFavorite': isFavorite,
      'mediaAttachments': mediaAttachments?.map((m) => m.toMap()).toList(),
      'templateId': templateId,
      'isDraft': isDraft,
      'lastModified': lastModified != null ? Timestamp.fromDate(lastModified!) : null,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map, String id) {
    return JournalEntry(
      id: id,
      mood: map['mood'] ?? 'Not specified',
      tagId: map['tagId'],
      tagName: map['tagName'] ?? 'Not specified',
      title: map['title'] ?? '',
      content: map['content'] ?? '{}',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isFavorite: map['isFavorite'] ?? false,
      mediaAttachments: (map['mediaAttachments'] as List<dynamic>?)
          ?.map((m) => MediaAttachment.fromMap(m))
          .toList(),
      templateId: map['templateId'],
      isDraft: map['isDraft'] ?? false,
      lastModified: map['lastModified'] != null
          ? (map['lastModified'] as Timestamp).toDate()
          : null,
    );
  }

  JournalEntry copyWith({
    String? mood,
    String? tagId,
    String? tagName,
    String? title,
    String? content,
    DateTime? timestamp,
    bool? isFavorite,
    String? id,
    List<MediaAttachment>? mediaAttachments,
    String? templateId,
    bool? isDraft,
    DateTime? lastModified,
  }) {
    return JournalEntry(
      mood: mood ?? this.mood,
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      title: title ?? this.title,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
      id: id ?? this.id,
      mediaAttachments: mediaAttachments ?? this.mediaAttachments,
      templateId: templateId ?? this.templateId,
      isDraft: isDraft ?? this.isDraft,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

// Media attachment model
class MediaAttachment {
  final String id;
  final MediaType type;
  final String url;
  final String? thumbnailUrl;
  final String? caption;
  final DateTime uploadedAt;

  MediaAttachment({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.caption,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  factory MediaAttachment.fromMap(Map<String, dynamic> map) {
    return MediaAttachment(
      id: map['id'],
      type: MediaType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => MediaType.image,
      ),
      url: map['url'],
      thumbnailUrl: map['thumbnailUrl'],
      caption: map['caption'],
      uploadedAt: (map['uploadedAt'] as Timestamp).toDate(),
    );
  }
}

enum MediaType { image, voice, drawing }

// Journal template model
class JournalTemplate {
  final String id;
  final String name;
  final String description;
  final List<TemplateSection> sections;
  final String icon;

  JournalTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.sections,
    required this.icon,
  });
}

class TemplateSection {
  final String title;
  final String prompt;
  final String? placeholder;

  TemplateSection({
    required this.title,
    required this.prompt,
    this.placeholder,
  });
}

// Predefined templates
class JournalTemplates {
  static final List<JournalTemplate> templates = [
    JournalTemplate(
      id: 'gratitude',
      name: 'Gratitude Journal',
      description: 'Focus on the positive things in your life',
      icon: '🙏',
      sections: [
        TemplateSection(
          title: 'Three Good Things',
          prompt: 'What are three things you\'re grateful for today?',
          placeholder: '1. \n2. \n3. ',
        ),
        TemplateSection(
          title: 'Why They Matter',
          prompt: 'Why did these things make a difference?',
          placeholder: 'Reflect on the impact...',
        ),
      ],
    ),
    JournalTemplate(
      id: 'daily_reflection',
      name: 'Daily Reflection',
      description: 'Review your day and plan ahead',
      icon: '🌅',
      sections: [
        TemplateSection(
          title: 'Today\'s Highlights',
          prompt: 'What were the best moments of today?',
        ),
        TemplateSection(
          title: 'Challenges',
          prompt: 'What challenges did you face?',
        ),
        TemplateSection(
          title: 'Lessons Learned',
          prompt: 'What did you learn today?',
        ),
        TemplateSection(
          title: 'Tomorrow\'s Goals',
          prompt: 'What do you want to achieve tomorrow?',
        ),
      ],
    ),
    JournalTemplate(
      id: 'goal_tracking',
      name: 'Goal Progress',
      description: 'Track your progress toward goals',
      icon: '🎯',
      sections: [
        TemplateSection(
          title: 'Current Goal',
          prompt: 'What goal are you working on?',
        ),
        TemplateSection(
          title: 'Actions Taken',
          prompt: 'What steps did you take today?',
        ),
        TemplateSection(
          title: 'Obstacles',
          prompt: 'What got in your way?',
        ),
        TemplateSection(
          title: 'Next Steps',
          prompt: 'What will you do next?',
        ),
      ],
    ),
    JournalTemplate(
      id: 'mood_tracker',
      name: 'Mood Check-in',
      description: 'Understand your emotional patterns',
      icon: '💭',
      sections: [
        TemplateSection(
          title: 'How I Feel',
          prompt: 'Describe your mood right now',
        ),
        TemplateSection(
          title: 'What Triggered It',
          prompt: 'What events or thoughts influenced this mood?',
        ),
        TemplateSection(
          title: 'Coping Strategies',
          prompt: 'What helped or could help you feel better?',
        ),
      ],
    ),
    JournalTemplate(
      id: 'creative_writing',
      name: 'Creative Expression',
      description: 'Free-form creative writing',
      icon: '✍️',
      sections: [
        TemplateSection(
          title: 'Story/Poem/Thoughts',
          prompt: 'Let your creativity flow...',
          placeholder: 'Write freely without judgment...',
        ),
      ],
    ),
  ];

  static JournalTemplate? getTemplateById(String id) {
    try {
      return templates.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}

// Better prompt responses
class JournalPrompts {
  static final Map<String, List<String>> prompts = {
    "What's on my mind right now?": [
      "Right now, I'm thinking about...",
      "My mind keeps returning to...",
      "I can't stop wondering about...",
    ],
    "What do I need to hear today?": [
      "You're stronger than you think, and you're doing the best you can.",
      "It's okay to take things one step at a time.",
      "Your feelings are valid, and it's okay to not be okay sometimes.",
    ],
    "3 things I want to appreciate today": [
      "1. The small moments that made me smile\n2. The people who support me\n3. My own resilience",
      "1. \n2. \n3. ",
    ],
    "A quote to live by?": [
      "Find a quote that resonates with your current journey...",
      "What words of wisdom guide you right now?",
    ],
    "What can I improve today?": [
      "One thing I could do better tomorrow is...",
      "I noticed I struggled with... and I could try...",
    ],
    "Five things you would like to do more": [
      "1. \n2. \n3. \n4. \n5. ",
      "Activities that would enrich my life:",
    ],
  };

  static String getRandomResponse(String prompt) {
    final responses = prompts[prompt] ?? ["Start writing..."];
    return responses[DateTime.now().millisecond % responses.length];
  }
}