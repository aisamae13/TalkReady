// journal_stats_page.dart
import 'package:flutter/material.dart';
import 'journal_models.dart';
import 'dart:convert';
import 'dart:math';

class JournalStatsPage extends StatelessWidget {
  final List<JournalEntry> entries;

  const JournalStatsPage({super.key, required this.entries});

  Map<String, dynamic> _calculateStats() {
    if (entries.isEmpty) {
      return {
        'totalEntries': 0,
        'currentStreak': 0,
        'longestStreak': 0,
        'averageWordCount': 0,
        'moodDistribution': {},
        'tagDistribution': {},
        'entriesByMonth': {},
        'favoriteCount': 0,
        'mostProductiveDay': 'N/A',
      };
    }

    // Sort entries by date
    final sortedEntries = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Calculate streaks
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;
    DateTime? lastDate;

    for (var entry in sortedEntries.reversed) {
      if (entry.isDraft) continue;

      final entryDate = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );

      if (lastDate == null) {
        tempStreak = 1;
      } else {
        final difference = entryDate.difference(lastDate).inDays;
        if (difference == 1) {
          tempStreak++;
        } else if (difference > 1) {
          longestStreak = max(longestStreak, tempStreak);
          tempStreak = 1;
        }
      }
      lastDate = entryDate;
    }

    longestStreak = max(longestStreak, tempStreak);

    // Check if current streak is active
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final daysSinceLastEntry = lastDate != null
        ? todayDate.difference(lastDate).inDays
        : 999;

    currentStreak = (daysSinceLastEntry <= 1) ? tempStreak : 0;

    // Calculate average word count
    int totalWords = 0;
    final nonDraftEntries = entries.where((e) => !e.isDraft).toList();
    for (var entry in nonDraftEntries) {
      try {
        final content = jsonDecode(entry.content);
        final text = content['text'] ?? '';
        totalWords += RegExp(r'\S+').allMatches(text).length;
      } catch (e) {
        // Skip malformed entries
      }
    }
    final avgWordCount = nonDraftEntries.isNotEmpty
        ? (totalWords / nonDraftEntries.length).round()
        : 0;

    // Mood distribution
    Map<String, int> moodDist = {};
    for (var entry in nonDraftEntries) {
      if (entry.mood != 'Not specified') {
        moodDist[entry.mood] = (moodDist[entry.mood] ?? 0) + 1;
      }
    }

    // Tag distribution
    Map<String, int> tagDist = {};
    for (var entry in nonDraftEntries) {
      if (entry.tagName != null && entry.tagName != 'Not specified') {
        tagDist[entry.tagName!] = (tagDist[entry.tagName!] ?? 0) + 1;
      }
    }

