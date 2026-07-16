import 'dart:ui';
import 'package:flutter/material.dart';

/// 液态玻璃容器组件
///
/// 使用 BackdropFilter 对背景进行模糊处理，配合半透明填充和渐变边框，
/// 实现 visionOS / Fluent Design 风格的磨砂玻璃效果。
class GlassContainer extends StatelessWidget {
  /// 模糊强度（sigma 值），默认 4（轻微模糊）
  final double blurSigma;

  /// 背景透明度，默认 0.05
  final double backgroundOpacity;

  /// 边框透明度，默认 0.1
  final double borderOpacity;

  /// 圆角半径，默认 20
  final double borderRadius;

  /// 是否显示渐变边框高光（左上亮、右下暗）
  final bool showGradientBorder;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 外边距
  final EdgeInsetsGeometry? margin;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// 子组件
  final Widget? child;

  const GlassContainer({
    super.key,
    this.blurSigma = 4.0,
    this.backgroundOpacity = 0.05,
    this.borderOpacity = 0.1,
    this.borderRadius = 20.0,
    this.showGradientBorder = true,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget container = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          margin: margin,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(backgroundOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: showGradientBorder
                ? null // 使用下方的渐变边框替代
                : Border.all(
                    color: Colors.white.withOpacity(borderOpacity),
                  ),
          ),
          child: child,
        ),
      ),
    );

    // 渐变边框高光：左上较亮，右下较暗，模拟光线反射
    if (showGradientBorder) {
      container = Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: const LinearGradient(
            colors: [
              Color(0x33FFFFFF), // 左上 ~20% 白色
              Color(0x08FFFFFF), // 右下 ~3% 白色
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.0), // 边框宽度
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 1),
            child: container,
          ),
        ),
      );
    }

    return container;
  }
}
