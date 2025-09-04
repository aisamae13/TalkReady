import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A helper function to determine styling for score bars
class ScoreStyling {
  final Color barColor;
  final Color textColor;
  
  ScoreStyling({required this.barColor, required this.textColor});
  
  static ScoreStyling getScoreStyling(double? score) {
    if (score == null) {
      return ScoreStyling(barColor: Colors.grey.shade300, textColor: Colors.grey.shade700);
    }
    if (score >= 90) {
      return ScoreStyling(barColor: Colors.green.shade500, textColor: Colors.green.shade600);
    }
    if (score >= 75) {
      return ScoreStyling(barColor: Colors.lime.shade500, textColor: Colors.lime.shade600);
    }
    if (score >= 60) {
      return ScoreStyling(barColor: Colors.amber.shade400, textColor: Colors.amber.shade600);
    }
    if (score >= 40) {
      return ScoreStyling(barColor: Colors.orange.shade500, textColor: Colors.orange.shade600);
    }
    return ScoreStyling(barColor: Colors.red.shade500, textColor: Colors.red.shade600);
  }
}

class FeedbackDisplay extends StatefulWidget {
  final Map<String, dynamic>? feedbackResult;
  
  const FeedbackDisplay({
    Key? key, 
    required this.feedbackResult,
  }) : super(key: key);

  @override
  _FeedbackDisplayState createState() => _FeedbackDisplayState();
}

class _FeedbackDisplayState extends State<FeedbackDisplay> with SingleTickerProviderStateMixin {
  String _activeTab = 'metrics';
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _changeTab(String tab) {
    if (_activeTab != tab) {
      setState(() {
        _activeTab = tab;
        _animationController.reset();
        _animationController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.feedbackResult == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No feedback available.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.indigo.shade400,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Detailed Analysis',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Tab Navigation
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildTabButton('metrics', 'Metrics', FontAwesomeIcons.clipboardCheck),
                _buildTabButton('words', 'Word-by-Word', FontAwesomeIcons.list),
              ],
            ),
          ),
          
          // Tab Content
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _opacityAnimation,
            child: _activeTab == 'metrics' ? _buildMetricsTab() : _buildWordsTab(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(String tabId, String label, IconData icon) {
    bool isActive = _activeTab == tabId;
    return InkWell(
      onTap: () => _changeTab(tabId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: isActive 
              ? Border(bottom: BorderSide(color: Colors.indigo.shade600, width: 4)) 
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.indigo.shade700 : Colors.grey.shade500,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.indigo.shade700 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricsTab() {
    final feedbackResult = widget.feedbackResult!;
    final textRecognized = feedbackResult['textRecognized'] as String? ?? "Speech not clearly recognized.";
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // What AI heard section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.shade100,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What the AI Heard:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"$textRecognized"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Metrics grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildMetricCard("Accuracy", feedbackResult['accuracyScore'] as double?, "%"),
            _buildMetricCard("Fluency", feedbackResult['fluencyScore'] as double?, ""),
            _buildMetricCard("Completeness", feedbackResult['completenessScore'] as double?, "%"),
            _buildMetricCard("Prosody", feedbackResult['prosodyScore'] as double?, ""),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMetricCard(String label, double? score, String suffix) {
    if (score == null) {
      return const SizedBox.shrink();
    }
    
    final styling = ScoreStyling.getScoreStyling(score);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                "${score.toInt()}$suffix",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: styling.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(styling.barColor),
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWordsTab() {
    final feedbackResult = widget.feedbackResult!;
    final words = feedbackResult['words'] as List<dynamic>? ?? [];
    
    return Container(
      height: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: words.isEmpty 
          ? const Center(child: Text('No word-level analysis available.'))
          : ListView.separated(
              shrinkWrap: true,
              itemCount: words.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade300),
              itemBuilder: (context, index) {
                final wordData = words[index] as Map<String, dynamic>;
                final word = wordData['word'] as String? ?? '';
                final accuracyScore = wordData['accuracyScore'] as double? ?? 0.0;
                final errorType = wordData['errorType'] as String? ?? 'None';
                final styling = ScoreStyling.getScoreStyling(accuracyScore);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        word,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: errorType != 'None' ? Colors.red.shade600 : Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        '${accuracyScore.toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: styling.textColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}