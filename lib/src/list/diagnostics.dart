/// Debug-only labels and logging for the list interval and rendering engine.
library;

import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ListDebugWidget extends StatelessWidget {
  const ListDebugWidget(this.child, this.debugText, {super.key});

  final Widget child;
  final String Function() debugText;

  @override
  StatelessElement createElement() => _DebugElement(this);

  @override
  Widget build(BuildContext context) => child;
}

class _DebugElement extends StatelessElement {
  _DebugElement(super.widget);
}

String debugElement(Element? element) {
  if (element == null) return 'null';
  var ret = 'UNKNOWN';
  if (element is _DebugElement) {
    ret = (element.widget as ListDebugWidget).debugText.call();
  }
  return ret;
}

String debugRenderBox(RenderObject? ro) {
  if (ro == null) return 'null';
  final creator = ro.debugCreator;
  if (creator is DebugCreator) {
    Element? element = creator.element;
    while (element != null) {
      if (element is _DebugElement) return debugElement(element);
      element = element.parent;
    }
  }
  return 'UNKNOWN';
}

extension ElementAncestorTraversal on Element {
  Element? get parent {
    Element? ret;
    visitAncestorElements((element) {
      ret = element;
      return false;
    });
    return ret;
  }
}

//
// Debug
//

String _spaces = '';

void _dbgBegin(String message) {
  _dbgPrint('$message {');
  _spaces += '    ';
}

void _dbgPrint(String message) {
  io.stderr.writeln('$_spaces$message');
}

void _dbgEnd() {
  final l = _spaces.length - 4;
  if (l <= 0) {
    _spaces = '';
  } else {
    _spaces = _spaces.substring(l);
  }
  _dbgPrint('}');
}

const _debugEnabled = false;

void Function(String message) listLogBegin = kDebugMode && _debugEnabled
    ? _dbgBegin
    : (m) {};
void Function(String message) listLogPrint = kDebugMode && _debugEnabled
    ? _dbgPrint
    : (m) {};
void Function() listLogEnd = kDebugMode && _debugEnabled ? _dbgEnd : () {};
