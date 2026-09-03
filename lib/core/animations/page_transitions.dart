import 'package:flutter/material.dart';

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = Curves.easeOutCubic;
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
    final curvedSecondary = CurvedAnimation(parent: secondaryAnimation, curve: curve);

    return Stack(
      children: [
        // Outgoing page - fade out + slide left
        FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(curvedSecondary),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.3, 0),
            ).animate(curvedSecondary),
            child: child,
          ),
        ),
        // Incoming page - fade in + slide from right
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.3, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        ),
      ],
    );
  }
}

class AppPageTransitionsBuilderVertical extends PageTransitionsBuilder {
  const AppPageTransitionsBuilderVertical();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = Curves.easeOutCubic;
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: curvedAnimation,
        child: child,
      ),
    );
  }
}