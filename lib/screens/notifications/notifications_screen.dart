import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/app_notification_model.dart';
import 'package:doctor_computer/providers/notification_provider.dart';
import 'package:doctor_computer/widgets/common/glass_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['Semua', 'Bottleneck', 'Reminder', 'Pembayaran', 'Voucher'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final allNotifs = provider.notifications;

    List<AppNotificationModel> filtered = allNotifs;
    if (_selectedFilter == 1) {
      filtered = allNotifs.where((n) => n.type == NotificationType.bottleneck).toList();
    } else if (_selectedFilter == 2) {
      filtered = allNotifs.where((n) => n.type == NotificationType.minigame).toList();
    } else if (_selectedFilter == 3) {
      filtered = allNotifs.where((n) => n.type == NotificationType.paymentDeadline).toList();
    } else if (_selectedFilter == 4) {
      filtered = allNotifs.where((n) => n.type == NotificationType.voucherExpiry).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (provider.unreadCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: const Text('Tandai Dibaca', style: TextStyle(color: Colors.white, fontSize: 12)),
              onPressed: () {
                provider.markAllAsRead();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: List.generate(_filters.length, (idx) {
                  final isSelected = _selectedFilter == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(_filters[idx]),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = idx);
                      },
                    ),
                  );
                }),
              ),
            ),
            // Notification list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 60, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          Text('Belum ada notifikasi', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final notif = filtered[index];
                        final timeAgo = _formatTimeAgo(notif.timestamp);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            onTap: () {
                              provider.markAsRead(notif.id);
                              if (notif.actionRoute != null) {
                                Navigator.pushNamed(context, notif.actionRoute!);
                              }
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: notif.iconColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(notif.icon, color: notif.iconColor, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notif.title,
                                              style: AppTextStyles.titleSmall.copyWith(
                                                fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (!notif.isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif.message,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: notif.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(timeAgo, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                                          if (notif.actionLabel != null)
                                            Text(
                                              '${notif.actionLabel} ➔',
                                              style: AppTextStyles.caption.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else {
      return '${diff.inDays} hari lalu';
    }
  }
}
