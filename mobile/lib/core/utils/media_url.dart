const _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://terapay.teratech.co.tz/api',
);

String mediaOrigin() {
  final parsed = Uri.tryParse(_apiBase.trim());
  if (parsed == null || parsed.host.isEmpty) {
    return 'https://terapay.teratech.co.tz';
  }
  final port = parsed.hasPort ? ':${parsed.port}' : '';
  return '${parsed.scheme}://${parsed.host}$port';
}

/// Turns API `image` / `image_url` values into an absolute URL the image
/// widgets can load. `/storage/...` is rewritten to `/api/media/...` because
/// the public site serves the PWA HTML for `/storage` paths.
String? resolveMediaUrl(String? path) {
  if (path == null) return null;
  var p = path.trim();
  if (p.isEmpty || p == 'null') return null;

  final origin = mediaOrigin();

  if (p.startsWith('http://') || p.startsWith('https://')) {
    final uri = Uri.tryParse(p);
    if (uri == null) return p;
    final rewritten = _toApiMediaPath(uri.path);
    if (rewritten != null) {
      return '$origin$rewritten${uri.hasQuery ? '?${uri.query}' : ''}';
    }
    if (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1') {
      return '$origin${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    }
    return p;
  }

  p = p.replaceFirst(RegExp(r'^/+'), '');
  final rewritten = _toApiMediaPath('/$p');
  if (rewritten != null) return '$origin$rewritten';

  if (!p.startsWith('storage/')) p = 'storage/$p';
  return '$origin/$p';
}

String? _toApiMediaPath(String path) {
  final match = RegExp(r'/storage/products/([^/?#]+)').firstMatch(path);
  if (match != null) {
    return '/api/media/products/${match.group(1)}';
  }
  final apiMatch = RegExp(r'/api/media/products/([^/?#]+)').firstMatch(path);
  if (apiMatch != null) {
    return '/api/media/products/${apiMatch.group(1)}';
  }
  final fileOnly = RegExp(r'^/?products/([^/?#]+)$').firstMatch(path);
  if (fileOnly != null) {
    return '/api/media/products/${fileOnly.group(1)}';
  }
  return null;
}
