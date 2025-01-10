import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter_quill/flutter_quill.dart';

extension EnhanceContextMenuExt on QuillEditorConfig {
  QuillEditorConfig enhanceContextMenu(QuillController controller) {
    final editorKey = this.editorKey ?? GlobalKey<EditorState>();
    final detectRepeatedTap = _DetectRepeatedTap(editorKey, controller);

    return copyWith(
      editorKey: editorKey,
      onTapUp: detectRepeatedTap.handleTapUp,
      contextMenuBuilder: (context, state) =>
          _contextMenuBuilder(controller, context, state),
    );
  }

  static Widget _contextMenuBuilder(QuillController controller,
      BuildContext context, QuillRawEditorState state) {
    final contextMenuButtonItems = state.contextMenuButtonItems;
    final selection = state.textEditingValue.selection;

    if (selection.isCollapsed) {
      contextMenuButtonItems.removeWhere(
        (it) =>
            it.type == ContextMenuButtonType.cut ||
            it.type == ContextMenuButtonType.copy,
      );

      final selectAllIndex = contextMenuButtonItems
          .indexWhere((it) => it.type == ContextMenuButtonType.selectAll);
      final selectButton = ContextMenuButtonItem(
        label: "Select",
        onPressed: () => _selectNearestWord(controller),
      );

      // add Select (before "Select All")
      if (selectAllIndex > -1) {
        contextMenuButtonItems.insert(selectAllIndex, selectButton);
      } else {
        contextMenuButtonItems.add(
          selectButton,
        );
      }
    }

    return TextFieldTapRegion(
      child: AdaptiveTextSelectionToolbar.buttonItems(
        buttonItems: contextMenuButtonItems,
        anchors: state.contextMenuAnchors,
      ),
    );
  }
}

class _DetectRepeatedTap {
  final GlobalKey<EditorState> editorKey;
  final QuillController controller;
  Offset? _lastTapUpPosition;
  int? _lastOffset;

  _DetectRepeatedTap(
    this.editorKey,
    this.controller,
  );

  bool handleTapUp(
      TapDragUpDetails details, TextPosition Function(Offset offset) f) {
    // something is already selected, we do not want to trigger anything
    if (!controller.selection.isCollapsed) {
      return false;
    }

    final nextPosition = details.globalPosition;
    final nextTextPosition = f(nextPosition);
    final nextOffset = nextTextPosition.offset;
    final lastOffset = _lastOffset;
    final lastTapUpPosition = _lastTapUpPosition;

    if (lastTapUpPosition != null && lastOffset != null) {
      final diff = lastTapUpPosition - nextPosition;
      if (diff.dx.abs() < 10 &&
          diff.dy.abs() < 10 &&
          lastOffset == nextOffset) {
        onShowToolbar();
      }
    }
    _lastOffset = nextOffset;
    _lastTapUpPosition = nextPosition;

    return false;
  }

  void onShowToolbar() {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      editorKey.currentState?.showToolbar();
    });
  }
}

void _selectNearestWord(QuillController controller) {
  /// Determines whether the given character is a word boundary
  bool isWordBoundary(String char) {
    return char.trim().isEmpty ||
        char == '.' ||
        char == ',' ||
        char == ';' ||
        char == '!';
  }

  final selection = controller.selection;
  if (!selection.isCollapsed) {
    // Only handle collapsed selections
    return;
  }

  final text = controller.document.toPlainText();

  if (selection.baseOffset < 0 || selection.baseOffset >= text.length) {
    // Out of bounds, ignore
    return;
  }

  final offset = selection.baseOffset;

  // Determine the start of the word
  int start = offset;
  while (start > 0 && !isWordBoundary(text[start - 1])) {
    start--;
  }

  // Determine the end of the word
  int end = offset;
  while (end < text.length && !isWordBoundary(text[end])) {
    end++;
  }

  // Update the selection to the word boundaries
  controller.updateSelection(
    TextSelection(baseOffset: start, extentOffset: end),
    ChangeSource.local,
  );
}
