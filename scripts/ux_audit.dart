import 'dart:io';

const _usage = '''
Usage: dart ux_audit.dart [path]

  path   folder or file to scan (default: lib)
''';

final _ansi = stdout.supportsAnsiEscapes;
final _green = _ansi ? '\x1B[32m' : '';
final _yellow = _ansi ? '\x1B[33m' : '';
final _reset = _ansi ? '\x1B[0m' : '';

const _skipSuffixes = ['.g.dart', '.freezed.dart', '.gr.dart', '.config.dart', '.mocks.dart'];

final _dialogCall = RegExp(
  r'(?<![\w.])(showDialog|showAdaptiveDialog|showCupertinoDialog|showGeneralDialog)\s*(<[^>(]*>)?\s*\(',
);
final _dialogWidget = RegExp(r'(?<![\w.])(AlertDialog|CupertinoAlertDialog)(\.adaptive)?\s*\(');
// Case sensitive on purpose: matches "Sure" and areYouSure, but not ensure or measure.
final _confirmWords = RegExp(r'(?<![a-z])[Ss]ure\b|[Dd]elet|[Rr]emov|DELETE|REMOVE');

final _handler = RegExp(r'(?<![\w.])(onPressed|onTap|onLongPress)\s*:');
final _asyncClosure = RegExp(r'^\([^()]*\)\s*async\s*(\{|=>)');
final _forwarder = RegExp(r'^(?:\(\s*\)\s*(?:=>\s*|\{\s*))?(?:await\s+)?(_?[A-Za-z]\w*)(?:\s*\(\s*\)\s*;?\s*\}?)?$');
final _nullWhenBusy = RegExp(r'\?\s*null\s*:');
// A method reference only counts when it sounds like a write. Toggles and
// refreshes can be tapped again on purpose.
final _writeName = RegExp(
  r'submit|save|send|pay|checkout|order|book|buy|purchase|confirm|login|log_?in|sign_?in|sign_?up|register|create|upload|post|delete|remove|transfer|place',
  caseSensitive: false,
);
const _flagWords = 'loading|busy|submitting|saving|sending|processing|inflight|pending|running|locked|working';
final _guard = RegExp(
  '\\b\\w*($_flagWords)\\w*\\s*=\\s*true\\b|if\\s*\\(\\s*[\\w.]*($_flagWords)\\w*\\s*\\)\\s*return',
  caseSensitive: false,
);
final _flag = RegExp('\\b\\w*($_flagWords)\\w*\\b', caseSensitive: false);
final _guardingWidget = RegExp(r'Async|Loading|Progress|Busy');
final _awaitTarget = RegExp(r'\bawait\s+([\w.<>]+)');
// Awaiting a dialog, a route, a picker or a URL launch isn't a write.
final _navigation = RegExp(
  r'^(show\w*|open\w*|launch\w*|pick\w*|Navigator\b|Clipboard\b|Share\b|context\.(push|go|pop)\w*|\w+\.(push|pop)\w*)',
);

final _centeredSpinner = RegExp(
  r'(?<![\w.])Center\s*\(\s*child\s*:\s*(const\s+)?(CircularProgressIndicator(\.adaptive)?|CupertinoActivityIndicator)\s*\(',
);

final _listView = RegExp(r'(?<![\w.])(ListView|GridView|SliverList|SliverGrid)\.(builder|separated)\s*\(');
final _itemCount = RegExp(r'itemCount\s*:\s*([\w.!?]*?\w)[!?]?\s*\??\.\s*length\b');
final _classDecl = RegExp(r'\bclass\s+\w+[^{;]*\{');

class Finding {
  Finding(this.file, this.line, this.message);
  final String file;
  final int line;
  final String message;
}

class Source {
  Source(this.path, this.text) {
    final (code, masked) = _strip(text);
    this.code = code;
    this.masked = masked;
  }

  final String path;
  final String text;

  /// Comments blanked, strings kept. Same length and line breaks as [text].
  late final String code;

  /// Comments and string contents blanked, so brackets in strings don't count.
  late final String masked;

  final findings = <Finding>[];

  int lineOf(int offset) => '\n'.allMatches(text.substring(0, offset)).length + 1;

  void report(int offset, String message) => findings.add(Finding(path, lineOf(offset), message));
}

String _blank(String s) => s.replaceAll(RegExp(r'[^\n]'), ' ');

