import 'package:flutter/material.dart';

/// Sweeps a soft highlight across its child. Wrap grey boxes shaped like
/// the content that is about to load.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting: keep the shapes, drop the sweep.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final direction = Directionality.of(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [colors.surfaceContainerHighest, colors.surfaceContainerLow, colors.surfaceContainerHighest],
          stops: const [0.35, 0.5, 0.65],
          transform: _Slide(_controller.value),
        ).createShader(bounds, textDirection: direction),
        child: child,
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = bounds.width * (progress * 2 - 1);
    return Matrix4.translationValues(textDirection == TextDirection.rtl ? -dx : dx, 0, 0);
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 6});

  const SkeletonBox.circle({super.key, required double size}) : width = size, height = size, radius = size / 2;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder rows shaped like a ListTile with an avatar, a title and a
/// subtitle. Match it to your real row so nothing jumps when data arrives.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 8});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const SkeletonBox.circle(size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: i.isEven ? 0.6 : 0.45,
                      child: const SkeletonBox(height: 14),
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: i.isEven ? 0.85 : 0.7,
                      child: const SkeletonBox(height: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
