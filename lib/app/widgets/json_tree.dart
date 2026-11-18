import 'dart:convert';

import 'package:flutter/material.dart';

import '../utils/json_format.dart';

/// Syntax colors for JSON values.
abstract final class JsonColors {
  static Color key(BuildContext c) => Theme.of(c).colorScheme.primary;
  static Color string(BuildContext c) =>
      Theme.of(c).colorScheme.tertiary;
  static Color number(BuildContext c) =>
      Theme.of(c).colorScheme.secondary;
  static Color boolNull(BuildContext c) =>
      Theme.of(c).colorScheme.error;
  static Color structure(BuildContext c) =>
      Theme.of(c).colorScheme.onSurfaceVariant;
}

String _typeLabel(Object? v) => switch (v) {
      null => 'null',
      String _ => 'string',
      num _ => 'number',
      bool _ => 'bool',
      Map _ => 'object',
      List _ => 'array',
      _ => 'value',
    };

/// Read-only collapsible JSON tree.
class JsonTreeView extends StatelessWidget {
  const JsonTreeView({super.key, required this.value, this.fontSize = 13});

  final Object? value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(fontSize: fontSize, fontFamily: 'monospace'),
      child: _buildNode(context, value, null, 0, isRoot: true),
    );
  }

  Widget _buildNode(
    BuildContext context,
    Object? value,
    String? key,
    int depth, {
    bool isRoot = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final mono = TextStyle(fontSize: fontSize, fontFamily: 'monospace');

    Widget keyChip() {
      if (key == null) return const SizedBox.shrink();
      return Text(
        '$key: ',
        style: mono.copyWith(color: JsonColors.key(context)),
      );
    }

    if (value is Map) {
      final entries = value.entries.toList();
      return _Branch(
        label: keyChip(),
        preview: '{${entries.length}}',
        color: JsonColors.structure(context),
        empty: entries.isEmpty,
        children: [
          for (final e in entries)
            _buildNode(context, e.value, '${e.key}', depth + 1),
        ],
      );
    }
    if (value is List) {
      return _Branch(
        label: keyChip(),
        preview: '[${value.length}]',
        color: JsonColors.structure(context),
        empty: value.isEmpty,
        children: [
          for (var i = 0; i < value.length; i++)
            _buildNode(context, value[i], '[$i]', depth + 1),
        ],
      );
    }

    // Scalar leaf.
    final Color color;
    final String text;
    if (value is String) {
      color = JsonColors.string(context);
      text = '"${value.replaceAll('"', '\\"')}"';
    } else if (value is num) {
      color = JsonColors.number(context);
      text = '$value';
    } else if (value == null || value is bool) {
      color = JsonColors.boolNull(context);
      text = '$value';
    } else {
      color = scheme.onSurface;
      text = '$value';
    }
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0 + (key == null ? 0 : 0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: key == null ? '' : '$key: ',
                    style: mono.copyWith(color: JsonColors.key(context)),
                  ),
                  TextSpan(text: text, style: mono.copyWith(color: color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({
    required this.label,
    required this.preview,
    required this.color,
    required this.children,
    required this.empty,
  });

  final Widget label;
  final String preview;
  final Color color;
  final List<Widget> children;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    if (empty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            label,
            Text('$preview ', style: TextStyle(color: color)),
          ],
        ),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 14),
        initiallyExpanded: true,
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Row(
          children: [
            Flexible(child: label),
            Text(
              preview,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
        children: children,
      ),
    );
  }
}

// ————————————————————————————————————————————————
// Editable JSON tree
// ————————————————————————————————————————————————

/// Editable JSON tree. Mutates a deep copy internally and reports the
/// new root through [onChanged]. Root must be a Map or List.
class JsonTreeEditor extends StatefulWidget {
  const JsonTreeEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final Object? initialValue;
  final ValueChanged<Object?> onChanged;

  @override
  State<JsonTreeEditor> createState() => _JsonTreeEditorState();
}

class _JsonTreeEditorState extends State<JsonTreeEditor> {
  late Object? _root;

  @override
  void initState() {
    super.initState();
    _root = _deepCopy(widget.initialValue);
  }

  static Object? _deepCopy(Object? v) {
    final encoded = tryEncodeJson(v);
    if (encoded == null) return v;
    return jsonDecodeSafe(encoded);
  }

  void _emit() => widget.onChanged(_root);

  @override
  Widget build(BuildContext context) {
    return _NodeEditor(
      value: _root,
      onChanged: (v) {
        setState(() => _root = v);
        _emit();
      },
      isRoot: true,
    );
  }
}

Object? jsonDecodeSafe(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}

class _NodeEditor extends StatelessWidget {
  const _NodeEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.mapKey,
    this.index,
    this.isRoot = false,
    this.depth = 0,
  });

  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? mapKey;
  final int? index;
  final bool isRoot;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final label = mapKey != null
        ? '$mapKey'
        : (index != null ? '[$index]' : 'root');

    if (value is Map) {
      final map = Map<String, dynamic>.from(value as Map);
      return _Container(
        label: label,
        typeLabel: 'object · ${map.length}',
        onDelete: isRoot ? null : () => onChanged(_deleteSentinel),
        onAdd: () => _addMapEntry(context, map),
        addLabel: 'Add key',
        children: [
          for (final e in map.entries)
            _NodeEditor(
              key: ValueKey('${depth}_${e.key}'),
              value: e.value,
              mapKey: e.key,
              depth: depth + 1,
              onChanged: (v) {
                if (identical(v, _deleteSentinel)) {
                  map.remove(e.key);
                } else {
                  map[e.key] = v;
                }
                onChanged(Map<String, dynamic>.from(map));
              },
            ),
        ],
      );
    }

    if (value is List) {
      final list = List<dynamic>.from(value as List);
      return _Container(
        label: label,
        typeLabel: 'array · ${list.length}',
        onDelete: isRoot ? null : () => onChanged(_deleteSentinel),
        onAdd: () => _addListItem(context, list),
        addLabel: 'Add item',
        children: [
          for (var i = 0; i < list.length; i++)
            _NodeEditor(
              key: ValueKey('${depth}_$i'),
              value: list[i],
              index: i,
              depth: depth + 1,
              onChanged: (v) {
                if (identical(v, _deleteSentinel)) {
                  list.removeAt(i);
                } else {
                  list[i] = v;
                }
                onChanged(List<dynamic>.from(list));
              },
            ),
        ],
      );
    }

    // Scalar.
    return _ScalarRow(
      label: label,
      value: value,
      onChanged: onChanged,
      onDelete: isRoot ? null : () => onChanged(_deleteSentinel),
    );
  }

  Future<void> _addMapEntry(
      BuildContext context, Map<String, dynamic> map) async {
    final result = await showDialog<({String key, Object? value})>(
      context: context,
      builder: (_) => const _AddEntryDialog(),
    );
    if (result == null) return;
    map[result.key] = result.value;
    onChanged(Map<String, dynamic>.from(map));
  }

  Future<void> _addListItem(BuildContext context, List<dynamic> list) async {
    final result = await showDialog<_ScalarResult>(
      context: context,
      builder: (_) => const _ScalarEditDialog(initial: null, label: 'new item'),
    );
    if (result == null) return;
    list.add(result.value);
    onChanged(List<dynamic>.from(list));
  }
}

