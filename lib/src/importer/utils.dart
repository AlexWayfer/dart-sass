// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import '../io.dart';

/// Whether the Sass interpreter is currently evaluating a `@use` rule.
///
/// The `@use` rule has slightly different path-resolution behavior than
/// `@import`: `@use` prioritizes a `.css` file with a given name at the same
/// level as `.sass` and `.scss`, while `@import` prefers `.sass` and `.scss`
/// over `.css`. It's admittedly hacky to set this globally, but `@import` will
/// eventually be removed, at which point we can delete this and have one
/// consistent behavior.
bool _inUseRule = false;

/// Runs [callback] in a context where [resolveImportPath] uses `@use` semantics
/// rather than `@import` semantics.
T inUseRule<T>(T callback()) {
  var wasInUseRule = _inUseRule;
  _inUseRule = true;
  try {
    return callback();
  } finally {
    _inUseRule = wasInUseRule;
  }
}

/// Like [inUseRule], but asynchronous.
Future<T> inUseRuleAsync<T>(Future<T> callback()) async {
  var wasInUseRule = _inUseRule;
  _inUseRule = true;
  try {
    return await callback();
  } finally {
    _inUseRule = wasInUseRule;
  }
}

/// Resolves an imported path using the same logic as the filesystem importer.
///
/// This tries to fill in extensions and partial prefixes and check if a directory default. If no file can be
/// found, it returns `null`.
String resolveImportPath(String path) {
  var extension = p.extension(path);
  if (extension == '.sass' || extension == '.scss' || extension == '.css') {
    return _ifInImport(() => _exactlyOne(
            _tryPath('${p.withoutExtension(path)}.import$extension'))) ??
        _exactlyOne(_tryPath(path));
  }

  return _ifInImport(
          () => _exactlyOne(_tryPathWithExtensions('$path.import'))) ??
      _exactlyOne(_tryPathWithExtensions(path)) ??
      _tryPathAsDirectory(path);
}

/// Like [_tryPath], but checks `.sass`, `.scss`, and `.css` extensions.
List<String> _tryPathWithExtensions(String path) {
  var result = _tryPath(path + '.sass')..addAll(_tryPath(path + '.scss'));
  return result.isNotEmpty ? result : _tryPath(path + '.css');
}

/// Returns the [path] and/or the partial with the same name, if either or both
/// exists.
///
/// If neither exists, returns an empty list.
List<String> _tryPath(String path) {
  var partial = p.join(p.dirname(path), "_${p.basename(path)}");
  return [if (fileExists(partial)) partial, if (fileExists(path)) path];
}

/// Returns the resolved index file for [path] if [path] is a directory and the
/// index file exists.
///
/// Otherwise, returns `null`.
String _tryPathAsDirectory(String path) {
  if (!dirExists(path)) return null;

  return _ifInImport(() =>
          _exactlyOne(_tryPathWithExtensions(p.join(path, 'index.import')))) ??
      _exactlyOne(_tryPathWithExtensions(p.join(path, 'index')));
}

/// If [paths] contains exactly one path, returns that path.
///
/// If it contains no paths, returns `null`. If it contains more than one,
/// throws an exception.
String _exactlyOne(List<String> paths) {
  if (paths.isEmpty) return null;
  if (paths.length == 1) return paths.first;

  throw "It's not clear which file to import. Found:\n" +
      paths.map((path) => "  " + p.prettyUri(p.toUri(path))).join("\n");
}

/// If [_inUseRule] is `false`, invokes callback and returns the result.
///
/// Otherwise, returns `null`.
T _ifInImport<T>(T callback()) => _inUseRule ? null : callback();
