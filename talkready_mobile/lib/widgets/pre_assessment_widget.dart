// lib/StudentAssessment/PreAssessment.dart
import 'package:flutter/material.dart';
import 'dart:async';

class PreAssessmentWidget extends StatefulWidget {
  final Map<String, dynamic> assessmentData;
  final VoidCallback onComplete;

  const PreAssessmentWidget({
    super.key,
    required this.assessmentData,
    required this.onComplete,
  });

  @override
  _PreAssessmentWidgetState createState() => _PreAssessmentWidgetState();
}

class _PreAssessmentWidgetState extends State<PreAssessmentWidget> {
  late Map<String, Map<String, dynamic>> _columns;
  late String _sourceColumnId;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    final originalColumns = Map<String, dynamic>.from(
      widget.assessmentData['columns'] ?? {},
    );
    final newTypedColumns = <String, Map<String, dynamic>>{};

    originalColumns.forEach((key, value) {
      final columnData = Map<String, dynamic>.from(value as Map);
      final itemsList = columnData['items'] as List? ?? [];
      final typedItems = itemsList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      newTypedColumns[key] = {'name': columnData['name'], 'items': typedItems};
    });

    _columns = newTypedColumns;
    _sourceColumnId = widget.assessmentData['sourceColumnId'] as String;
  }

  void _handleDrop(String itemId, String targetColumnId) {
    if (_showResults) return;
    final item = _findAndRemoveItem(itemId);
    if (item != null) {
      setState(() {
        final targetList = _columns[targetColumnId]!['items'] as List;
        targetList.add(item);
      });
    }
  }

  Map<String, dynamic>? _findAndRemoveItem(String itemId) {
    Map<String, dynamic>? foundItem;
    for (var column in _columns.values) {
      final items = column['items'] as List;
      final itemIndex = items.indexWhere((item) => item['id'] == itemId);
      if (itemIndex != -1) {
        foundItem = items.removeAt(itemIndex) as Map<String, dynamic>;
        break;
      }
    }
    return foundItem;
  }

  void _checkAnswers() {
    setState(() => _showResults = true);
    Timer(const Duration(seconds: 4), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    final bool allItemsPlaced =
        (_columns[_sourceColumnId]!['items'] as List).isEmpty;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.assessmentData['title'] as String,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00568D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.assessmentData['instruction'] as String,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // Source items (Draggables)
            _buildSourceColumn(_sourceColumnId),

            const Divider(height: 32, thickness: 1),

            // Target columns (Drop Zones)
            ..._getTargetColumnIds().map((id) => _buildTargetColumn(id)),

            const SizedBox(height: 24),
            if (allItemsPlaced && !_showResults)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  onPressed: _checkAnswers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  label: const Text("I'm Done!"),
                ),
              ),
            if (_showResults) _buildFeedback(),
          ],
        ),
      ),
    );
  }

  List<String> _getTargetColumnIds() {
    return (widget.assessmentData['columnOrder'] as List<dynamic>)
        .where((id) => id != _sourceColumnId)
        .map((id) => id as String)
        .toList();
  }

  Widget _buildSourceColumn(String columnId) {
    final column = _columns[columnId]!;
    return Column(
      children: [
        Text(
          column['name'] as String,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: (column['items'] as List).map<Widget>((item) {
            final itemWidget = _buildDraggableItem(item, columnId);
            return Draggable<String>(
              data: item['id'] as String,
              feedback: Material(elevation: 4.0, child: itemWidget),
              childWhenDragging: Opacity(opacity: 0.5, child: itemWidget),
              child: itemWidget,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTargetColumn(String columnId) {
    final column = _columns[columnId]!;
    return DragTarget<String>(
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            color: isHovering ? Colors.blue[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovering ? Colors.blue.shade300 : Colors.grey.shade300,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Text(
                column['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 16),
              if ((column['items'] as List).isEmpty)
                Text(
                  'Drop items here',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (column['items'] as List)
                      .map((item) => _buildDraggableItem(item, columnId))
                      .toList(),
                ),
            ],
          ),
        );
      },
      onWillAccept: (data) => true,
      onAccept: (data) => _handleDrop(data, columnId),
    );
  }

  Widget _buildDraggableItem(
    Map<String, dynamic> item,
    String currentColumnId,
  ) {
    Color? borderColor;
    Color? bgColor = Colors.white;
    if (_showResults && currentColumnId != _sourceColumnId) {
      if (item['correctColumn'] == currentColumnId) {
        borderColor = Colors.green;
        bgColor = Colors.green[50];
      } else {
        borderColor = Colors.red;
        bgColor = Colors.red[50];
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? Colors.grey[400]!,
          width: borderColor != null ? 2.0 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        item['content'] as String,
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _buildFeedback() {
    // This widget remains the same
    final feedbackData =
        widget.assessmentData['feedback'] as Map<String, dynamic>;
    return Center(
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          Text(
            feedbackData['heading'] as String,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(feedbackData['paragraph'] as String),
          const SizedBox(height: 16),
          const Text("Loading lesson..."),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
