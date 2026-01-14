import 'package:flutter/material.dart';

import '../../../core/routes/app_router.dart';
import 'feature_card.dart';

class FeatureGrid extends StatefulWidget {
  const FeatureGrid({super.key});

  @override
  State<FeatureGrid> createState() => _FeatureGridState();
}

class _FeatureGridState extends State<FeatureGrid>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      4,
          (index) => AnimationController(
        duration: Duration(milliseconds: 600 + (index * 100)),
        vsync: this,
      ),
    );

    _animations = _controllers
        .map((controller) => Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    )))
        .toList();

    // Start animations with staggered delay
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final features = [
      FeatureCardData(
        icon: Icons.photo_library_outlined,
        title: 'Photo Cleanup',
        subtitle: 'Remove duplicates & blurry photos',
        route: AppRouter.photoCleanup,
      ),
      FeatureCardData(
        icon: Icons.video_library_outlined,
        title: 'Video Cleanup',
        subtitle: 'Sort by size & delete large files',
        route: AppRouter.videoCleanup,
      ),
      FeatureCardData(
        icon: Icons.contacts_outlined,
        title: 'Contact Cleanup',
        subtitle: 'Remove duplicate contacts',
        route: AppRouter.contactCleanup,
      ),
      FeatureCardData(
        icon: Icons.storage_outlined,
        title: 'Storage Analysis',
        subtitle: 'View detailed storage usage',
        route: AppRouter.storageAnalysis,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemCount: features.length,
        itemBuilder: (context, index) {
          return SlideTransition(
            position: _animations[index],
            child: FadeTransition(
              opacity: _controllers[index],
              child: FeatureCard(data: features[index]),
            ),
          );
        },
      ),
    );
  }
}