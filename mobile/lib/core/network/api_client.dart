/// Abstract API client interface.
/// Any transport layer (REST, GraphQL, mock) must implement this contract.
/// This allows swapping the underlying API protocol without touching features.
abstract class ApiClient {
  Future<T> get<T>({
    required String endpoint,
    required T Function(dynamic json) parser,
    Map<String, dynamic>? queryParameters,
  });

  Future<T> post<T>({
    required String endpoint,
    required T Function(dynamic json) parser,
    dynamic data,
  });

  Future<T> put<T>({
    required String endpoint,
    required T Function(dynamic json) parser,
    dynamic data,
  });

  Future<T> patch<T>({
    required String endpoint,
    required T Function(dynamic json) parser,
    dynamic data,
  });

  Future<void> delete({required String endpoint});

  Future<List<int>> downloadBytes({required String endpoint});
}
