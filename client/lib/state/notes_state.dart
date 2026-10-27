import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/note.dart';

class NotesState extends ChangeNotifier {
  NotesState(this._api);

  final Api _api;

  List<Note> _notes = [];
  bool _loading = false;
  String? _error;
  String _search = '';

  List<Note> get notes {
    if (_search.isEmpty) return _notes;
    final q = _search.toLowerCase();
    return _notes.where((n) {
      return n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q);
    }).toList();
  }

  bool get loading => _loading;
  String? get error => _error;
  String get search => _search;

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _notes = await _api.notes();
      _notes.sort((a, b) {
        if (a.isPinned != b.isPinned) return b.isPinned ? 1 : -1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Note?> create({String? title, String? content, String? color, String? tags}) async {
    try {
      final note = await _api.createNote(title: title, content: content, color: color, tags: tags);
      _notes.insert(0, note);
      notifyListeners();
      return note;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> update(Note note) async {
    try {
      final updated = await _api.updateNote(note.id, title: note.title, content: note.content, isPinned: note.isPinned, color: note.color, tags: note.tags);
      final idx = _notes.indexWhere((n) => n.id == note.id);
      if (idx >= 0) {
        _notes[idx] = updated;
        _notes.sort((a, b) {
          if (a.isPinned != b.isPinned) return b.isPinned ? 1 : -1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> togglePin(Note note) async {
    try {
      final updated = await _api.togglePinNote(note.id);
      final idx = _notes.indexWhere((n) => n.id == note.id);
      if (idx >= 0) {
        _notes[idx] = updated;
        _notes.sort((a, b) {
          if (a.isPinned != b.isPinned) return b.isPinned ? 1 : -1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(Note note) async {
    try {
      await _api.deleteNote(note.id);
      _notes.removeWhere((n) => n.id == note.id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
