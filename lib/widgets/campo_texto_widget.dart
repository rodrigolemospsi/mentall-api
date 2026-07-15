import 'package:flutter/material.dart';

class CampoTextoWidget extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final int? maxHeight;

  const CampoTextoWidget({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.maxHeight,
  });

  @override
  State<CampoTextoWidget> createState() => _CampoTextoWidgetState();
}

class _CampoTextoWidgetState extends State<CampoTextoWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: widget.controller,
      scrollController: _scrollController,
      maxLines: widget.maxLines,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: widget.maxLines > 1,
      ),
    );

    final constrained = widget.maxHeight != null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight!.toDouble()),
            child: field,
          )
        : field;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: constrained,
      ),
    );
  }
}