    // Entries by month (last 6 months)
    Map<String, int> entriesByMonth = {};
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = _getMonthName(month.month).substring(0, 3);
      entriesByMonth[monthKey] = 0;
    }

    for (var entry in nonDraftEntries) {
      final monthKey = _getMonthName(entry.timestamp.month).substring(0, 3);
      if (entriesByMonth.containsKey(monthKey)) {
        entriesByMonth[monthKey] = (entriesByMonth[monthKey] ?? 0) + 1;
      }
    }

    // Favorite count
    final favoriteCount = nonDraftEntries.where((e) => e.isFavorite).length;

    // Most productive day of week
    Map<int, int> dayCount = {};
    for (var entry in nonDraftEntries) {
      final day = entry.timestamp.weekday;
      dayCount[day] = (dayCount[day] ?? 0) + 1;
    }
    int? mostProductiveDay = dayCount.isNotEmpty
        ? dayCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : null;

    return {
      'totalEntries': nonDraftEntries.length,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'averageWordCount': avgWordCount,
      'moodDistribution': moodDist,
      'tagDistribution': tagDist,
      'entriesByMonth': entriesByMonth,
      'favoriteCount': favoriteCount,
      'mostProductiveDay': mostProductiveDay != null
          ? _getDayName(mostProductiveDay)
          : 'N/A',
    };
  }

  String _getMonthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May',
                    'June', 'July', 'August', 'September', 'October',
                    'November', 'December'];
    return months[month];
  }

  String _getDayName(int day) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
                  'Friday', 'Saturday', 'Sunday'];
    return days[day];
  }

  String _getMoodEmoji(String mood) {
    const moods = {
      'Rad': '😎',
      'Happy': '😄',
      'Meh': '😐',
      'Sad': '😢',
      'Angry': '😠',
    };
    return moods[mood] ?? '❓';
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    final moodDist = stats['moodDistribution'] as Map<String, int>;
    final tagDist = stats['tagDistribution'] as Map<String, int>;
    final entriesByMonth = stats['entriesByMonth'] as Map<String, int>;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFEDEBE9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF605E5C)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Journal Insights',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF252423),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Content
            Expanded(
              child: stats['totalEntries'] == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 64,
                            color: const Color(0xFF8A8886),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No stats yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF605E5C),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start journaling to see insights',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8A8886),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overview Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  '${stats['totalEntries']}',
                                  'Total Entries',
                                  Icons.library_books,
                                  const Color(0xFF0078D4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  '${stats['currentStreak']}',
                                  'Day Streak',
                                  Icons.local_fire_department,
                                  const Color(0xFFE74856),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  '${stats['longestStreak']}',
                                  'Longest Streak',
                                  Icons.trending_up,
                                  const Color(0xFF10893E),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  '${stats['averageWordCount']}',
                                  'Avg Words',
                                  Icons.format_size,
                                  const Color(0xFF8661C5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Activity Chart
                          const Text(
                            'Writing Activity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF252423),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildActivityChart(entriesByMonth),
                          const SizedBox(height: 24),

                          // Mood Distribution
                          if (moodDist.isNotEmpty) ...[
                            const Text(
                              'Mood Distribution',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF252423),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildMoodDistribution(moodDist),
                            const SizedBox(height: 24),
                          ],

                          // Top Tags
                          if (tagDist.isNotEmpty) ...[
                            const Text(
                              'Most Used Tags',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF252423),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTopTags(tagDist),
                            const SizedBox(height: 24),
                          ],

                          // Additional Stats
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F2F1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _buildStatRow(
                                  'Favorite Entries',
                                  '${stats['favoriteCount']}',
                                  Icons.favorite,
                                ),
                                const Divider(height: 24),
                                _buildStatRow(
                                  'Most Productive Day',
                                  stats['mostProductiveDay'],
                                  Icons.calendar_today,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDEBE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Color(0xFF252423),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF605E5C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart(Map<String, int> data) {
    final maxValue = data.values.isEmpty ? 1 : data.values.reduce(max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDEBE9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.entries.map((entry) {
          final height = maxValue > 0 ? (entry.value / maxValue) * 100 : 0.0;
          return Column(
            children: [
              Text(
                '${entry.value}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF605E5C),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: height < 20 ? 20 : height,
                decoration: BoxDecoration(
                  color: const Color(0xFF0078D4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A8886),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMoodDistribution(Map<String, int> moodDist) {
    final sortedMoods = moodDist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDEBE9)),
      ),
      child: Column(
        children: sortedMoods.map((entry) {
          final total = moodDist.values.reduce((a, b) => a + b);
          final percentage = ((entry.value / total) * 100).round();

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  _getMoodEmoji(entry.key),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF252423),
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF605E5C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: const Color(0xFFF3F2F1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0078D4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopTags(Map<String, int> tagDist) {
    final sortedTags = tagDist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTags = sortedTags.take(5).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: topTags.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0078D4).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0078D4).withOpacity(0.3)),
          ),
          child: Text(
            '${entry.key} (${entry.value})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0078D4),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF605E5C)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF605E5C),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF252423),
          ),
        ),
      ],
    );
  }
}