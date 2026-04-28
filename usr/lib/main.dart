import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const BilliardsApp());
}

class BilliardsApp extends StatelessWidget {
  const BilliardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billiards Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const BilliardsGameScreen(),
    );
  }
}

class BilliardsGameScreen extends StatefulWidget {
  const BilliardsGameScreen({super.key});

  @override
  State<BilliardsGameScreen> createState() => _BilliardsGameScreenState();
}

class _BilliardsGameScreenState extends State<BilliardsGameScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;

  // Game constants
  static const double tableWidth = 400;
  static const double tableHeight = 800;
  static const double ballRadius = 12;
  static const double pocketRadius = 22;
  static const double friction = 0.99; // Velocity multiplier per frame
  static const double restitution = 0.85; // Bounciness

  List<Ball> balls = [];
  List<Offset> pockets = [];

  bool isAiming = false;
  Offset? dragStart;
  Offset? dragCurrent;

  int score = 0;
  bool isGameOver = false;

  @override
  void initState() {
    super.initState();
    _initGame();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _initGame() {
    balls.clear();
    score = 0;
    isGameOver = false;

    // Define pockets
    pockets = [
      const Offset(0, 0),
      const Offset(tableWidth, 0),
      const Offset(0, tableHeight / 2),
      const Offset(tableWidth, tableHeight / 2),
      const Offset(0, tableHeight),
      const Offset(tableWidth, tableHeight),
    ];

    // Add Cue Ball
    balls.add(Ball(
      id: 0,
      position: const Offset(tableWidth / 2, tableHeight * 0.75),
      color: Colors.white,
    ));

    // Add Object Balls in a triangle
    double startX = tableWidth / 2;
    double startY = tableHeight * 0.25;
    double spacingX = ballRadius * 2.1;
    double spacingY = ballRadius * 1.8;

    int ballId = 1;
    List<Color> ballColors = [
      Colors.yellow, Colors.blue, Colors.red, Colors.purple, Colors.orange,
      Colors.green, Colors.brown, Colors.black, Colors.yellowAccent, Colors.blueAccent,
      Colors.redAccent, Colors.purpleAccent, Colors.deepOrange, Colors.lightGreen, Colors.brown[300]!
    ];

    for (int row = 0; row < 5; row++) {
      for (int col = 0; col <= row; col++) {
        double x = startX - (row * spacingX / 2) + (col * spacingX);
        double y = startY - (row * spacingY);
        balls.add(Ball(
          id: ballId,
          position: Offset(x, y),
          color: ballColors[(ballId - 1) % ballColors.length],
        ));
        ballId++;
      }
    }
  }

  void _tick(Duration elapsed) {
    bool ballsMoving = false;

    // Update positions and apply friction
    for (var ball in balls) {
      if (ball.isPocketed) continue;

      if (ball.velocity.distance > 0.05) {
        ball.position += ball.velocity;
        ball.velocity *= friction;
        ballsMoving = true;
      } else {
        ball.velocity = Offset.zero;
      }
    }

    // Check collisions
    _checkWallCollisions();
    _checkBallCollisions();
    _checkPockets();

    if (mounted) {
      setState(() {});
    }

    // Check game over
    if (!ballsMoving && balls.where((b) => b.id != 0 && !b.isPocketed).isEmpty) {
      isGameOver = true;
    }
  }

  void _checkWallCollisions() {
    for (var ball in balls) {
      if (ball.isPocketed) continue;

      // Left wall
      if (ball.position.dx - ballRadius < 0) {
        ball.position = Offset(ballRadius, ball.position.dy);
        ball.velocity = Offset(-ball.velocity.dx * restitution, ball.velocity.dy);
      }
      // Right wall
      else if (ball.position.dx + ballRadius > tableWidth) {
        ball.position = Offset(tableWidth - ballRadius, ball.position.dy);
        ball.velocity = Offset(-ball.velocity.dx * restitution, ball.velocity.dy);
      }

      // Top wall
      if (ball.position.dy - ballRadius < 0) {
        ball.position = Offset(ball.position.dx, ballRadius);
        ball.velocity = Offset(ball.velocity.dx, -ball.velocity.dy * restitution);
      }
      // Bottom wall
      else if (ball.position.dy + ballRadius > tableHeight) {
        ball.position = Offset(ball.position.dx, tableHeight - ballRadius);
        ball.velocity = Offset(ball.velocity.dx, -ball.velocity.dy * restitution);
      }
    }
  }

  void _checkBallCollisions() {
    for (int i = 0; i < balls.length; i++) {
      if (balls[i].isPocketed) continue;
      
      for (int j = i + 1; j < balls.length; j++) {
        if (balls[j].isPocketed) continue;

        Ball b1 = balls[i];
        Ball b2 = balls[j];

        Offset delta = b2.position - b1.position;
        double dist = delta.distance;
        double minDist = ballRadius * 2;

        if (dist < minDist && dist > 0) {
          // Resolve overlap
          double overlap = minDist - dist;
          Offset normal = delta / dist;
          
          b1.position -= normal * (overlap / 2);
          b2.position += normal * (overlap / 2);

          // Calculate relative velocity
          Offset relVel = b1.velocity - b2.velocity;
          double velAlongNormal = relVel.dx * normal.dx + relVel.dy * normal.dy;

          // Do not resolve if velocities are separating
          if (velAlongNormal > 0) continue;

          double jImpulse = -(1 + restitution) * velAlongNormal;
          jImpulse /= 2; // Since masses are equal (1 + 1)

          Offset impulse = normal * jImpulse;
          b1.velocity += impulse;
          b2.velocity -= impulse;
        }
      }
    }
  }

  void _checkPockets() {
    for (var ball in balls) {
      if (ball.isPocketed) continue;

      for (var pocket in pockets) {
        if ((ball.position - pocket).distance < pocketRadius) {
          if (ball.id == 0) {
            // Cue ball pocketed - Scratch! Reset it
            ball.velocity = Offset.zero;
            ball.position = const Offset(tableWidth / 2, tableHeight * 0.75);
            score -= 1; // Penalty
          } else {
            ball.isPocketed = true;
            ball.velocity = Offset.zero;
            score += 10;
          }
        }
      }
    }
  }

  bool _areAllBallsStopped() {
    for (var ball in balls) {
      if (ball.velocity.distance > 0) return false;
    }
    return true;
  }

  void _handlePanStart(DragStartDetails details, double scale, Offset offset) {
    if (!_areAllBallsStopped() || isGameOver) return;

    Offset localPos = (details.localPosition - offset) / scale;
    Ball cueBall = balls[0];

    // Check if clicking near cue ball
    if ((localPos - cueBall.position).distance < ballRadius * 4) {
      isAiming = true;
      dragStart = localPos;
      dragCurrent = localPos;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, double scale, Offset offset) {
    if (isAiming) {
      setState(() {
        dragCurrent = (details.localPosition - offset) / scale;
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (isAiming && dragStart != null && dragCurrent != null) {
      Ball cueBall = balls[0];
      Offset dragVector = dragStart! - dragCurrent!;
      
      // Cap maximum power
      if (dragVector.distance > 150) {
        dragVector = (dragVector / dragVector.distance) * 150;
      }

      cueBall.velocity = dragVector * 0.15; // Power multiplier
      
      setState(() {
        isAiming = false;
        dragStart = null;
        dragCurrent = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billiards'),
        backgroundColor: Colors.black87,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Score: $score',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _initGame();
              });
            },
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate scale to fit table in screen
          double scale = min(
            (constraints.maxWidth - 32) / tableWidth,
            (constraints.maxHeight - 32) / tableHeight,
          );

          double scaledWidth = tableWidth * scale;
          double scaledHeight = tableHeight * scale;

          Offset offset = Offset(
            (constraints.maxWidth - scaledWidth) / 2,
            (constraints.maxHeight - scaledHeight) / 2,
          );

          return GestureDetector(
            onPanStart: (details) => _handlePanStart(details, scale, offset),
            onPanUpdate: (details) => _handlePanUpdate(details, scale, offset),
            onPanEnd: _handlePanEnd,
            child: Container(
              color: const Color(0xFF1E1E1E),
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    width: scaledWidth,
                    height: scaledHeight,
                    child: CustomPaint(
                      painter: BilliardsPainter(
                        balls: balls,
                        pockets: pockets,
                        tableWidth: tableWidth,
                        tableHeight: tableHeight,
                        ballRadius: ballRadius,
                        pocketRadius: pocketRadius,
                        isAiming: isAiming,
                        dragStart: dragStart,
                        dragCurrent: dragCurrent,
                      ),
                    ),
                  ),
                  if (isGameOver)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'You Win!',
                              style: TextStyle(
                                  fontSize: 32,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Final Score: $score',
                              style: const TextStyle(fontSize: 20, color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () {
                                setState(() {
                                  _initGame();
                                });
                              },
                              child: const Text('Play Again'),
                            )
                          ],
                        ),
                      ),
                    )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class Ball {
  final int id;
  Offset position;
  Offset velocity;
  final Color color;
  bool isPocketed;

  Ball({
    required this.id,
    required this.position,
    this.velocity = Offset.zero,
    required this.color,
    this.isPocketed = false,
  });
}

class BilliardsPainter extends CustomPainter {
  final List<Ball> balls;
  final List<Offset> pockets;
  final double tableWidth;
  final double tableHeight;
  final double ballRadius;
  final double pocketRadius;
  final bool isAiming;
  final Offset? dragStart;
  final Offset? dragCurrent;

  BilliardsPainter({
    required this.balls,
    required this.pockets,
    required this.tableWidth,
    required this.tableHeight,
    required this.ballRadius,
    required this.pocketRadius,
    required this.isAiming,
    required this.dragStart,
    required this.dragCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale canvas to logical game coordinates
    canvas.scale(size.width / tableWidth, size.height / tableHeight);

    // 1. Draw Table Wood Border
    final borderPaint = Paint()
      ..color = const Color(0xFF5C3A21)
      ..style = PaintingStyle.fill;
    
    const double borderWidth = 20;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-borderWidth, -borderWidth, tableWidth + borderWidth, tableHeight + borderWidth),
        const Radius.circular(16),
      ),
      borderPaint,
    );

    // 2. Draw Green Cloth
    final clothPaint = Paint()
      ..color = const Color(0xFF0F6B32)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, tableWidth, tableHeight), clothPaint);

    // 3. Draw Pockets
    final pocketPaint = Paint()..color = Colors.black;
    for (var pocket in pockets) {
      canvas.drawCircle(pocket, pocketRadius, pocketPaint);
    }

    // 4. Draw Aiming Line & Cue Stick (if aiming)
    if (isAiming && dragStart != null && dragCurrent != null) {
      Ball cueBall = balls[0];
      Offset dragVector = dragStart! - dragCurrent!;
      
      // Cue stick line
      final cuePaint = Paint()
        ..color = Colors.brown[200]!
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      Offset cueStickEnd = cueBall.position - dragVector;
      Offset cueStickStart = cueBall.position - dragVector.normalize() * (dragVector.distance + 150);
      
      canvas.drawLine(cueStickEnd, cueStickStart, cuePaint);

      // Aim trajectory
      final aimPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      Offset trajectoryEnd = cueBall.position + dragVector.normalize() * 300;
      canvas.drawLine(cueBall.position, trajectoryEnd, aimPaint);
    }

    // 5. Draw Balls
    for (var ball in balls) {
      if (ball.isPocketed) continue;

      // Shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(ball.position + const Offset(2, 2), ballRadius, shadowPaint);

      // Ball Color
      final ballPaint = Paint()..color = ball.color;
      canvas.drawCircle(ball.position, ballRadius, ballPaint);

      // Highlight for 3D effect
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(
        ball.position - const Offset(3, 3),
        ballRadius * 0.3,
        highlightPaint,
      );

      // Numbers for object balls
      if (ball.id != 0) {
        // White circle background for number
        final numberBgPaint = Paint()..color = Colors.white;
        canvas.drawCircle(ball.position, ballRadius * 0.5, numberBgPaint);

        TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: '${ball.id}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          ball.position - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BilliardsPainter oldDelegate) => true;
}

extension OffsetExt on Offset {
  Offset normalize() {
    double dist = distance;
    if (dist == 0) return Offset.zero;
    return Offset(dx / dist, dy / dist);
  }
}
