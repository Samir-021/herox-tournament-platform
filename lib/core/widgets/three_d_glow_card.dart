import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/cyber_theme.dart';

class ThreeDGlowCard extends StatefulWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color glowColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool enableTilt;

  const ThreeDGlowCard({
    super.key,
    required this.child,
    this.blur = 12,
    this.opacity = 0.15,
    this.glowColor = CyberTheme.primary,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.all(8),
    this.onTap,
    this.enableTilt = true,
  });

  @override
  State<ThreeDGlowCard> createState() => _ThreeDGlowCardState();
}

class _ThreeDGlowCardState extends State<ThreeDGlowCard> {
  double _rotateX = 0.0;
  double _rotateY = 0.0;
  bool _isHovered = false;

  void _updateTilt(Offset localPos, Size size) {
    if (!widget.enableTilt) return;

    // Calculate relative coordinates from -1.0 to 1.0
    final relativeX = (localPos.dx / size.width) * 2 - 1;
    final relativeY = (localPos.dy / size.height) * 2 - 1;

    setState(() {
      // Limit maximum tilt angle to ~0.08 radians (approx 4.5 degrees)
      _rotateX = -relativeY * 0.08;
      _rotateY = relativeX * 0.08;
    });
  }

  void _resetTilt() {
    setState(() {
      _rotateX = 0.0;
      _rotateY = 0.0;
      _isHovered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.hasBoundedWidth ? constraints.maxWidth : 300,
            constraints.hasBoundedHeight ? constraints.maxHeight : 200,
          );

          return MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onHover: (details) => _updateTilt(details.localPosition, size),
            onExit: (_) => _resetTilt(),
            child: GestureDetector(
              onPanUpdate: (details) => _updateTilt(details.localPosition, size),
              onPanEnd: (_) => _resetTilt(),
              onTapDown: (_) => setState(() => _isHovered = true),
              onTapUp: (_) => _resetTilt(),
              onTapCancel: () => _resetTilt(),
              onTap: widget.onTap,
              child: TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(_rotateX, _rotateY),
                ),
                duration: CyberMotion.fast,
                curve: CyberMotion.snappyCurve,
                builder: (context, tilt, _) {
                  // Apply 3D rotation and scaling on hover
                  final scale = _isHovered ? 1.03 : 1.0;
                  final transformMatrix = Matrix4.identity()
                    ..setEntry(3, 2, 0.0015) // Perspective depth parameter
                    ..rotateX(tilt.dx)
                    ..rotateY(tilt.dy)
                    ..scaleByDouble(scale, scale, 1.0, 1.0);

                  return Transform(
                    transform: transformMatrix,
                    alignment: FractionalOffset.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
                        child: AnimatedContainer(
                          duration: CyberMotion.medium,
                          curve: CyberMotion.snappyCurve,
                          padding: widget.padding,
                          decoration: BoxDecoration(
                            color: CyberTheme.surface.withValues(alpha: widget.opacity),
                            borderRadius: BorderRadius.circular(widget.borderRadius),
                            border: Border.all(
                              color: widget.glowColor.withValues(alpha: _isHovered ? 0.6 : 0.25),
                              width: _isHovered ? 1.5 : 1.1,
                            ),
                            boxShadow: [
                              // AAA Neon layered glow shadow
                              BoxShadow(
                                color: widget.glowColor.withValues(alpha: _isHovered ? 0.35 : 0.12),
                                blurRadius: _isHovered ? 22 : 10,
                                spreadRadius: _isHovered ? 3 : 0,
                              ),
                              BoxShadow(
                                color: widget.glowColor.withValues(alpha: _isHovered ? 0.15 : 0.04),
                                blurRadius: _isHovered ? 40 : 20,
                                spreadRadius: _isHovered ? 6 : 0,
                              ),
                            ],
                          ),
                          child: widget.child,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
