import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../bloc/notifications_bloc.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsBloc>().add(const NotificationsFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => context
                .read<NotificationsBloc>()
                .add(const NotificationsMarkAllReadRequested()),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          if (state is NotificationsLoading) return const AppLoadingIndicator();
          if (state is NotificationsError) {
            return ErrorView(
              message: state.message,
              onRetry: () => context
                  .read<NotificationsBloc>()
                  .add(const NotificationsFetchRequested()),
            );
          }
          if (state is NotificationsLoaded) {
            if (state.notifications.isEmpty) {
              return const EmptyView(
                message: 'No notifications',
                icon: Icons.notifications_none_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = state.notifications[i];
                return Card(
                  color: n.isRead ? null : AppColors.primary.withAlpha(12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _priorityColor(n.priority).withAlpha(30),
                      child: Icon(
                        _typeIcon(n.type),
                        color: _priorityColor(n.priority),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight:
                            n.isRead ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.message),
                        Text(
                          DateFormatter.timeAgo(n.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.grey400,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: n.isRead
                        ? null
                        : () => context
                            .read<NotificationsBloc>()
                            .add(NotificationMarkReadRequested(n.id)),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return AppColors.error;
      case 'HIGH':
        return AppColors.warning;
      case 'MEDIUM':
        return AppColors.info;
      default:
        return AppColors.grey400;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'SALE':
        return Icons.receipt_outlined;
      case 'LOW_STOCK':
        return Icons.inventory_2_outlined;
      case 'SECURITY':
        return Icons.security_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
