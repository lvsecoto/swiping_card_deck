import 'package:flutter/widgets.dart';

class SwipingGestureNotification extends Notification {
  /// 偏移位置，-1.0到1.0
  final double offsetX;
  final SwipingGesturePosition position;

  SwipingGestureNotification({
    required this.offsetX,
    required this.position,
  });
}

class DragGestureNotification extends Notification {
  /// 用户正在中间拖动，并且未用Swipe结束
  final bool isSwipingCard;

  DragGestureNotification(this.isSwipingCard);
}

/// 当前卡片的位置
enum SwipingGesturePosition {
  // 在左外区域，超过[设置的swipeThreshold]
  overLeft,

  // 在中间区域
  center,

  // 在右外区域，超过[设置的swipeThreshold]
  overRight,
}
