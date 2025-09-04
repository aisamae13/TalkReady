import 'package:flutter/material.dart';
import 'dart:async';

class PreAssessment extends StatefulWidget {
  final VoidCallback onComplete;
  final Map<String, dynamic> assessmentData;

  const PreAssessment({
    super.key,
    required this.onComplete,
    required this.assessmentData,
  });

  @override
  _PreAssessmentState createState() => _PreAssessmentState();
}

class _PreAssessmentState extends State<PreAssessment>
    with TickerProviderStateMixin {
  Map<String, dynamic> _columns = {};
  bool _showFeedback = false;
  double _progress = 0.0;
  Map<String, String>? _results;
  Timer? _progressTimer;
  
  late AnimationController _feedbackController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.easeInOut,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
    ));
  }

  void _initializeData() {
    if (widget.assessmentData['columns'] != null) {
      setState(() {
        _columns = Map<String, dynamic>.from(widget.assessmentData['columns']);
        _showFeedback = false;
        _progress = 0.0;
        _results = null;
      });
    }
  }

  @override
  void didUpdateWidget(PreAssessment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assessmentData != oldWidget.assessmentData) {
      _initializeData();
    }
  }

  bool _canAcceptDrop(String columnId, Map<String, dynamic> item) {
    // Check if the item can be dropped in this column
    return true; // Allow all drops for now, validation happens on check
  }

  void _handleDrop(String targetColumnId, Map<String, dynamic> item, String sourceColumnId) {
    if (_results != null) return; // Don't allow drops after checking answers

    setState(() {
      // Remove item from source column
      List<dynamic> sourceItems = List.from(_columns[sourceColumnId]['items']);
      sourceItems.removeWhere((sourceItem) => sourceItem['id'] == item['id']);
      _columns[sourceColumnId]['items'] = sourceItems;

      // Add item to target column
      List<dynamic> targetItems = List.from(_columns[targetColumnId]['items']);
      targetItems.add(item);
      _columns[targetColumnId]['items'] = targetItems;
    });
  }

  void _handleCheckAnswers() {
    final newResults = <String, String>{};
    final sourceColumnId = widget.assessmentData['sourceColumnId'];
    
    _columns.forEach((columnId, column) {
      if (columnId != sourceColumnId) {
        for (var item in column['items']) {
          final isCorrect = item['correctColumn'] == columnId;
          newResults[item['id']] = isCorrect ? 'correct' : 'incorrect';
        }
      }
    });

    setState(() => _results = newResults);

    // Show results for 3 seconds, then show feedback
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showFeedback = true);
        _feedbackController.forward();
        _startProgressAnimation();
      }
    });
  }

  void _startProgressAnimation() {
    _progress = 0.0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 38), (timer) {
      setState(() {
        _progress += 1.0;
        if (_progress >= 100.0) {
          _progress = 100.0;
          timer.cancel();
        }
      });
    });

    // Complete after 4 seconds
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assessmentData['columns'] == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text('Loading pre-assessment...'),
        ),
      );
    }

    if (_showFeedback) {
      return _buildFeedbackView();
    }

    return _buildAssessmentView();
  }

  Widget _buildFeedbackView() {
    final feedbackData = widget.assessmentData['feedback'] ?? {};
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.only(bottom: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                feedbackData['heading'] ?? 'Well Done!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                feedbackData['paragraph'] ?? 'Great job on completing the pre-assessment!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    Text(
                      'Loading lesson...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _progress / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[500]!),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentView() {
    final columnOrder = widget.assessmentData['columnOrder'] as List<dynamic>? ?? [];
    final sourceColumnId = widget.assessmentData['sourceColumnId'] as String? ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildInstruction(),
          const SizedBox(height: 24),
          _buildDragDropArea(columnOrder),
          if (_isAllItemsMoved(sourceColumnId) && _results == null) ...[
            const SizedBox(height: 32),
            _buildCheckButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.lightbulb,
            color: Colors.yellow[700],
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.assessmentData['title'] ?? 'Pre-Assessment',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3066be),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstruction() {
    return Text(
      widget.assessmentData['instruction'] ?? '',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[700],
        height: 1.5,
      ),
    );
  }

  Widget _buildDragDropArea(List<dynamic> columnOrder) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate appropriate number of columns based on screen width
        int crossAxisCount = constraints.maxWidth > 800 
            ? columnOrder.length 
            : constraints.maxWidth > 600 
                ? 2 
                : 1;
                
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: columnOrder.length,
          itemBuilder: (context, index) {
            final columnId = columnOrder[index].toString();
            final column = _columns[columnId];
            if (column == null) return const SizedBox.shrink();
            
            return _buildDropColumn(columnId, column);
          },
        );
      },
    );
  }

  Widget _buildDropColumn(String columnId, Map<String, dynamic> column) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            column['name'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DragTarget<Map<String, dynamic>>(
            onWillAccept: (data) => _canAcceptDrop(columnId, data!),
            onAccept: (data) {
              // Find source column
              String? sourceColumnId;
              _columns.forEach((key, value) {
                if ((value['items'] as List).any((item) => item['id'] == data['id'])) {
                  sourceColumnId = key;
                }
              });
              if (sourceColumnId != null) {
                _handleDrop(columnId, data, sourceColumnId!);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              
              return Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHovering ? Colors.blue[50] : Colors.grey[50],
                  border: Border.all(
                    color: isHovering ? Colors.blue[300]! : Colors.grey[300]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: (column['items'] as List<dynamic>)
                      .map<Widget>((item) => _buildDraggableItem(item, columnId))
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableItem(Map<String, dynamic> item, String columnId) {
    final resultStatus = _results?[item['id']];
    Color backgroundColor = Colors.white;
    Color? borderColor;
    
    if (resultStatus == 'correct') {
      borderColor = Colors.green[500];
    } else if (resultStatus == 'incorrect') {
      borderColor = Colors.red[500];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Draggable<Map<String, dynamic>>(
        data: item,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              item['content'] ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        childWhenDragging: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            item['content'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor ?? Colors.grey[300]!,
              width: borderColor != null ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            item['content'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _handleCheckAnswers,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[500],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 4,
        ),
        child: const Text(
          'I\'m Done!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  bool _isAllItemsMoved(String sourceColumnId) {
    if (_columns[sourceColumnId] == null) return false;
    final sourceItems = _columns[sourceColumnId]['items'] as List<dynamic>;
    return sourceItems.isEmpty;
  }
}