import 'dart:async';
import 'package:flutter/material.dart';
import 'attendance.dart';
import 'subject.dart';

class ShrinkingExpandableFAB extends StatefulWidget {
  const ShrinkingExpandableFAB({super.key});

  @override
  State<ShrinkingExpandableFAB> createState() => _ShrinkingExpandableFABState();
}

class _ShrinkingExpandableFABState extends State<ShrinkingExpandableFAB> {
  double size = 5.0;
  bool isExpanding = false; 
  bool isExpanded = false;
  Timer? holdTimer;

  void _startHold() {
    setState(() => isExpanding = true);

    Timer.periodic(Duration(milliseconds: 20), (timer) {
      if (!isExpanding || isExpanded) {
        timer.cancel();
        return;
      }
      setState(() {
        size = (size + 3).clamp(5, 60);
      });
    });

    holdTimer = Timer(const Duration(seconds: 1), () {
      if (isExpanding) {
        setState(() {
          isExpanded = true;
          size = 60;
        });
      }
    });
  }

  void _cancelHold() {
    if (!isExpanded) {
      setState(() {
        isExpanding = false;
        size = 5.0;
      });
    }
    holdTimer?.cancel();
  }

  void _closeFAB() {
    setState(() {
      isExpanded = false;
      isExpanding = false;
      size = 5.0;
    });
  }

  @override
  void dispose() {
    holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (isExpanding && !isExpanded)
          Positioned(
            bottom: 8,
            right: 10,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.3),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              onEnd: () {
                if (isExpanding && !isExpanded) setState(() {});
              },
              builder: (context, value, child) {
                return Opacity(
                  opacity: 0.6 * (1.3 - value),
                  child: Container(
                    height: 60 * value,
                    width: 60 * value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withOpacity(0.4),
                    ),
                  ),
                );
              },
            ),
          ),
        if (isExpanded)
          Positioned(
            bottom: 85,
            right: 10,
            child: FloatingActionButton(
              heroTag: "overviewFAB",
              backgroundColor: Colors.green,
              child: const Icon(Icons.dashboard_customize),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubjectWiseOverviewPage(),
                  ),
                );
              },
            ),
          ),
        if (isExpanded)
          Positioned(
            bottom: 160,
            right: 10,
            child: FloatingActionButton(
              heroTag: "attendanceFAB",
              backgroundColor: Colors.indigo,
              child: const Icon(Icons.check_circle_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AttendancePage()),
                );
              },
            ),
          ),
        Positioned(
          bottom: 8,
          right: 10,
          child: Positioned(
            bottom: 8,
            right: 10,
            child: GestureDetector(
              behavior:
                  HitTestBehavior
                      .translucent,
              onLongPressStart: (_) => _startHold(),
              onLongPressEnd: (_) => _cancelHold(),
              onTap: () {
                if (isExpanded) _closeFAB();
              },
              child: Container(
                height: 60,
                width: 60,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: size,
                  width: size,
                  curve: Curves.easeOut,
                  child:
                      isExpanded
                          ? FloatingActionButton(
                            heroTag: "closeFAB",
                            onPressed: _closeFAB,
                            child: const Icon(Icons.close),
                          )
                          : Container(
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}