(String, String) _strip(String s) {
  final code = StringBuffer();
  final masked = StringBuffer();
  var i = 0;
  while (i < s.length) {
    if (s.startsWith('//', i)) {
      final end = s.indexOf('\n', i);
      final stop = end == -1 ? s.length : end;
      code.write(' ' * (stop - i));
      masked.write(' ' * (stop - i));
      i = stop;
    } else if (s.startsWith('/*', i)) {
      final end = s.indexOf('*/', i + 2);
      final stop = end == -1 ? s.length : end + 2;
      code.write(_blank(s.substring(i, stop)));
      masked.write(_blank(s.substring(i, stop)));
      i = stop;
    } else if (s[i] == "'" || s[i] == '"') {
      final raw = i > 0 && s[i - 1] == 'r';
      final q = s.startsWith("'''", i) || s.startsWith('"""', i) ? s.substring(i, i + 3) : s[i];
      var j = i + q.length;
      while (j < s.length && !s.startsWith(q, j)) {
        if (s[j] == '\\' && !raw) {
          j++;
        } else if (q.length == 1 && s[j] == '\n') {
          break;
        }
        j++;
      }
      final inner = j.clamp(0, s.length);
      final stop = inner < s.length && s.startsWith(q, inner) ? inner + q.length : inner;
      code.write(s.substring(i, stop));
      masked.write(q);
      masked.write(_blank(s.substring(i + q.length, inner)));
      masked.write(s.substring(inner, stop));
      i = stop;
    } else {
      code.write(s[i]);
      masked.write(s[i]);
      i++;
    }
  }
  return (code.toString(), masked.toString());
}

