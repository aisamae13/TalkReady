import 'package:flutter/material.dart';
import 'dart:math' as math;

class CustomBottomNavItem {
  final IconData icon;
  final String label;

  CustomBottomNavItem({required this.icon, required this.label});
}

class AnimatedBottomNavBar extends StatefulWidget {
  final List<CustomBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color activeColor;
  final Color inactiveColor;
  final Color backgroundColor;
  final Color notchColor;
  final double barHeight;
  final double iconSize;
  final double selectedIconSize;
  final double selectedIconPadding;
  final Duration animationDuration;
  final double iconProtrusion;
  final double extraNotchDepth;
  final double? customNotchWidthFactor; // <-- New optional parameter

  const AnimatedBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.activeColor = Colors.black,
    this.inactiveColor = Colors.black,
    this.backgroundColor = const Color(0xFF2196F3),
    this.notchColor = Colors.white,
    this.barHeight = 18.0,
    this.iconSize = 24.0,
    this.selectedIconSize = 28.0,
    this.selectedIconPadding = 10.0,
    this.animationDuration = const Duration(milliseconds: 300),
    this.iconProtrusion = 18.0,
    this.extraNotchDepth = 8.5,
    this.customNotchWidthFactor, // <-- Initialize new parameter
  });

  @override
  State<AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<AnimatedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late int _oldIndex;

  @override
  void initState() {
    super.initState();
    _oldIndex = widget.currentIndex;
    _controller = AnimationController(vsync: this, duration: widget.animationDuration);
    _animation = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.currentIndex != 0) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_oldIndex != widget.currentIndex) {
      _animation = Tween<double>(
        begin: _oldIndex.toDouble(),
        end: widget.currentIndex.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.forward(from: 0.0);
      _oldIndex = widget.currentIndex;
    }
    if (widget.iconProtrusion != oldWidget.iconProtrusion ||
        widget.barHeight != oldWidget.barHeight ||
        widget.extraNotchDepth != oldWidget.extraNotchDepth ||
        widget.selectedIconSize != oldWidget.selectedIconSize ||
        widget.selectedIconPadding != oldWidget.selectedIconPadding ||
        widget.customNotchWidthFactor != oldWidget.customNotchWidthFactor) { // <-- Check new param
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double actualSelectedIconSize = widget.selectedIconSize;
    final double selectedIconPaddingValue = widget.selectedIconPadding;
    final double selectedIconCircleRadius = actualSelectedIconSize / 2 + selectedIconPaddingValue;
    final double selectedIconCircleDiameter = 2 * selectedIconCircleRadius;

    final double totalWidgetHeight = widget.barHeight + widget.iconProtrusion;
    final double painterNotchDepth = selectedIconCircleRadius + widget.extraNotchDepth;

    final double itemWidth = widget.items.isNotEmpty ? screenWidth / widget.items.length : screenWidth;

    double notchWidthFactorToUse;

    if (widget.customNotchWidthFactor != null) {
      notchWidthFactorToUse = widget.customNotchWidthFactor!;
    } else {
      // Default dynamic calculation
      const double notchToIconWidthRatio = 1.5; // Notch visual width will be ~1.5x the icon diameter
      final double desiredNotchSpan = selectedIconCircleDiameter * notchToIconWidthRatio;
      // The factor is how much of the itemWidth the notch should span
      notchWidthFactorToUse = (itemWidth > 0 && widget.items.isNotEmpty)
          ? desiredNotchSpan / itemWidth
          : 1.0; // Default if itemWidth is 0 or no items
    }

    return Container(
      height: totalWidgetHeight,
      width: screenWidth,
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: widget.iconProtrusion,
            height: widget.barHeight,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(screenWidth, widget.barHeight),
                  painter: BottomBarPainter(
                    itemCount: widget.items.length,
                    animatedIndex: _animation.value,
                    barColor: widget.backgroundColor,
                    notchDepth: painterNotchDepth,
                    notchWidthFactor: notchWidthFactorToUse, // <-- Use determined factor
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: totalWidgetHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.items.asMap().entries.map((entry) {
                int index = entry.key;
                CustomBottomNavItem item = entry.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.only(top: widget.iconProtrusion),
                      child: SizedBox(
                        height: widget.barHeight,
                        child: Center(
                          child: Opacity(
                            opacity: (_animation.value.round() == index && _controller.isAnimating) || widget.currentIndex == index ? 0.0 : 1.0,
                            child: Icon(
                              item.icon,
                              size: widget.iconSize,
                              color: widget.inactiveColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (widget.items.isNotEmpty)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                double selectedIconCenterX = itemWidth * (_animation.value + 0.5);
                double positionedLeft = selectedIconCenterX - (selectedIconCircleDiameter / 2);
                int iconToShowIndex = widget.currentIndex;
                if (_controller.isAnimating) {
                    iconToShowIndex = widget.currentIndex;
                }
                final IconData currentIconData = widget.items[iconToShowIndex].icon;
                return Positioned(
                  left: positionedLeft,
                  top: 0,
                  width: selectedIconCircleDiameter,
                  height: selectedIconCircleDiameter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.notchColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: Icon(
                      currentIconData,
                      color: widget.activeColor,
                      size: actualSelectedIconSize,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class BottomBarPainter extends CustomPainter {
  final int itemCount;
  final double animatedIndex;
  final Color barColor;
  final double notchDepth;
  final double notchWidthFactor;

  BottomBarPainter({
    required this.itemCount,
    required this.animatedIndex,
    required this.barColor,
    required this.notchDepth,
    required this.notchWidthFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;
    final path = Path();
    if (itemCount <= 0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(path, paint);
      return;
    }
    final itemWidth = size.width / itemCount;
    final notchCenter = itemWidth * (animatedIndex + 0.5);
    final notchRadius = itemWidth * notchWidthFactor / 2;
    final startX = notchCenter - notchRadius;
    final endX = notchCenter + notchRadius;
    path.moveTo(0, 0);
    path.lineTo(math.max(0, startX), 0);
    if (startX < endX && startX < size.width && endX > 0) {
      const double curveSmoothness = 0.45;
      path.cubicTo(
        startX + notchRadius * curveSmoothness,
        0,
        notchCenter - notchRadius * (1 - curveSmoothness),
        notchDepth,
        notchCenter,
        notchDepth,
      );
      path.cubicTo(
        notchCenter + notchRadius * (1 - curveSmoothness),
        notchDepth,
        endX - notchRadius * curveSmoothness,
        0,
        math.min(size.width, endX),
        0,
      );
    } else {
      path.lineTo(math.min(size.width, math.max(0, endX)), 0);
    }
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BottomBarPainter oldDelegate) {
    return oldDelegate.animatedIndex != animatedIndex ||
        oldDelegate.barColor != barColor ||
        oldDelegate.itemCount != itemCount ||
        oldDelegate.notchDepth != notchDepth ||
        oldDelegate.notchWidthFactor != notchWidthFactor;
  }
}