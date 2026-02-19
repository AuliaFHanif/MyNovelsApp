import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/feed_viewmodel.dart';
import '../../viewmodels/series_viewmodel.dart';
import '../../models/feed_notification.dart';

class FeedPanel extends StatefulWidget {
  const FeedPanel({super.key});

  @override
  State<FeedPanel> createState() => _FeedPanelState();
}

class _FeedPanelState extends State<FeedPanel> {
  @override
  void initState() {
    super.initState();
    // Load feed data when panel opens
    Future.microtask(() {
      final feedViewModel = context.read<FeedViewModel>();
      feedViewModel.fetchNotifications();
      feedViewModel.fetchMonitoredSources();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tabs
          TabBar(
            tabs: [
              Consumer<FeedViewModel>(
                builder: (context, viewModel, child) {
                  final unreadCount = viewModel.unreadCount;
                  return Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Notifications'),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  );
                },
              ),
              const Tab(text: 'Subscriptions'),
            ],
          ),
          // Content
          Expanded(
            child: TabBarView(
              children: [
                // Notifications Tab
                _buildNotificationsTab(),
                // Subscriptions Tab
                _buildSubscriptionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return Consumer<FeedViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe to artists to get updates',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: viewModel.notifications.length,
          itemBuilder: (context, index) {
            final notification = viewModel.notifications[index];
            return _buildNotificationCard(context, notification, viewModel);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    FeedNotification notification,
    FeedViewModel viewModel,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: notification.isRead ? Colors.white : Colors.blue[50],
      child: InkWell(
        onTap: () async {
          // Mark as read
          if (!notification.isRead) {
            await viewModel.markAsRead(notification.id);
          }

          // Open link
          if (await canLaunchUrl(Uri.parse(notification.postUrl))) {
            await launchUrl(Uri.parse(notification.postUrl),
                mode: LaunchMode.externalApplication);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Artist + Series
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.artistName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.seriesTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Unread indicator
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Chapter info (if available)
              if (notification.chapterTitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    notification.chapterTitle!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 12),

              // Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(notification.created),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    splashRadius: 20,
                    onPressed: () async {
                      await viewModel.deleteNotification(notification.id);
                    },
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionsTab() {
    return Consumer2<FeedViewModel, SeriesViewModel>(
      builder: (context, feedViewModel, seriesViewModel, child) {
        if (feedViewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (feedViewModel.monitoredSources.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rss_feed, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No subscriptions yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showSubscribeDialog(context, feedViewModel),
                  icon: const Icon(Icons.add),
                  label: const Text('Subscribe to Artist'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: feedViewModel.monitoredSources.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              // Add subscription button at top
              return Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _showSubscribeDialog(context, feedViewModel),
                  icon: const Icon(Icons.add),
                  label: const Text('Subscribe to Artist'),
                ),
              );
            }

            final source = feedViewModel.monitoredSources[index - 1];
            final series = seriesViewModel.seriesList
                .firstWhere((s) => s.id == source.seriesId, orElse: () => null);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                leading: Icon(
                  Icons.rss_feed,
                  color: source.isActive ? Colors.blue : Colors.grey,
                ),
                title: Text(source.artistName),
                subtitle: Text(
                  series?.title ?? 'Unknown Series',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _showUnsubscribeDialog(
                    context,
                    source,
                    feedViewModel,
                  ),
                  tooltip: 'Unsubscribe',
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubscribeDialog(BuildContext context, FeedViewModel feedViewModel) {
    final _urlController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscribe to Artist'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<SeriesViewModel>(
                builder: (context, seriesViewModel, child) {
                  if (seriesViewModel.seriesList.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'No series found. Create a series first.',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Series *',
                        border: OutlineInputBorder(),
                      ),
                      items: seriesViewModel.seriesList
                          .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.title),
                              ))
                          .toList(),
                      onChanged: (value) {},
                      validator: (value) =>
                          value == null ? 'Please select a series' : null,
                    ),
                  );
                },
              ),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'DeviantArt Artist URL *',
                  hintText:
                      'https://www.deviantart.com/[username]',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a DeviantArt URL';
                  }
                  if (!value.contains('deviantart.com')) {
                    return 'Invalid DeviantArt URL';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                // Get selected series
                final seriesViewModel =
                    context.read<SeriesViewModel>();
                // TODO: Get selected series ID from form
                final selectedSeriesId = seriesViewModel
                    .seriesList.first.id; // Placeholder - implement dropdown value

                final artistUrl = _urlController.text.trim();
                final artistName = _extractArtistName(artistUrl);

                final success = await feedViewModel.subscribeToArtist(
                  selectedSeriesId,
                  artistName,
                  artistUrl,
                );

                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Subscribed to $artistName'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(feedViewModel.errorMessage ?? 'Failed to subscribe'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  void _showUnsubscribeDialog(
    BuildContext context,
    var source,
    FeedViewModel feedViewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsubscribe?'),
        content: Text(
          'Are you sure you want to unsubscribe from ${source.artistName}? '
          'Associated notifications will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await feedViewModel.unsubscribeFromArtist(source.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unsubscribed'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
  }

  String _extractArtistName(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.pathSegments.first;
    } catch (e) {
      return 'Unknown Artist';
    }
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
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}