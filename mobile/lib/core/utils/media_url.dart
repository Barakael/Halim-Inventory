const _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://haslim.co.tz/api',
);

String mediaOrigin() {
  final parsed = Uri.tryParse(_apiBase.trim());
  if (parsed == null || parsed.host.isEmpty) {
    return 'http://127.0.0.1:8000';
  }
  final port = parsed.hasPort ? ':${parsed.port}' : '';
  return '${parsed.scheme}://${parsed.host}$port';
}

/// Turns API `image` / `image_url` / receipt values into an absolute URL.
/// `/storage/...` is rewritten to `/api/media/...` because the public site
/// serves the PWA HTML for `/storage` paths.
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
    // Absolute /api/media already on another host — rewrite to API origin
    if (uri.path.startsWith('/api/media/')) {
      return '$origin${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    }
    return p;
  }

  if (p.startsWith('/api/media/')) {
    return '$origin$p';
  }

  p = p.replaceFirst(RegExp(r'^/+'), '');
  final rewritten = _toApiMediaPath('/$p');
  if (rewritten != null) return '$origin$rewritten';

  if (!p.startsWith('storage/')) p = 'storage/$p';
  final fromStorage = _toApiMediaPath('/$p');
  if (fromStorage != null) return '$origin$fromStorage';
  return '$origin/$p';
}

String? _toApiMediaPath(String path) {
  // Already API media
  final already = RegExp(r'^/api/media/(products|purchase-payments|debt-payments)/(.+)$')
      .firstMatch(path);
  if (already != null) {
    return '/api/media/${already.group(1)}/${already.group(2)}';
  }

  // /storage/purchase-payments/{shop}/{file}
  final purchasePay = RegExp(
    r'/storage/purchase-payments/(\d+)/([^/?#]+)',
  ).firstMatch(path);
  if (purchasePay != null) {
    return '/api/media/purchase-payments/${purchasePay.group(1)}/${purchasePay.group(2)}';
  }

  // /storage/debt-payments/{shop}/{file}
  final debtPay = RegExp(
    r'/storage/debt-payments/(\d+)/([^/?#]+)',
  ).firstMatch(path);
  if (debtPay != null) {
    return '/api/media/debt-payments/${debtPay.group(1)}/${debtPay.group(2)}';
  }

  // /storage/products/{shop}/{file} or /storage/products/{file}
  final productShop = RegExp(r'/storage/products/(\d+)/([^/?#]+)').firstMatch(path);
  if (productShop != null) {
    return '/api/media/products/${productShop.group(1)}/${productShop.group(2)}';
  }
  final product = RegExp(r'/storage/products/([^/?#]+)').firstMatch(path);
  if (product != null) {
    return '/api/media/products/${product.group(1)}';
  }

  final fileOnly = RegExp(r'^/?products/([^/?#]+)$').firstMatch(path);
  if (fileOnly != null) {
    return '/api/media/products/${fileOnly.group(1)}';
  }
  return null;
}
