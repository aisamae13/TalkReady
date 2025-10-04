// pdf_generator_service.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class PdfGeneratorService {
  Future<void> generateProgressReportPdf({
    required Map<String, dynamic> overallStats,
    required Map<String, List<Map<String, dynamic>>> allUserAttempts,
    required List<Map<String, dynamic>> assessmentSubmissions,
    required String userName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(userName),
          pw.SizedBox(height: 20),
          _buildOverallStats(overallStats),
          pw.SizedBox(height: 20),
          _buildAssessmentsSummary(assessmentSubmissions),
          pw.SizedBox(height: 20),
          _buildLessonsTable(allUserAttempts),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildHeader(String userName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TalkReady Progress Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Student: $userName', style: const pw.TextStyle(fontSize: 14)),
        pw.Text(
          'Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  pw.Widget _buildOverallStats(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Overall Statistics', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Lessons Attempted', '${stats['attemptedLessonsCount']}'),
              _buildStatItem('Total Attempts', '${stats['totalAttempts']}'),
              _buildStatItem('Average Score', '${stats['averageScore']}${stats['averageScore'] == "N/A" ? "" : "%"}'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildAssessmentsSummary(List<Map<String, dynamic>> submissions) {
    final reviewed = submissions.where((s) => s['isReviewed'] == true).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Trainer Assessments', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Total Submissions: ${submissions.length}'),
        pw.Text('Reviewed: ${reviewed.length}'),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: ['Assessment', 'Score', 'Date'],
          data: submissions.take(10).map((s) {
            final score = s['score'] ?? 0;
            final total = s['totalPossiblePoints'] ?? 100;
            final date = _formatDate(s['submittedAt']);
            return [s['assessmentTitle'] ?? 'Assessment', '$score/$total', date];
          }).toList(),
        ),
      ],
    );
  }

  pw.Widget _buildLessonsTable(Map<String, List<Map<String, dynamic>>> attempts) {
    final lessons = attempts.entries.map((entry) {
      final bestScore = entry.value.map((a) {
        final score = (a['score'] as num?)?.toDouble() ?? 0;
        final max = _getMaxScore(a);
        return max > 0 ? (score / max * 100) : 0.0;
      }).reduce(math.max);

      return [
        _getLessonTitle(entry.key),
        '${entry.value.length}',
        '${bestScore.toStringAsFixed(1)}%',
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('AI Lessons Progress', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: ['Lesson', 'Attempts', 'Best Score'],
          data: lessons,
        ),
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    try {
      DateTime date = timestamp is Timestamp ? timestamp.toDate() : timestamp as DateTime;
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  double _getMaxScore(Map<String, dynamic> attempt) {
    if (attempt['maxScore'] != null) return (attempt['maxScore'] as num).toDouble();
    const scores = {'Lesson-1-1': 7.0, 'Lesson-1-2': 5.0, 'Lesson-1-3': 11.0};
    return scores[attempt['lessonId']] ?? 100.0;
  }

  String _getLessonTitle(String lessonId) {
    // Use your existing lesson title lookup logic
    return lessonId;
  }
}