// lib/widgets/drag_drop_question_widget.dart
import 'package:flutter/material.dart';

class DragDropQuestionWidget extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final Map<String, dynamic> currentAnswer;
  final bool showResults;
  final Function(Map<String, dynamic> newColumns) onAnswerChanged;

  const DragDropQuestionWidget({
    super.key,
    required this.questionData,
    required this.currentAnswer,
    required this.showResults,
    required this.onAnswerChanged,
  });

  @override
  State<DragDropQuestionWidget> createState() => _DragDropQuestionWidgetState();
}

class _DragDropQuestionWidgetState extends State<DragDropQuestionWidget> {
  late Map<String, dynamic> _columns;
  late final List<Map<String, dynamic>> _allItems;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(covariant DragDropQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentAnswer != oldWidget.currentAnswer && _isInitialized) {
      setState(() {
        _columns = Map<String, dynamic>.from(widget.currentAnswer);
      });
    }
  }

  void _initializeData() {
    final sourceColumnId = widget.questionData['sourceColumnId'];
    _allItems = List<Map<String, dynamic>>.from(
      widget.questionData['columns'][sourceColumnId]?['items'] ?? [],
    );
    _columns = Map<String, dynamic>.from(widget.currentAnswer);
    _isInitialized = true;
  }

  void _moveItem(
    String fromColumnId,
    String toColumnId,
    Map<String, dynamic> item,
  ) {
    if (widget.showResults) return;

    setState(() {
      // Remove from source column
      final fromItems = List<Map<String, dynamic>>.from(
        _columns[fromColumnId]['items'],
      );
      fromItems.removeWhere((i) => i['content'] == item['content']);
      _columns[fromColumnId]['items'] = fromItems;

      // Add to target column
      final toItems = List<Map<String, dynamic>>.from(
        _columns[toColumnId]['items'],
      );
      toItems.add(item);
      _columns[toColumnId]['items'] = toItems;
    });

    widget.onAnswerChanged(_columns);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final columnOrder = List<String>.from(widget.questionData['columnOrder']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Instruction with better styling
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF3498DB).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.touch_app, color: const Color(0xFF3498DB), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.questionData['instruction'] ??
                      'Drag items to the correct category.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Vertical layout for drag zones
        ...columnOrder.map((columnId) => _buildDragZone(columnId)).toList(),

        // Help text for mobile users
        if (!widget.showResults)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Tap and hold an item, then drag it to the correct category.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDragZone(String columnId) {
    final column = _columns[columnId];
    final items = List<Map<String, dynamic>>.from(column['items'] ?? []);
    final isSourceColumn = columnId == widget.questionData['sourceColumnId'];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3498DB).withOpacity(0.8),
                  const Color(0xFF2980B9).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              column['name'] ?? 'Category',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Drop zone
          DragTarget<Map<String, dynamic>>(
            onAccept: (item) =>
                _moveItem(_findItemColumn(item['content']), columnId, item),
            builder: (context, candidateData, rejectedData) {
              return Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: isSourceColumn ? 200 : 120,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: candidateData.isNotEmpty
                      ? const Color(0xFF3498DB).withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: candidateData.isNotEmpty
                      ? Border.all(color: const Color(0xFF3498DB), width: 2)
                      : null,
                ),
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'Empty list',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: items
                            .map((item) => _buildDraggableItem(item, columnId))
                            .toList(),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableItem(
    Map<String, dynamic> item,
    String currentColumnId,
  ) {
    bool isCorrect = false;
    if (widget.showResults &&
        currentColumnId != widget.questionData['sourceColumnId']) {
      isCorrect = item['correctColumn'] == currentColumnId;
    }

    Widget itemWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: widget.showResults
            ? Border.all(color: isCorrect ? Colors.green : Colors.red, width: 2)
            : Border.all(color: Colors.grey.shade400),
        boxShadow: [
          BoxShadow(
            color: widget.showResults
                ? (isCorrect ? Colors.green : Colors.red).withOpacity(0.1)
                : Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.showResults)
            Icon(Icons.drag_indicator, color: Colors.grey.shade500, size: 18),
          if (!widget.showResults) const SizedBox(width: 8),
          Flexible(
            child: Text(
              item['content'] ?? '',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          if (widget.showResults) ...[
            const SizedBox(width: 8),
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? Colors.green : Colors.red,
              size: 18,
            ),
          ],
        ],
      ),
    );

    if (widget.showResults) {
      return itemWidget;
    }

    return Draggable<Map<String, dynamic>>(
      data: item,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF3498DB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item['content'] ?? '',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          item['content'] ?? '',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
      ),
      child: itemWidget,
    );
  }

  String _findItemColumn(String itemContent) {
    for (String columnId in _columns.keys) {
      final items = List<Map<String, dynamic>>.from(
        _columns[columnId]['items'],
      );
      if (items.any((item) => item['content'] == itemContent)) {
        return columnId;
      }
    }
    return widget.questionData['sourceColumnId']; // fallback
  }
}
