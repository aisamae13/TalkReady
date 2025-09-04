import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Helper function to convert raw criteria names into human-readable titles
String formatCriterionName(String rawName) {
  return rawName
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .replaceRange(0, 1, rawName[0].toUpperCase())
      .trim();
}

// Icon map to assign a specific icon to each criterion
class CriteriaIconMap {
  static const Map<String, IconData> iconMap = {
    'acknowledgment': FontAwesomeIcons.headphones,
    'empathy': FontAwesomeIcons.solidHeart,
    'verification': FontAwesomeIcons.userCheck,
    'solutionClarity_Billing': FontAwesomeIcons.lightbulb,
    'solutionClarity_Internet': FontAwesomeIcons.lightbulb,
    'expectationSetting': FontAwesomeIcons.solidStar,
    'closingPhrase': FontAwesomeIcons.phoneSlash,
    'offerFurtherAssistance': FontAwesomeIcons.questionCircle,
    'professionalFarewell': FontAwesomeIcons.phoneSlash,
  };

  static const Map<String, Color> colorMap = {
    'acknowledgment': Colors.blue,
    'empathy': Colors.pink,
    'verification': Colors.teal,
    'solutionClarity_Billing': Colors.orange,
    'solutionClarity_Internet': Colors.orange,
    'expectationSetting': Colors.orange,
    'closingPhrase': Colors.grey,
    'offerFurtherAssistance': Colors.purple,
    'professionalFarewell': Colors.grey,
  };

  static IconData getIcon(String criterion) {
    return iconMap[criterion] ?? FontAwesomeIcons.comment;
  }

  static Color getColor(String criterion) {
    return colorMap[criterion] ?? Colors.grey;
  }
}

class CriteriaItem {
  final String criterion;
  final String evaluation;
  final bool met;

  const CriteriaItem({
    required this.criterion,
    required this.evaluation,
    required this.met,
  });

  factory CriteriaItem.fromMap(Map<String, dynamic> map) {
    return CriteriaItem(
      criterion: map['criterion'] as String? ?? '',
      evaluation: map['evaluation'] as String? ?? '',
      met: map['met'] as bool? ?? false,
    );
  }
}

class UnscriptedFeedback {
  final List<CriteriaItem> criteriaBreakdown;
  final String? overallFeedback;

  const UnscriptedFeedback({
    required this.criteriaBreakdown,
    this.overallFeedback,
  });

  factory UnscriptedFeedback.fromMap(Map<String, dynamic> map) {
    return UnscriptedFeedback(
      criteriaBreakdown: (map['criteriaBreakdown'] as List<dynamic>?)
              ?.map((item) => CriteriaItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      overallFeedback: map['overallFeedback'] as String?,
    );
  }
}

// Widget for displaying unscripted feedback - this is what RolePlayScenarioQuestion will use
class UnscriptedFeedbackCard extends StatefulWidget {
  final UnscriptedFeedback? feedback;

  const UnscriptedFeedbackCard({
    super.key,
    required this.feedback,
  });

  @override
  State<UnscriptedFeedbackCard> createState() => _UnscriptedFeedbackCardState();
}

class _UnscriptedFeedbackCardState extends State<UnscriptedFeedbackCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.feedback == null || widget.feedback!.criteriaBreakdown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No detailed feedback is available for this response.',
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final feedback = widget.feedback!;
    final criteriaMet = feedback.criteriaBreakdown.where((item) => item.met).toList();
    final criteriaNotMet = feedback.criteriaBreakdown.where((item) => !item.met).toList();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.comment,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Performance Breakdown',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                      ),
                    ),
                  ],
                ),
                
                // Divider
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),

                // Overall Feedback
                if (feedback.overallFeedback != null && feedback.overallFeedback!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.indigo[200]!,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      feedback.overallFeedback!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo[900],
                          ),
                    ),
                  ),
                ],

                // Strengths Section
                if (criteriaMet.isNotEmpty) ...[
                  Text(
                    'Strengths (Criteria Met)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildCriteriaList(criteriaMet, true),
                  const SizedBox(height: 24),
                ],

                // Areas for Improvement Section
                if (criteriaNotMet.isNotEmpty) ...[
                  Text(
                    'Areas for Improvement (Criteria Not Met)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildCriteriaList(criteriaNotMet, false),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCriteriaList(List<CriteriaItem> criteria, bool isPositive) {
    return Column(
      children: criteria.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 100 * (index + 1)),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(-10 * (1 - value), 0),
              child: Opacity(
                opacity: value,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPositive ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: isPositive ? Colors.green : Colors.red,
                        width: 4,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4, right: 16),
                        child: FaIcon(
                          CriteriaIconMap.getIcon(item.criterion),
                          color: isPositive 
                              ? Colors.green[600] 
                              : Colors.red[600],
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatCriterionName(item.criterion),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.evaluation,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

// Convenience widget that can handle both Map<String, dynamic> and UnscriptedFeedback objects
// This is what RolePlayScenarioQuestion will actually use
class UnscriptedFeedbackWidget extends StatelessWidget {
  final Map<String, dynamic>? feedbackData;

  const UnscriptedFeedbackWidget({
    super.key,
    required this.feedbackData,
  });

  @override
  Widget build(BuildContext context) {
    if (feedbackData == null) {
      return const UnscriptedFeedbackCard(feedback: null);
    }

    try {
      final feedback = UnscriptedFeedback.fromMap(feedbackData!);
      return UnscriptedFeedbackCard(feedback: feedback);
    } catch (e) {
      debugPrint('Error parsing unscripted feedback: $e');
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Error displaying feedback: ${e.toString()}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
  }
}