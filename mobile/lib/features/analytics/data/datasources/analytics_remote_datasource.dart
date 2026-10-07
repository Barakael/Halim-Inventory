import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/analytics_model.dart';

class AnalyticsRemoteDataSource {
  final ApiClient apiClient;
  const AnalyticsRemoteDataSource({required this.apiClient});

  Future<AnalyticsModel> getAnalytics({String? date}) =>
      apiClient.get<AnalyticsModel>(
        endpoint: ApiEndpoints.dashboard,
        parser: (json) {
          if (json is Map<String, dynamic>) {
            return AnalyticsModel.fromDashboardJson(json);
          }
          if (json is Map) {
            return AnalyticsModel.fromDashboardJson(
              Map<String, dynamic>.from(json),
            );
          }
          throw FormatException(
            'Unexpected dashboard payload: ${json.runtimeType}',
          );
        },
      );
}
