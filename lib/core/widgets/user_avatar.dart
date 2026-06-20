import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Single source of truth for a user's avatar across the app: shows the uploaded
/// photo when [url] is set, otherwise the name initial. Every user-bearing card
/// (feed, comments, CRM, messages, activities, team, agents) should use this so
/// a profile photo appears everywhere the moment it's uploaded.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.url, this.radius = 18, this.background});

  final String name;
  final String? url;
  final double radius;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    final n = name.trim();
    final initial = n.isNotEmpty ? n[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: background ?? AppColors.primary,
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl
          ? null
          : Text(initial,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: radius * 0.8)),
    );
  }
}
