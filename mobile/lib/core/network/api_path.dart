/// Dio treats paths starting with `/` as absolute on the host, which drops `/api`
/// from the base URL. Strip the leading slash so paths join correctly.
String resolveApiPath(String path) {
  if (path.isEmpty) return path;
  return path.startsWith('/') ? path.substring(1) : path;
}

/// API root must end with `/` so relative paths like `login` resolve to `…/api/login`.
String normalizeApiBaseUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.endsWith('/') ? trimmed : '$trimmed/';
}
