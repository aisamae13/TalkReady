import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ScoreStyling {
  final Color barColor;
  final Color textColor;

  const ScoreStyling({
    required this.barColor,
    required this.textColor,
  });
}

ScoreStyling getScoreStyling(double? score) {
  if (score == null) {
    return const ScoreStyling(
      barColor: Colors.grey,
      textColor: Colors.grey,
    );
  }
  
  if (score >= 90) {
    return ScoreStyling(
      barColor: Colors.green.shade500,
      textColor: Colors.green.shade600,
    );
  }
  if (score >= 75) {
    return ScoreStyling(
      barColor: Colors.lime.shade500,
      textColor: Colors.lime.shade600,
    );
  }
  if (score >= 60) {
    return ScoreStyling(
      barColor: Colors.yellow.shade400,
      textColor: Colors.yellow.shade600,
    );
  }
  if (score >= 40) {
    return ScoreStyling(
      barColor: Colors.orange.shade500,
      textColor: Colors.orange.shade600,
    );
  }
  
  return ScoreStyling(
    barColor: Colors.red.shade500,
    textColor: Colors.red.shade600,
  );
}

class DetailedFeedback extends StatefulWidget {
  final String metric;
  final double? score;
  final String? whatItMeasures;
  final String? whyThisScore;
  final String? tip;

  const DetailedFeedback({
    super.key,
    required this.metric,
    this.score,
    this.whatItMeasures,
    this.whyThisScore,
    this.tip,
  });

  @override
  State<DetailedFeedback> createState() => _DetailedFeedbackState();
}

class _DetailedFeedbackState extends State<DetailedFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: (widget.score ?? 0) / 100,
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
    final styling = getScoreStyling(widget.score);
    final scoreText = widget.score?.toStringAsFixed(0);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with metric name and score
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.metric,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                    ),
                  ),
                  if (widget.score != null)
                    Text(
                      '$scoreText%',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: styling.textColor,
                          ),
                    ),
                ],
              ),

              // Progress bar
              if (widget.score != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: _progressAnimation.value,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(styling.barColor),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Explanation section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.whatItMeasures != null && widget.whatItMeasures!.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2, right: 8),
                          child: FaIcon(
                            FontAwesomeIcons.infoCircle,
                            color: Colors.blue.shade500,
                            size: 14,
                          ),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                              children: [
                                TextSpan(
                                  text: 'What it measures: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                TextSpan(text: widget.whatItMeasures),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (widget.whyThisScore != null && widget.whyThisScore!.isNotEmpty) ...[
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        children: [
                          TextSpan(
                            text: 'Why this score: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          TextSpan(text: widget.whyThisScore),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Tip section
              if (widget.tip != null && widget.tip!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    border: Border(
                      left: BorderSide(
                        color: Colors.yellow.shade400,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 12),
                        child: FaIcon(
                          FontAwesomeIcons.lightbulb,
                          color: Colors.yellow.shade500,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tip for Improvement',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.yellow.shade800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.tip!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.yellow.shade700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Alternative simpler version without animations if preferred
class SimpleDetailedFeedback extends StatelessWidget {
  final String metric;
  final double? score;
  final String? whatItMeasures;
  final String? whyThisScore;
  final String? tip;

  const SimpleDetailedFeedback({
    super.key,
    required this.metric,
    this.score,
    this.whatItMeasures,
    this.whyThisScore,
    this.tip,
  });

  @override
  Widget build(BuildContext context) {
    final styling = getScoreStyling(score);
    final scoreText = score?.toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    metric,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (score != null)
                  Text(
                    '$scoreText%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: styling.textColor,
                    ),
                  ),
              ],
            ),

            // Progress bar
            if (score != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: score! / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(styling.barColor),
                minHeight: 12,
              ),
              const SizedBox(height: 16),
            ],

            // Content
            if (whatItMeasures != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FaIcon(
                    FontAwesomeIcons.infoCircle,
                    color: Colors.blue,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black54),
                        children: [
                          const TextSpan(
                            text: 'What it measures: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: whatItMeasures),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            if (whyThisScore != null) ...[
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black54),
                  children: [
                    const TextSpan(
                      text: 'Why this score: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: whyThisScore),
                  ],
                ),
              ),
            ],

            // Tip section
            if (tip != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.lightbulb,
                      color: Colors.yellow.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tip for Improvement',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.yellow.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tip!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.yellow.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}