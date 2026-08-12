import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/notes_service.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// No `intl` dependency in this project — brief's tech stack list doesn't
/// include it — so this hand-rolls the "Aug 12, 2026 · 3:42 PM" format
/// Apple Notes uses under the title.
String _formatTimestamp(DateTime utc) {
  final dt = utc.toLocal();
  final month = _monthNames[dt.month - 1];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$month ${dt.day}, ${dt.year} · $hour12:$minute $period';
}

class NoteDetailScreen extends StatefulWidget {
  final Note note;
  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late Note _note;
  // Controllers created once here (not rebuilt in build()) — see the v4
  // gotcha about TextEditingController recreation fighting the cursor.
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _titleController = TextEditingController(text: _note.title)
      ..addListener(_markDirty);
    _bodyController = TextEditingController(text: _note.body)
      ..addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  /// Returns true once the note is safely saved (or there was nothing to
  /// save), false if a save attempt failed — callers should not pop in
  /// that case so the user doesn't lose their edit.
  Future<bool> _save() async {
    if (!_dirty) return true;
    setState(() => _saving = true);
    try {
      _note = await NotesService.updateNote(
        _note.copyWith(
          title: _titleController.text,
          body: _bodyController.text,
        ),
      );
      if (!mounted) return true;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      return true;
    } on NotesException catch (e) {
      if (!mounted) return false;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    }
  }

  Future<void> _togglePin() async {
    final previous = _note.pinned;
    setState(() => _note = _note.copyWith(pinned: !previous));
    try {
      _note = await NotesService.updateNote(_note);
    } on NotesException catch (e) {
      if (!mounted) return;
      setState(() => _note = _note.copyWith(pinned: previous));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await NotesService.deleteNote(_note.id);
      if (mounted) Navigator.of(context).pop();
    } on NotesException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final saved = await _save();
        if (saved && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(
                _note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              tooltip: _note.pinned ? 'Unpin' : 'Pin',
              onPressed: _togglePin,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: theme.textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 12),
                    child: Text(
                      _formatTimestamp(_note.updatedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_saving) const LinearProgressIndicator(),
                  // No expands:true / Expanded here on purpose — that
                  // forced the body box to fill the rest of the screen
                  // even for a two-word note, leaving a big empty void
                  // below it. maxLines: null inside a scroll view lets
                  // the field size to its content and only scrolls once
                  // the note is actually long.
                  Expanded(
                    child: SingleChildScrollView(
                      child: TextField(
                        controller: _bodyController,
                        style: theme.textTheme.bodyLarge,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Start typing…',
                          border: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
