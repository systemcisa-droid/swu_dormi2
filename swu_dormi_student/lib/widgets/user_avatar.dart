import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackName;
  final double radius;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    required this.fallbackName,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final initial = fallbackName.isNotEmpty ? fallbackName[0] : '?';

    if (imageUrl == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: Text(initial, style: TextStyle(fontSize: radius * 0.75)),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(
            initial,
            style: TextStyle(fontSize: radius * 0.75),
          ),
        ),
      ),
    );
  }
}
