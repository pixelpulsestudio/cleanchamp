import 'package:flutter/material.dart';

class FeatureCard extends StatefulWidget {
  final FeatureCardData data;

  const FeatureCard({super.key, required this.data});

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _getGradientColors() {
    switch (widget.data.title) {
      case 'Photo Cleanup':
        return [
          Colors.purple.shade100,
          Colors.purple.shade50,
          Colors.white,
        ];
      case 'Video Cleanup':
        return [
          Colors.blue.shade100,
          Colors.blue.shade50,
          Colors.white,
        ];
      case 'Contact Cleanup':
        return [
          Colors.green.shade100,
          Colors.green.shade50,
          Colors.white,
        ];
      case 'Storage Analysis':
        return [
          Colors.orange.shade100,
          Colors.orange.shade50,
          Colors.white,
        ];
      default:
        return [
          Colors.grey.shade100,
          Colors.grey.shade50,
          Colors.white,
        ];
    }
  }

  Color _getIconColor() {
    switch (widget.data.title) {
      case 'Photo Cleanup':
        return Colors.purple.shade600;
      case 'Video Cleanup':
        return Colors.blue.shade600;
      case 'Contact Cleanup':
        return Colors.green.shade600;
      case 'Storage Analysis':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Color _getAccentColor() {
    switch (widget.data.title) {
      case 'Photo Cleanup':
        return Colors.purple.shade700;
      case 'Video Cleanup':
        return Colors.blue.shade700;
      case 'Contact Cleanup':
        return Colors.green.shade700;
      case 'Storage Analysis':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _controller.forward();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _controller.reverse();
            Navigator.pushNamed(context, widget.data.route);
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
            _controller.reverse();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getGradientColors(),
                stops: const [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getIconColor().withOpacity(0.15),
                  blurRadius: _isPressed ? 8 : 15,
                  offset: Offset(0, _isPressed ? 3 : 6),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: _isPressed ? 15 : 25,
                  offset: Offset(0, _isPressed ? 6 : 12),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: _getIconColor().withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.data.icon,
                      size: 20,
                      color: _getIconColor(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      widget.data.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _getAccentColor(),
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Flexible(
                    child: Text(
                      widget.data.subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.1,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _getIconColor().withOpacity(0.1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Start',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _getAccentColor(),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 9,
                          color: _getAccentColor(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FeatureCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  FeatureCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}