const Object _deleteSentinel = Object();

class _Container extends StatelessWidget {
  const _Container({
    required this.label,
    required this.typeLabel,
    required this.children,
    required this.onAdd,
    required this.addLabel,
    this.onDelete,
  });

  final String label;
  final String typeLabel;
  final List<Widget> children;
  final VoidCallback onAdd;
  final String addLabel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: true,
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              typeLabel,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: addLabel,
              icon: Icon(Icons.add_rounded, size: 18, color: scheme.primary),
              onPressed: onAdd,
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.close_rounded,
                    size: 18, color: scheme.error),
                onPressed: onDelete,
              )
            else
              const SizedBox(width: 40),
          ],
        ),
        children: children,
      ),
    );
  }
}

class _ScalarRow extends StatelessWidget {
  const _ScalarRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onDelete,
  });

  final String label;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (value) {
      String _ => JsonColors.string(context),
      num _ => JsonColors.number(context),
      bool _ || null => JsonColors.boolNull(context),
      _ => scheme.onSurface,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _edit(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                child: Text(
                  summarizeValue(value, maxLen: 120),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Text(
            _typeLabel(value),
            style: TextStyle(fontSize: 10, color: scheme.outline),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete key',
              icon: Icon(Icons.close_rounded,
                  size: 16, color: scheme.error),
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            )
          else
            const SizedBox(width: 32),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<_ScalarResult>(
      context: context,
      builder: (_) => _ScalarEditDialog(initial: value, label: label),
    );
    if (result != null) onChanged(result.value);
  }
}

/// Wrapper so "set to null" is distinguishable from "cancelled".
class _ScalarResult {
  const _ScalarResult(this.value);
  final Object? value;
}

class _ScalarEditDialog extends StatefulWidget {
  const _ScalarEditDialog({required this.initial, required this.label});

  final Object? initial;
  final String label;

  @override
  State<_ScalarEditDialog> createState() => _ScalarEditDialogState();
}

class _ScalarEditDialogState extends State<_ScalarEditDialog> {
  late final TextEditingController _controller;
  late String _type;

  @override
  void initState() {
    super.initState();
    _type = _typeLabel(widget.initial);
    _controller = TextEditingController(
      text: widget.initial is String
          ? widget.initial as String
          : widget.initial == null
              ? ''
              : '${widget.initial}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Object? _parse() {
    final text = _controller.text;
    switch (_type) {
      case 'string':
        return text;
      case 'number':
        return num.tryParse(text);
      case 'bool':
        return text.toLowerCase() == 'true';
      case 'null':
        return null;
      default:
        return parseJsonValue(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Edit ${widget.label}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'string', child: Text('string')),
              DropdownMenuItem(value: 'number', child: Text('number')),
              DropdownMenuItem(value: 'bool', child: Text('bool')),
              DropdownMenuItem(value: 'null', child: Text('null')),
              DropdownMenuItem(value: 'json', child: Text('json')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'string'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: _type == 'json' ? 6 : 1,
            minLines: 1,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              labelText: switch (_type) {
                'bool' => 'true / false',
                'null' => '(always null)',
                'json' => 'JSON value',
                _ => 'Value',
              },
            ),
            onSubmitted: (_) => _save(),
          ),
          if (_type == 'null')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Value will be set to null.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    if (_type == 'number' && num.tryParse(_controller.text) == null) {
      return; // invalid number — keep dialog open
    }
    if (_type == 'json' && parseJsonValue(_controller.text) == null) {
      return;
    }
    Navigator.pop(context, _ScalarResult(_parse()));
  }
}

class _AddEntryDialog extends StatefulWidget {
  const _AddEntryDialog();

  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  final _key = TextEditingController();
  final _value = TextEditingController(text: '""');
  String _error = '';

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final key = _key.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Key is required');
      return;
    }
    final parsed = parseJsonValue(_value.text);
    if (parsed == null) {
      setState(() => _error = 'Invalid JSON value');
      return;
    }
    Navigator.pop(context, (key: key, value: parsed));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _key,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Key'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              labelText: 'JSON value',
              errorText: _error.isEmpty ? null : _error,
              hintText: '"text", 42, true, {...}, [...]',
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}
