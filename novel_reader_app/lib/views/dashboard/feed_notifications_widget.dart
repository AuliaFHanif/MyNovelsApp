import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/feed_viewmodel.dart';
import '../../models/feed_notification.dart';

class FeedNotificationsWidget extends StatefulWidget {
  const FeedNotificationsWidget({super.key});

  @override
  State<FeedNotificationsWidget> createState() =>
      _FeedNotificationsWidgetState();
}

class _FeedNotificationsWidgetState extends State<FeedNotificationsWidget> {
  @override
  void initState() {
    super.initState();
    // Load notifications when widget initializes
    Future.microtask(() {
      context.read<FeedViewModel>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedViewModel>(
      builder: (context, viewModel, child) {
        return Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'New Posts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${viewModel.notifications.length} notification${viewModel.notifications.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        viewModel.fetchNotifications();
                      },
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              if (viewModel.isLoading)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue[700],
                    ),
                  ),
                )
              else if (viewModel.notifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No new posts',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 300,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: viewModel.notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = viewModel.notifications[index];
                      return _buildNotificationCard(
                        context,
                        notification,
                        viewModel,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    FeedNotification notification,
    FeedViewModel viewModel,
  ) {
    return Material(
      color: notification.isRead ? Colors.grey[50] : Colors.blue[50],
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () async {
          // Mark as read
          if (!notification.isRead) {
            await viewModel.markAsRead(notification.id);
          }

          // Open link
          if (await canLaunchUrl(Uri.parse(notification.postUrl))) {
            await launchUrl(
              Uri.parse(notification.postUrl),
              mode: LaunchMode.externalApplication,
            );
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artist name (subtitle)
              Text(
                notification.artistName,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              // Post title (main)
              Text(
                notification.chapterTitle ?? 'New Post',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Footer: timestamp and unread indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatTime(notification.created),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  // Delete button
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      onPressed: () async {
                        await viewModel.deleteNotification(notification.id);
                      },
                      splashRadius: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}