int _close(String masked, int open) {
  var depth = 0;
  for (var i = open; i < masked.length; i++) {
    final c = masked[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return masked.length - 1;
}

// End of the argument that starts at [start]: the next comma or closing
// bracket at the same depth.
int _argEnd(String masked, int start) {
  var depth = 0;
  for (var i = start; i < masked.length; i++) {
    final c = masked[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      if (depth == 0) return i;
      depth--;
    }
    if (c == ',' && depth == 0) return i;
  }
  return masked.length;
}

// Name and opening paren of the call whose argument list contains [offset],
// like AsyncButton for `AsyncButton(onPressed: ...)`.
(String, int)? _enclosingCall(String masked, int offset) {
  var depth = 0;
  for (var i = offset - 1; i >= 0; i--) {
    final c = masked[i];
    if (c == ')' || c == ']' || c == '}') depth++;
    if (c == '(' || c == '[' || c == '{') {
      if (depth == 0) {
        if (c != '(') return null;
        final m = RegExp(r'([A-Za-z_][\w.]*)\s*(<[^<>]*>)?\s*$').firstMatch(masked.substring(0, i));
        return m == null ? null : (m.group(1)!, i);
      }
      depth--;
    }
  }
  return null;
}

void _confirmDialogs(Source src) {
  final covered = <(int, int)>[];
  for (final pattern in [_dialogCall, _dialogWidget]) {
    for (final m in pattern.allMatches(src.masked)) {
      if (covered.any((r) => m.start > r.$1 && m.start < r.$2)) continue;
      final close = _close(src.masked, m.end - 1);
      covered.add((m.start, close));
      if (!_confirmWords.hasMatch(src.code.substring(m.end, close))) continue;
      src.report(
        m.start,
        'Confirm dialog for a delete. If it can be undone, remove the item right away and show a SnackBar '
        'with Undo (snippets/undo_delete.dart)',
      );
    }
  }
}

void _doubleTaps(Source src) {
  for (final m in _handler.allMatches(src.masked)) {
    final end = _argEnd(src.masked, m.end);
    final expr = src.masked.substring(m.end, end).trim();
    if (_nullWhenBusy.hasMatch(expr.split(RegExp(r'[({]')).first)) continue;
    final call = _enclosingCall(src.masked, m.start);
    if (call != null) {
      if (_guardingWidget.hasMatch(call.$1)) continue;
      // A sibling argument like `enabled: !state.busy` already blocks the second tap.
      if (_flag.hasMatch(src.masked.substring(call.$2, _close(src.masked, call.$2)))) continue;
    }

    String body;
    final closure = _asyncClosure.firstMatch(expr);
    if (closure != null) {
      body = expr.substring(closure.end);
    } else {
      final name = _forwarder.firstMatch(expr)?.group(1);
      if (name == null || !_writeName.hasMatch(name)) continue;
      final decl = RegExp('(?<![\\w.])${RegExp.escape(name)}\\s*\\([^)]*\\)\\s*async\\s*\\{').firstMatch(src.masked);
      if (decl == null) continue;
      body = src.masked.substring(decl.end - 1, _close(src.masked, decl.end - 1));
    }

    final targets = _awaitTarget.allMatches(body).map((a) => a.group(1)!).toList();
    if (targets.isEmpty || targets.every(_navigation.hasMatch)) continue;
    if (_guard.hasMatch(body)) continue;

    src.report(
      m.start,
      'Async ${m.group(1)} with no busy flag. A second tap runs it again: a double submit or a double payment. '
      'Disable it while it runs (snippets/async_button.dart)',
    );
  }
}

void _spinners(Source src) {
  for (final m in _centeredSpinner.allMatches(src.masked)) {
    src.report(
      m.start,
      'Centered spinner. If this screen loads a list or cards, show a skeleton shaped like them instead '
      '(snippets/skeleton.dart)',
    );
  }
}

void _emptyLists(Source src) {
  final classes = [for (final c in _classDecl.allMatches(src.masked)) (c.start, _close(src.masked, c.end - 1))];
  for (final m in _listView.allMatches(src.masked)) {
    final close = _close(src.masked, m.end - 1);
    final count = _itemCount.firstMatch(src.masked.substring(m.end, close));
    if (count == null) continue;
    final list = count.group(1)!;
    if (list.endsWith('.values')) continue;
    final name = RegExp.escape(list.split('.').last.replaceAll(RegExp(r'[!?]'), ''));

    final owner = classes.where((c) => c.$1 < m.start && c.$2 > m.start).lastOrNull;
    final scope = owner == null ? src.masked : src.masked.substring(owner.$1, owner.$2);
    final emptyCheck = RegExp(
      '(?<![\\w])$name\\s*[!?]?\\s*\\.\\s*(isEmpty|isNotEmpty)\\b'
      '|(?<![\\w])$name\\s*[!?]?\\s*\\.\\s*length\\s*(==|!=|>|<=|<)\\s*[01]\\b'
      r'|\[\s*\]\s*=>|case\s*\[\s*\]|\.empty\b|\b(?!isEmpty\b|isNotEmpty\b)\w*Empty\w*',
    );
    if (emptyCheck.hasMatch(scope)) continue;

    src.report(
      m.start,
      '${m.group(1)} over $list.length with no empty check in this widget. An empty list is a blank screen. '
      'Say what goes here and offer one action (snippets/empty_state.dart)',
    );
  }
}

Iterable<File> _dartFiles(String root) sync* {
  if (FileSystemEntity.isFileSync(root)) {
    yield File(root);
    return;
  }
  final files =
      Directory(root).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    if (_skipSuffixes.any(f.path.endsWith)) continue;
    yield f;
  }
}

void main(List<String> args) {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.write(_usage);
    return;
  }
  final unknown = args.where((a) => a.startsWith('-'));
  if (unknown.isNotEmpty || args.length > 1) {
    stderr.write(unknown.isEmpty ? _usage : 'Unknown option: ${unknown.first}\n\n$_usage');
    exitCode = 2;
    return;
  }
  final root = args.isEmpty ? 'lib' : args.first;
  if (FileSystemEntity.typeSync(root) == FileSystemEntityType.notFound) {
    stderr.writeln('No such path: $root');
    exitCode = 2;
    return;
  }

  final all = <Finding>[];
  var files = 0;
  for (final f in _dartFiles(root)) {
    final src = Source(f.path, f.readAsStringSync());
    _confirmDialogs(src);
    _doubleTaps(src);
    _spinners(src);
    _emptyLists(src);
    if (src.findings.isEmpty) continue;
    files++;
    all.addAll(src.findings);
  }

  if (all.isEmpty) {
    stdout.writeln('Flutter UX audit of $root: ${_green}no problems found.$_reset');
    return;
  }

  all.sort((a, b) => a.file == b.file ? a.line.compareTo(b.line) : a.file.compareTo(b.file));
  stdout.writeln(
    'Flutter UX audit of $root: ${all.length} ${all.length == 1 ? 'finding' : 'findings'} '
    'in $files ${files == 1 ? 'file' : 'files'}\n',
  );
  for (final f in all) {
    stdout.writeln('  $_yellow${f.file}:${f.line}$_reset  ${f.message}');
  }
  exitCode = 1;
}
