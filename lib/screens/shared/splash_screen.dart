import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'profiles_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<double> _progress;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(milliseconds: 5000));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, a, __) => const ProfilesScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildFallingItem(int index) {
    final icons = [
      Icons.attach_money,
      Icons.monetization_on,
      Icons.savings,
      Icons.show_chart,
      Icons.currency_bitcoin,
      Icons.star
    ];
    final icon = icons[index % icons.length];
    final colors = [
      Colors.greenAccent,
      Colors.amber,
      Colors.white,
      Colors.blueAccent,
      Colors.orange,
      Colors.white70
    ];
    final color = colors[index % colors.length];

    final size = _random.nextDouble() * 15 + 15;
    final left = _random.nextDouble() * MediaQuery.of(context).size.width;
    final duration = _random.nextInt(3000) + 2000;

    return Positioned(
      left: left,
      top: -50,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: -50, end: MediaQuery.of(context).size.height + 100),
        duration: Duration(milliseconds: duration),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, value),
            child: child,
          );
        },
        child: Opacity(
          opacity: _random.nextDouble() * 0.5 + 0.3,
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0D1B2A),
                  Color(0xFF133B5C),
                  Color(0xFF0D1B2A)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 💸 Ícones caindo
          ...List.generate(25, (i) => _buildFallingItem(i)),

          // ✨ Glow central
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 🧠 LOGO COM ZOOM
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Image.asset(
                  'assets/images/splash_logo.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // 🔽 LOADING
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _progress,
                    builder: (_, __) {
                      final value = (_progress.value * 100).toInt();
                      return Text(
                        '$value%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'PREPARANDO SUAS FINANÇAS...',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 80),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) {
                        return LinearProgressIndicator(
                          value: _progress.value,
                          minHeight: 2,
                          backgroundColor: Colors.white24,
                          color: Colors.amber,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
