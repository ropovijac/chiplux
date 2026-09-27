import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/library_service.dart';
import 'services/cloud_sync_service.dart';
import 'comments_page.dart';
import 'services/tmdb_service.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'services/avatar_service.dart';
import 'services/media_user_data_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/critic_service.dart';
import 'dart:math' as math;
import 'package:flutter/rendering.dart'
    show ScrollCacheExtent;
    import 'services/community_service.dart';

const Color chipluxBackground =
    Color(0xFF07111C);

const Color chipluxSurface =
    Color(0xFF111D2A);

const Color chipluxSurfaceLight =
    Color(0xFF162536);

const Color chipluxCyan =
    Color(0xFF43E8FF);

const Color chipluxViolet =
    Color(0xFF8B7CFF);

const Color chipluxPurple =
    Color(0xFFD65CFF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );

  const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
);

await Supabase.initialize(
  url: supabaseUrl,
  publishableKey: supabasePublishableKey,
);

  await LibraryService.instance.init();

await MedalPinService.instance
    .init();

await CriticService.instance
    .refresh();

PublicStatsSyncService.instance
    .start();

runApp(
  const ChipluxApp(),
);
}

enum ChipluxBackgroundStyle {
  discover,
  search,
  watch,
  community,
  profile,
}

_AchievementGroup
    _movieAchievementGroupFor(
  int moviesWatched,
) {
  return _AchievementGroup(
    id: 'movies_watched',

    title:
        'Movies Watched',

    description:
        'Keep watching movies to upgrade this medal.',

    icon:
        Icons.movie_rounded,

    current:
        moviesWatched,

    tiers: [
      _Achievement(
        id:
            'movies_2',
        title:
            'First Screening',
        description:
            'Watch 2 movies',
        icon:
            Icons.movie_rounded,
        current:
            moviesWatched,
        target:
            2,
        rarity:
            _AchievementRarity
                .common,
      ),

      _Achievement(
        id:
            'movies_8',
        title:
            'Weekend Watcher',
        description:
            'Watch 8 movies',
        icon:
            Icons.movie_rounded,
        current:
            moviesWatched,
        target:
            8,
        rarity:
            _AchievementRarity
                .uncommon,
      ),

      _Achievement(
        id:
            'movies_16',
        title:
            'Film Explorer',
        description:
            'Watch 16 movies',
        icon:
            Icons.local_movies_rounded,
        current:
            moviesWatched,
        target:
            16,
        rarity:
            _AchievementRarity
                .uncommon,
      ),

      _Achievement(
        id:
            'movies_32',
        title:
            'Film Collector',
        description:
            'Watch 32 movies',
        icon:
            Icons.video_library_rounded,
        current:
            moviesWatched,
        target:
            32,
        rarity:
            _AchievementRarity
                .rare,
      ),

      _Achievement(
        id:
            'movies_64',
        title:
            'Film Buff',
        description:
            'Watch 64 movies',
        icon:
            Icons.theaters_rounded,
        current:
            moviesWatched,
        target:
            64,
        rarity:
            _AchievementRarity
                .rare,
      ),

      _Achievement(
        id:
            'movies_128',
        title:
            'Cinephile',
        description:
            'Watch 128 movies',
        icon:
            Icons.auto_awesome_rounded,
        current:
            moviesWatched,
        target:
            128,
        rarity:
            _AchievementRarity
                .epic,
      ),

      _Achievement(
        id:
            'movies_512',
        title:
            'Cinema Master',
        description:
            'Watch 512 movies',
        icon:
            Icons.workspace_premium_rounded,
        current:
            moviesWatched,
        target:
            512,
        rarity:
            _AchievementRarity
                .legendary,
      ),

      _Achievement(
        id:
            'movies_1024',
        title:
            'Screen Legend',
        description:
            'Watch 1024 movies',
        icon:
            Icons.diamond_rounded,
        current:
            moviesWatched,
        target:
            1024,
        rarity:
            _AchievementRarity
                .legendary,
      ),
    ],
  );
}

Future<void> _checkMovieAchievementUnlock(
  BuildContext context, {
  required int previousCount,
  required int currentCount,
}) async {
  // Only care when the movie count
  // actually increased.
  if (currentCount <= previousCount) {
    return;
  }

  final group =
      _movieAchievementGroupFor(
    currentCount,
  );

  // Find every threshold crossed by
  // this change.
  final newlyReached =
      group.tiers.where(
    (achievement) {
      return previousCount <
              achievement.target &&
          currentCount >=
              achievement.target;
    },
  ).toList();

  if (newlyReached.isEmpty) {
    return;
  }

  for (final achievement
      in newlyReached) {
    if (!context.mounted) {
      return;
    }

    // Let the completion animation
    // happen before showing the medal.
    await Future<void>.delayed(
      const Duration(
        milliseconds: 550,
      ),
    );

    if (!context.mounted) {
      return;
    }

    try {
  await CommunityService.instance
      .deleteActivity(
    activityType:
        'achievement_unlocked',
    achievementId:
        achievement.id,
  );

  await CommunityService.instance
      .tryCreateActivity(
    activityType:
        'achievement_unlocked',
    achievementId:
        achievement.id,
    achievementTitle:
        achievement.title,
  );
} catch (e) {
  debugPrint(
    'Could not create achievement activity: $e',
  );
}

if (!context.mounted) {
  return;
}

await _showAchievementUnlocked(
  context,
  achievement,
);
  }
}

Future<void> _showAchievementUnlocked(
  BuildContext context,
  _Achievement achievement,
) async {
  await showGeneralDialog<void>(
    context: context,

    barrierDismissible: false,

    barrierLabel:
        'Achievement unlocked',

    barrierColor:
        Colors.black.withValues(
      alpha: 0.78,
    ),

    transitionDuration:
        const Duration(
      milliseconds: 320,
    ),

    transitionBuilder: (
      context,
      animation,
      secondaryAnimation,
      child,
    ) {
      final curved =
          CurvedAnimation(
        parent: animation,
        curve:
            Curves.easeOutBack,
      );

      return FadeTransition(
        opacity:
            animation,
        child:
            ScaleTransition(
          scale:
              Tween<double>(
            begin: 0.82,
            end: 1.0,
          ).animate(
            curved,
          ),
          child:
              child,
        ),
      );
    },

    pageBuilder: (
      context,
      animation,
      secondaryAnimation,
    ) {
      return _AchievementUnlockDialog(
        achievement:
            achievement,
      );
    },
  );
}

class _AchievementUnlockDialog
    extends StatefulWidget {
  final _Achievement
      achievement;

  const _AchievementUnlockDialog({
    required this.achievement,
  });

  @override
  State<_AchievementUnlockDialog>
      createState() =>
          _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState
    extends State<
        _AchievementUnlockDialog>
    with
        SingleTickerProviderStateMixin {
  late final AnimationController
      _fireworksController;

  @override
  void initState() {
    super.initState();

    _fireworksController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 1800,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _fireworksController
        .dispose();

    super.dispose();
  }

  @override
Widget build(
  BuildContext context,
) {
  final achievement =
      widget.achievement;

  final colors =
      _achievementPopupColors(
    achievement,
  );

  final screenSize =
    MediaQuery.sizeOf(
  context,
);

final textScale =
    MediaQuery.textScalerOf(
  context,
).scale(1.0);

final dialogWidth =
    math.min(
  340.0,
  screenSize.width - 40,
);

final extraHeight =
    ((textScale - 1.0)
            .clamp(
      0.0,
      0.5,
    )) *
        140;

final dialogHeight =
    470.0 + extraHeight;

  return Material(
    color:
        Colors.transparent,

    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 20,
            vertical: 20,
          ),

          child: SizedBox(
  width: dialogWidth,
  height: dialogHeight,

            child: Stack(
              alignment:
                  Alignment.topCenter,

              clipBehavior:
                  Clip.none,

              children: [
                // =========================
                // FIREWORKS
                // =========================

                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,

                  child: SizedBox(
                    height: 155,

                    child:
                        AnimatedBuilder(
                      animation:
                          _fireworksController,

                      builder: (
                        context,
                        _,
                      ) {
                        return CustomPaint(
                          painter:
                              _AchievementFireworksPainter(
                            progress:
                                _fireworksController
                                    .value,

                            colors:
                                colors,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // =========================
                // LARGE TRANSPARENT MEDAL
                // =========================

                Positioned(
                  top: 100,

                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.05,

                      child:
                          Transform.scale(
                        scale: 3.2,

                        child:
                            _AchievementMedal(
                          achievement:
                              achievement,
                        ),
                      ),
                    ),
                  ),
                ),

                // =========================
                // ACHIEVEMENT CARD
                // =========================

                Positioned(
                  top: 120,
                  left: 0,
                  right: 0,

                  child: Container(
                    padding:
                        const EdgeInsets
                            .all(
                      1.4,
                    ),

                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius
                              .circular(
                        26,
                      ),

                      gradient:
                          LinearGradient(
                        begin:
                            Alignment
                                .topLeft,
                        end:
                            Alignment
                                .bottomRight,
                        colors:
                            colors,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color:
                              _achievementAccent(
                            achievement
                                .rarity,
                          ).withValues(
                            alpha:
                                0.24,
                          ),

                          blurRadius:
                              28,

                          spreadRadius:
                              2,
                        ),
                      ],
                    ),

                    child: Container(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        24,
                        28,
                        24,
                        22,
                      ),

                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          25,
                        ),

                        color:
                            Color.alphaBlend(
                          chipluxViolet
                              .withValues(
                            alpha:
                                0.035,
                          ),

                          chipluxSurface,
                        ),
                      ),

                      child: Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,

                        children: [
                          // =========================
                          // LABEL
                          // =========================

                          const GradientText(
                            'ACHIEVEMENT UNLOCKED',

                            style:
                                TextStyle(
                              fontSize:
                                  12,

                              fontWeight:
                                  FontWeight
                                      .w800,

                              letterSpacing:
                                  1.7,
                            ),
                          ),

                          const SizedBox(
                            height: 24,
                          ),

                          // =========================
                          // NORMAL MEDAL
                          // =========================

                          Transform.scale(
                            scale: 1.35,

                            child:
                                _AchievementMedal(
                              achievement:
                                  achievement,
                            ),
                          ),

                          const SizedBox(
                            height: 27,
                          ),

                          // =========================
                          // TITLE
                          // =========================

                          Text(
                            achievement
                                .title,

                            textAlign:
                                TextAlign
                                    .center,

                            style:
                                const TextStyle(
                              color:
                                  Colors.white,

                              fontSize:
                                  23,

                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 7,
                          ),

                          // =========================
                          // DESCRIPTION
                          // =========================

                          Text(
                            achievement
                                .description,

                            textAlign:
                                TextAlign
                                    .center,

                            style:
                                const TextStyle(
                              color:
                                  Colors
                                      .white60,

                              fontSize:
                                  14,
                            ),
                          ),

                          const SizedBox(
                            height: 25,
                          ),

                          // =========================
                          // GREAT BUTTON
                          // =========================

                          SizedBox(
                            width:
                                double
                                    .infinity,

                            height: 48,

                            child:
                                ElevatedButton(
                              onPressed:
                                  () {
                                Navigator.pop(
                                  context,
                                );
                              },

                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    chipluxSurfaceLight,

                                foregroundColor:
                                    Colors.white,

                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    15,
                                  ),
                                ),
                              ),

                              child:
                                  const Text(
                                'Great!',

                                style:
                                    TextStyle(
                                  fontSize:
                                      15,

                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _AchievementFireworksPainter
    extends CustomPainter {
  final double progress;
  final List<Color> colors;

  const _AchievementFireworksPainter({
    required this.progress,
    required this.colors,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    _drawFirework(
      canvas,
      size,
      const Offset(
        0.22,
        0.62,
      ),
      delay: 0.00,
      particleCount: 14,
    );

    _drawFirework(
      canvas,
      size,
      const Offset(
        0.50,
        0.30,
      ),
      delay: 0.28,
      particleCount: 17,
    );

    _drawFirework(
      canvas,
      size,
      const Offset(
        0.78,
        0.58,
      ),
      delay: 0.56,
      particleCount: 14,
    );

    _drawFirework(
      canvas,
      size,
      const Offset(
        0.38,
        0.70,
      ),
      delay: 0.78,
      particleCount: 11,
    );
  }

  void _drawFirework(
    Canvas canvas,
    Size size,
    Offset normalizedCenter, {
    required double delay,
    required int particleCount,
  }) {
    final double local =
        (progress +
                1.0 -
                delay) %
            1.0;

    // Each firework appears only
    // during part of the loop.
    if (local > 0.72) {
      return;
    }

    final double normalized =
        (local / 0.72)
            .clamp(
              0.0,
              1.0,
            );

    final double expansion =
        Curves.easeOutCubic
            .transform(
      normalized,
    );

    final double fade =
        (1.0 -
                normalized)
            .clamp(
              0.0,
              1.0,
            );

    final center =
        Offset(
      size.width *
          normalizedCenter.dx,
      size.height *
          normalizedCenter.dy,
    );

    final maxRadius =
        28 +
            size.width *
                0.11;

    for (int i = 0;
        i < particleCount;
        i++) {
      final angle =
          (math.pi *
                  2 /
                  particleCount) *
              i +
          delay *
              math.pi;

      final variation =
          0.78 +
              (i % 4) *
                  0.08;

      final distance =
          maxRadius *
              expansion *
              variation;

      final position =
          center +
              Offset(
                math.cos(
                      angle,
                    ) *
                    distance,
                math.sin(
                      angle,
                    ) *
                    distance,
              );

      final color =
          colors[
              i %
                  colors.length];

      final particlePaint =
          Paint()
            ..color =
                color.withValues(
              alpha:
                  fade *
                      0.95,
            );

      final trailPaint =
          Paint()
            ..color =
                color.withValues(
              alpha:
                  fade *
                      0.30,
            )
            ..strokeWidth =
                1.4
            ..strokeCap =
                StrokeCap.round;

      final trailLength =
          7.0 +
              (i % 3) *
                  2.5;

      final trailEnd =
          position -
              Offset(
                math.cos(
                      angle,
                    ) *
                    trailLength,
                math.sin(
                      angle,
                    ) *
                    trailLength,
              );

      canvas.drawLine(
        trailEnd,
        position,
        trailPaint,
      );

      canvas.drawCircle(
        position,
        1.8 +
            (i % 3) *
                0.45,
        particlePaint,
      );
    }

    // Small flash at explosion center.
    final flashFade =
        (1.0 -
                normalized *
                    4.0)
            .clamp(
              0.0,
              1.0,
            );

    if (flashFade > 0) {
      canvas.drawCircle(
        center,
        4 +
            normalized *
                5,
        Paint()
          ..color =
              Colors.white
                  .withValues(
            alpha:
                flashFade *
                    0.85,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant
        _AchievementFireworksPainter
        oldDelegate,
  ) {
    return oldDelegate.progress !=
            progress ||
        oldDelegate.colors !=
            colors;
  }
}

List<Color> _achievementPopupColors(
  _Achievement achievement,
) {
  switch (
      achievement.target) {
    case 2:
      return const [
        Colors.white,
        Color(
          0xFF9DAAB7,
        ),
      ];

    case 8:
      return const [
        chipluxCyan,
        Color(
          0xFF64BFFF,
        ),
      ];

    case 16:
      return const [
        chipluxCyan,
        chipluxViolet,
      ];

    case 32:
      return const [
        Color(
          0xFFFFE49A,
        ),
        Color(
          0xFFFFC857,
        ),
      ];

    case 64:
      return const [
        Color(
          0xFFFFC857,
        ),
        Color(
          0xFFFF5C72,
        ),
      ];

    case 128:
      return const [
        Color(
          0xFFFF5C72,
        ),
        chipluxPurple,
      ];

    case 512:
    case 1024:
      return const [
        chipluxCyan,
        chipluxViolet,
        chipluxPurple,
        Color(
          0xFFFFC857,
        ),
      ];

    default:
      return const [
        chipluxCyan,
        chipluxViolet,
      ];
  }
}

class ChipluxBackground
    extends StatelessWidget {
  final ChipluxBackgroundStyle style;
  final Widget child;

  const ChipluxBackground({
    super.key,
    required this.style,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter:
            _ChipluxBackgroundPainter(
          style,
        ),
        child: child,
      ),
    );
  }
}

class _ChipluxBackgroundPainter
    extends CustomPainter {
  final ChipluxBackgroundStyle style;

  const _ChipluxBackgroundPainter(
    this.style,
  );

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    // Keep our normal dark background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = chipluxBackground,
    );

    late Color firstColor;
    late Color secondColor;
    late Color thirdColor;

    switch (style) {
      case ChipluxBackgroundStyle.discover:
        firstColor = chipluxCyan;
        secondColor = chipluxViolet;
        thirdColor = chipluxPurple;
        break;

      case ChipluxBackgroundStyle.search:
        firstColor = chipluxViolet;
        secondColor = chipluxCyan;
        thirdColor = chipluxPurple;
        break;

      case ChipluxBackgroundStyle.watch:
        firstColor = chipluxCyan;
        secondColor = chipluxPurple;
        thirdColor = chipluxViolet;
        break;

        case ChipluxBackgroundStyle.community:
  firstColor = chipluxCyan;
  secondColor = chipluxViolet;
  thirdColor = chipluxPurple;
  break;

      case ChipluxBackgroundStyle.profile:
        firstColor = chipluxPurple;
        secondColor = chipluxViolet;
        thirdColor = chipluxCyan;
        break;
    }

    // TOP LEFT GLOW
    _drawGlow(
      canvas,
      center: Offset(
        -size.width * 0.10,
        size.height * 0.12,
      ),
      radius:
          size.width * 0.85,
      color: firstColor,
      opacity: 0.12,
    );

    // RIGHT / MIDDLE GLOW
    _drawGlow(
      canvas,
      center: Offset(
        size.width * 1.08,
        size.height * 0.45,
      ),
      radius:
          size.width * 0.90,
      color: secondColor,
      opacity: 0.095,
    );

    // LOWER LEFT GLOW
    _drawGlow(
      canvas,
      center: Offset(
        size.width * 0.05,
        size.height * 0.90,
      ),
      radius:
          size.width * 0.80,
      color: thirdColor,
      opacity: 0.07,
    );

    _drawLines(
      canvas,
      size,
      secondColor,
    );
  }

  void _drawGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    final rect =
        Rect.fromCircle(
      center: center,
      radius: radius,
    );

    final shader =
        RadialGradient(
      colors: [
        color.withValues(
          alpha: opacity,
        ),
        color.withValues(
          alpha: 0,
        ),
      ],
      stops: const [
        0,
        1,
      ],
    ).createShader(rect);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = shader,
    );
  }

  void _drawLines(
    Canvas canvas,
    Size size,
    Color color,
  ) {
    final paint =
        Paint()
          ..color =
              color.withValues(
            alpha: 0.06,
          )
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // UPPER DIAGONAL
    final path1 = Path()
      ..moveTo(
        size.width * 0.62,
        0,
      )
      ..lineTo(
        size.width * 0.90,
        size.height * 0.18,
      )
      ..lineTo(
        size.width,
        size.height * 0.18,
      );

    canvas.drawPath(
      path1,
      paint,
    );

    // MIDDLE LINE
    final path2 = Path()
      ..moveTo(
        0,
        size.height * 0.48,
      )
      ..lineTo(
        size.width * 0.14,
        size.height * 0.44,
      )
      ..lineTo(
        size.width * 0.52,
        size.height * 0.44,
      );

    canvas.drawPath(
      path2,
      paint,
    );

    // LOWER GEOMETRIC LINE
    final path3 = Path()
      ..moveTo(
        size.width * 0.45,
        size.height,
      )
      ..lineTo(
        size.width * 0.68,
        size.height * 0.83,
      )
      ..lineTo(
        size.width,
        size.height * 0.83,
      );

    canvas.drawPath(
      path3,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant
        _ChipluxBackgroundPainter
        oldDelegate,
  ) {
    return oldDelegate.style !=
        style;
  }
}

class ChipluxApp extends StatelessWidget {
  const ChipluxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chiplux',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
            chipluxBackground,
        colorScheme:
            const ColorScheme.dark(
          primary: chipluxCyan,
          secondary: chipluxViolet,
          surface: chipluxSurface,
        ),
        useMaterial3: true,
        navigationBarTheme:
            const NavigationBarThemeData(
          backgroundColor:
              Color(0xFF091521),
          indicatorColor:
              Color(0xFF173A50),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream:
          AuthService.instance.authChanges,
      builder: (context, snapshot) {
        final user =
            AuthService.instance.currentUser;

        if (user == null) {
          return const LoginPage();
        }

        return const MainScreen();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
  });

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState
    extends State<LoginPage> {
  // =====================================================
  // CONTROLLERS
  // =====================================================

  final TextEditingController
      emailController =
      TextEditingController();

  final TextEditingController
      passwordController =
      TextEditingController();

  final TextEditingController
      usernameController =
      TextEditingController();

  // =====================================================
  // LOGIN STATE
  // =====================================================

  bool loading = false;
  bool signupMode = false;
  bool showPassword = false;

  bool rememberMe = false;

  String? message;

  static const String
      _rememberedEmailKey =
      'chiplux_remembered_email';

  static const String
      _pendingSignupKey =
      'chiplux_pending_signup_email';

  // =====================================================
  // USERNAME CHECK
  // =====================================================

  Timer? _usernameDebounce;

  bool usernameChecking = false;

  bool? usernameAvailable;

  String? usernameStatus;

  List<String>
      usernameSuggestions =
      <String>[];

  int _usernameCheckGeneration = 0;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    _loadRememberedEmail();
  }

  Future<void>
      _loadRememberedEmail() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final rememberedEmail =
        prefs.getString(
      _rememberedEmailKey,
    );

    if (!mounted ||
        rememberedEmail == null ||
        rememberedEmail.isEmpty) {
      return;
    }

    setState(() {
      emailController.text =
          rememberedEmail;

      rememberMe = true;
    });
  }

  // =====================================================
  // USERNAME
  // =====================================================

  void _onUsernameChanged(
    String value,
  ) {
    _usernameDebounce?.cancel();

    final username =
        value
            .trim()
            .toLowerCase();

    _usernameCheckGeneration++;

    final generation =
        _usernameCheckGeneration;

    setState(() {
      usernameAvailable = null;
      usernameSuggestions = [];
      usernameStatus = null;
      usernameChecking = false;
    });

    if (!signupMode) {
      return;
    }

    if (username.isEmpty) {
      return;
    }

    if (username.length < 3) {
      setState(() {
        usernameStatus =
            'Username must be at least 3 characters.';
      });

      return;
    }

    if (username.length > 20) {
      setState(() {
        usernameStatus =
            'Username cannot be longer than 20 characters.';
      });

      return;
    }

    if (!RegExp(
      r'^[a-z0-9_]+$',
    ).hasMatch(
      username,
    )) {
      setState(() {
        usernameStatus =
            'Use only letters, numbers and underscores.';
      });

      return;
    }

    setState(() {
      usernameChecking = true;

      usernameStatus =
          'Checking username...';
    });

    _usernameDebounce =
        Timer(
      const Duration(
        milliseconds: 350,
      ),
      () {
        _checkUsername(
          username,
          generation,
        );
      },
    );
  }

  Future<void> _checkUsername(
    String username,
    int generation,
  ) async {
    try {
      final result =
          await AuthService.instance
              .checkUsernameAvailability(
        username,
      );

      if (!mounted ||
          generation !=
              _usernameCheckGeneration) {
        return;
      }

      final rawSuggestions =
          result['suggestions'];

      final suggestions =
          rawSuggestions is List
              ? rawSuggestions
                  .map(
                    (
                      value,
                    ) =>
                        value
                            .toString(),
                  )
                  .where(
                    (
                      value,
                    ) =>
                        value
                            .isNotEmpty,
                  )
                  .take(3)
                  .toList()
              : <String>[];

      final available =
          result['available'] ==
              true;

      setState(() {
        usernameChecking = false;

        usernameAvailable =
            available;

        usernameStatus =
            available
                ? 'Username is available.'
                : 'Username is already taken.';

        usernameSuggestions =
            suggestions;
      });
    } catch (e) {
      debugPrint(
        'Could not check username: $e',
      );

      if (!mounted ||
          generation !=
              _usernameCheckGeneration) {
        return;
      }

      setState(() {
        usernameChecking = false;

        usernameAvailable = null;

        usernameStatus =
            'Could not check username.';
      });
    }
  }

  void _useUsernameSuggestion(
    String username,
  ) {
    usernameController.text =
        username;

    usernameController.selection =
        TextSelection.collapsed(
      offset:
          username.length,
    );

    _onUsernameChanged(
      username,
    );
  }

  // =====================================================
  // SIGN IN / SIGN UP
  // =====================================================

  Future<void> submit() async {
    final identifier =
        emailController.text
            .trim();

    final password =
        passwordController.text;

    final username =
        usernameController.text
            .trim()
            .toLowerCase();

    // ===================================================
    // BASIC VALIDATION
    // ===================================================

    if (identifier.isEmpty ||
        password.length < 6) {
      setState(() {
        message =
            signupMode
                ? 'Enter your email and a password of at least 6 characters.'
                : 'Enter your email or username and a password of at least 6 characters.';
      });

      return;
    }

    // ===================================================
    // SIGNUP VALIDATION
    // ===================================================

    if (signupMode) {
      if (!identifier.contains(
        '@',
      )) {
        setState(() {
          message =
              'Enter a valid email address.';
        });

        return;
      }

      if (username.isEmpty) {
        setState(() {
          message =
              'Choose a username.';
        });

        return;
      }

      if (usernameChecking) {
        setState(() {
          message =
              'Wait for the username check to finish.';
        });

        return;
      }

      if (usernameAvailable !=
          true) {
        setState(() {
          message =
              'Choose an available username.';
        });

        return;
      }
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final prefs =
          await SharedPreferences
              .getInstance();

      // =================================================
      // CREATE ACCOUNT
      // =================================================

      if (signupMode) {
        final response =
            await AuthService
                .instance
                .signUp(
          email:
              identifier,

          password:
              password,

          username:
              username,
        );

        if (response.session !=
            null) {
          // Email confirmation is disabled,
          // therefore the new account is
          // already authenticated.
          //
          // Move current local/guest data
          // into this newly-created account.

          await LibraryService
              .instance
              .syncToCloud();

          await prefs.remove(
            _pendingSignupKey,
          );
        } else {
          // Email confirmation is required.
          //
          // Remember which specific account
          // is allowed to inherit the local
          // guest library after confirmation.

          await prefs.setString(
            _pendingSignupKey,
            identifier
                .toLowerCase(),
          );

          if (mounted) {
            setState(() {
              message =
                  'Account created. Check your email and confirm your account, then sign in.';
            });
          }
        }

        return;
      }

      // =================================================
      // SIGN IN
      // =================================================

      await AuthService
          .instance
          .signIn(
        identifier:
            identifier,

        password:
            password,
      );

      // Authentication succeeded.
      //
      // This is the ACTUAL account email,
      // even if the user signed in using
      // their username.

      final signedInEmail =
          AuthService.instance
              .currentUser
              ?.email
              ?.trim()
              .toLowerCase();

      // =================================================
      // REMEMBER ME
      // =================================================

      if (rememberMe &&
          signedInEmail != null &&
          signedInEmail.isNotEmpty) {
        await prefs.setString(
          _rememberedEmailKey,
          signedInEmail,
        );
      } else if (!rememberMe) {
        await prefs.remove(
          _rememberedEmailKey,
        );
      }

      // =================================================
      // LOCAL / CLOUD LIBRARY
      // =================================================

      final library =
          LibraryService.instance;

      final cloud =
          CloudSyncService.instance;

      final pendingEmail =
          prefs.getString(
        _pendingSignupKey,
      );

      final isPendingNewAccount =
          pendingEmail != null &&
              signedInEmail !=
                  null &&
              pendingEmail ==
                  signedInEmail;

      if (isPendingNewAccount) {
        final cloudLibrary =
            await cloud
                .downloadLibrary();

        final cloudEpisodes =
            await cloud
                .downloadEpisodes();

        final cloudIsEmpty =
            cloudLibrary.isEmpty &&
                cloudEpisodes
                    .isEmpty;

        if (cloudIsEmpty) {
          // This is the newly-created
          // account that owns the guest
          // data currently on the device.

          await library
              .syncToCloud();
        } else {
          // Cloud already contains data.
          // Cloud wins.

          await library
              .syncFromCloud();
        }

        await prefs.remove(
          _pendingSignupKey,
        );
      } else {
        // Normal login to an existing
        // account.
        //
        // Never accidentally upload
        // leftover local data into it.

        await library
            .syncFromCloud();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          String error =
              e.toString();

          if (error.contains(
            'already taken',
          )) {
            message =
                'That username is already taken.';
          } else if (error.contains(
                'Invalid username or password',
              ) ||
              error.contains(
                'Invalid login credentials',
              )) {
            message =
                'Invalid email, username or password.';
          } else {
            message =
                error;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // =====================================================
  // CHANGE MODE
  // =====================================================

  void _toggleMode() {
    if (loading) {
      return;
    }

    _usernameDebounce?.cancel();

    setState(() {
      signupMode =
          !signupMode;

      message = null;

      usernameAvailable = null;
      usernameChecking = false;
      usernameStatus = null;

      usernameSuggestions =
          <String>[];

      passwordController.clear();

      showPassword = false;
    });

    _usernameCheckGeneration++;

    if (signupMode &&
        usernameController.text
            .trim()
            .isNotEmpty) {
      _onUsernameChanged(
        usernameController.text,
      );
    }
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _usernameDebounce?.cancel();

    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final disableSubmit =
        loading ||
            (
              signupMode &&
              (
                usernameChecking ||
                usernameAvailable !=
                    true
              )
            );

    return Scaffold(
      backgroundColor:
          Colors.transparent,

      body:
          ChipluxBackground(
        style:
            ChipluxBackgroundStyle
                .discover,

        child:
            SafeArea(
          child:
              Center(
            child:
                SingleChildScrollView(
              padding:
                  const EdgeInsets
                      .all(
                30,
              ),

              child:
                  ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth:
                      430,
                ),

                child:
                    Column(
                  children: [
                    // =====================================
                    // LOGO
                    // =====================================

                    const ChipluxWordmark(
                      fontSize:
                          44,
                    ),

                    const SizedBox(
                      height:
                          10,
                    ),

                    const Text(
                      'Your Watchlist · Your Word',
                      textAlign:
                          TextAlign
                              .center,
                      style:
                          TextStyle(
                        color:
                            Colors
                                .white54,
                        letterSpacing:
                            2,
                      ),
                    ),

                    const SizedBox(
                      height:
                          42,
                    ),

                    // =====================================
                    // USERNAME - CREATE ACCOUNT ONLY
                    // =====================================

                    if (signupMode) ...[
                      TextField(
                        controller:
                            usernameController,

                        maxLength:
                            20,

                        autocorrect:
                            false,

                        enableSuggestions:
                            false,

                        textCapitalization:
                            TextCapitalization
                                .none,

                        textInputAction:
                            TextInputAction
                                .next,

                        onChanged:
                            _onUsernameChanged,

                        decoration:
                            InputDecoration(
                          labelText:
                              'Username',

                          prefixText:
                              '@',

                          prefixIcon:
                              const Icon(
                            Icons
                                .person_outline,
                          ),

                          suffixIcon:
                              usernameChecking
                                  ? const Padding(
                                      padding:
                                          EdgeInsets
                                              .all(
                                        14,
                                      ),
                                      child:
                                          SizedBox(
                                        width:
                                            18,
                                        height:
                                            18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                        ),
                                      ),
                                    )
                                  : usernameAvailable ==
                                          true
                                      ? const Icon(
                                          Icons
                                              .check_circle_outline,
                                          color:
                                              Colors
                                                  .greenAccent,
                                        )
                                      : usernameAvailable ==
                                              false
                                          ? const Icon(
                                              Icons
                                                  .cancel_outlined,
                                              color:
                                                  Colors
                                                      .redAccent,
                                            )
                                          : null,
                        ),
                      ),

                      if (usernameStatus !=
                          null)
                        Align(
                          alignment:
                              Alignment
                                  .centerLeft,
                          child:
                              Text(
                            usernameStatus!,
                            style:
                                TextStyle(
                              fontSize:
                                  12,
                              color:
                                  usernameAvailable ==
                                          true
                                      ? Colors
                                          .greenAccent
                                      : usernameAvailable ==
                                              false
                                          ? Colors
                                              .redAccent
                                          : Colors
                                              .white54,
                            ),
                          ),
                        ),

                      if (usernameSuggestions
                          .isNotEmpty) ...[
                        const SizedBox(
                          height:
                              9,
                        ),

                        const Align(
                          alignment:
                              Alignment
                                  .centerLeft,
                          child:
                              Text(
                            'Try one of these:',
                            style:
                                TextStyle(
                              color:
                                  Colors
                                      .white54,
                              fontSize:
                                  12,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height:
                              7,
                        ),

                        Align(
                          alignment:
                              Alignment
                                  .centerLeft,
                          child:
                              Wrap(
                            spacing:
                                7,
                            runSpacing:
                                5,

                            children:
                                usernameSuggestions
                                    .map(
                                      (
                                        suggestion,
                                      ) {
                                        return ActionChip(
                                          label:
                                              Text(
                                            '@$suggestion',
                                          ),
                                          onPressed:
                                              () {
                                            _useUsernameSuggestion(
                                              suggestion,
                                            );
                                          },
                                        );
                                      },
                                    )
                                    .toList(),
                          ),
                        ),
                      ],

                      const SizedBox(
                        height:
                            15,
                      ),
                    ],

                    // =====================================
                    // EMAIL / USERNAME
                    // =====================================

                    TextField(
                      controller:
                          emailController,

                      keyboardType:
                          signupMode
                              ? TextInputType
                                  .emailAddress
                              : TextInputType
                                  .text,

                      autocorrect:
                          false,

                      textCapitalization:
                          TextCapitalization
                              .none,

                      textInputAction:
                          TextInputAction
                              .next,

                      decoration:
                          InputDecoration(
                        labelText:
                            signupMode
                                ? 'Email'
                                : 'Email or username',

                        prefixIcon:
                            Icon(
                          signupMode
                              ? Icons
                                  .email_outlined
                              : Icons
                                  .person_outline,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          15,
                    ),

                    // =====================================
                    // PASSWORD
                    // =====================================

                    TextField(
                      controller:
                          passwordController,

                      obscureText:
                          !showPassword,

                      textInputAction:
                          TextInputAction
                              .done,

                      onSubmitted:
                          (_) {
                        if (!disableSubmit) {
                          submit();
                        }
                      },

                      decoration:
                          InputDecoration(
                        labelText:
                            signupMode
                                ? 'Create Password'
                                : 'Password',

                        prefixIcon:
                            const Icon(
                          Icons
                              .lock_outline,
                        ),

                        suffixIcon:
                            IconButton(
                          onPressed:
                              () {
                            setState(() {
                              showPassword =
                                  !showPassword;
                            });
                          },

                          icon:
                              Icon(
                            showPassword
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                          ),

                          tooltip:
                              showPassword
                                  ? 'Hide password'
                                  : 'Show password',
                        ),
                      ),
                    ),

                    // =====================================
                    // REMEMBER ME
                    // =====================================

                    if (!signupMode) ...[
                      const SizedBox(
                        height:
                            7,
                      ),

                      Row(
                        children: [
                          Checkbox(
                            value:
                                rememberMe,

                            activeColor:
                                chipluxCyan,

                            checkColor:
                                Colors
                                    .black,

                            visualDensity:
                                VisualDensity
                                    .compact,

                            onChanged:
                                loading
                                    ? null
                                    : (
                                        value,
                                      ) {
                                        setState(() {
                                          rememberMe =
                                              value ??
                                                  false;
                                        });
                                      },
                          ),

                          GestureDetector(
                            onTap:
                                loading
                                    ? null
                                    : () {
                                        setState(() {
                                          rememberMe =
                                              !rememberMe;
                                        });
                                      },
                            child:
                                const Text(
                              'Remember Me',
                              style:
                                  TextStyle(
                                color:
                                    Colors
                                        .white70,
                                fontSize:
                                    14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(
                      height:
                          18,
                    ),

                    // =====================================
                    // MESSAGE
                    // =====================================

                    if (message !=
                        null) ...[
                      Container(
                        width:
                            double
                                .infinity,

                        padding:
                            const EdgeInsets
                                .all(
                          12,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              Colors
                                  .white
                                  .withValues(
                            alpha:
                                0.05,
                          ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),

                          border:
                              Border.all(
                            color:
                                Colors
                                    .white
                                    .withValues(
                              alpha:
                                  0.08,
                            ),
                          ),
                        ),

                        child:
                            Text(
                          message!,
                          textAlign:
                              TextAlign
                                  .center,
                          style:
                              const TextStyle(
                            color:
                                Colors
                                    .white70,
                            fontSize:
                                13,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            15,
                      ),
                    ],

                    // =====================================
                    // SUBMIT
                    // =====================================

                    SizedBox(
                      width:
                          double
                              .infinity,

                      child:
                          ElevatedButton(
                        onPressed:
                            disableSubmit
                                ? null
                                : submit,

                        child:
                            Padding(
                          padding:
                              const EdgeInsets
                                  .all(
                            15,
                          ),

                          child:
                              loading
                                  ? const SizedBox(
                                      width:
                                          20,
                                      height:
                                          20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2,
                                      ),
                                    )
                                  : Text(
                                      signupMode
                                          ? 'Create Account'
                                          : 'Sign In',
                                    ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          15,
                    ),

                    // =====================================
                    // MODE SWITCH
                    // =====================================

                    TextButton(
                      onPressed:
                          loading
                              ? null
                              : _toggleMode,

                      child:
                          Text(
                        signupMode
                            ? 'Already have an account? Sign In'
                            : 'Don\'t have an account? Create Account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() =>
      _MainScreenState();
}

class _MainScreenState
    extends State<MainScreen> {
  int currentIndex = 2;

  String libraryInitialFilter =
    'watching';

String libraryInitialMediaType =
    'tv';

String? libraryInitialSortMode;

int libraryOpenRequest = 0;

    void _openCompleted(
  String mediaType, {
  String? sortMode,
}) {
  setState(() {
    libraryInitialFilter =
        'completed';

    libraryInitialMediaType =
        mediaType;

    libraryInitialSortMode =
        sortMode;

    libraryOpenRequest++;

    currentIndex = 2;
  });
}

Widget _currentPage() {
  return IndexedStack(
    index: currentIndex,
    children: [
  const HomePage(),

  const SearchPage(),

  LibraryPage(
    initialFilter:
        libraryInitialFilter,
    initialMediaType:
        libraryInitialMediaType,
    initialSortMode:
        libraryInitialSortMode,
    openRequest:
        libraryOpenRequest,
  ),

  const CommunityPage(),

  ProfilePage(
  onEpisodesWatchedTap: () {
    _openCompleted(
      'tv',
    );
  },

  onMoviesWatchedTap: () {
    _openCompleted(
      'movie',
    );
  },

  onEpisodesRatedTap: () {
    _openCompleted(
      'tv',
      sortMode: 'rated',
    );
  },

  onTitlesRatedTap: () {
    _openCompleted(
      'movie',
      sortMode: 'rated',
    );
  },
),
    ],
  );
}

  @override
void initState() {
  super.initState();
  

  ProfileService.instance.loadProfile();
}

  @override
  Widget build(BuildContext context) {

    final profile = ProfileService.instance;
    return Scaffold(
      body: ChipluxBackground(
  style: _backgroundStyle,
  child: _currentPage(),
),
      bottomNavigationBar: AnimatedBuilder(
  animation: profile,
  builder: (context, _) {
    return _ChipluxBottomNav(
      currentIndex: currentIndex,
      avatarUrl: profile.avatarUrl,
      onTap: (index) {
        setState(() {
          if (index == 2) {
  libraryInitialFilter =
      'watching';

  libraryInitialMediaType =
      'tv';

  libraryInitialSortMode =
      null;

  libraryOpenRequest++;
}

          currentIndex = index;
        });
      },
    );
  },
),
    );
  }

  ChipluxBackgroundStyle
    get _backgroundStyle {
  switch (currentIndex) {
    case 0:
      return ChipluxBackgroundStyle
          .discover;

    case 1:
      return ChipluxBackgroundStyle
          .search;

    case 2:
      return ChipluxBackgroundStyle
          .watch;

    case 3:
  return ChipluxBackgroundStyle
      .community;

case 4:
  return ChipluxBackgroundStyle
      .profile;

    default:
      return ChipluxBackgroundStyle
          .discover;
  }
}
}

class CommunityPage
    extends StatefulWidget {
  const CommunityPage({
    super.key,
  });

  @override
  State<CommunityPage> createState() =>
      _CommunityPageState();
}

class _CommunityPageState
    extends State<CommunityPage>
    with
        SingleTickerProviderStateMixin {
  late final TabController
      _tabController;

  final CommunityService community =
      CommunityService.instance;

      RealtimeChannel?
    _activityChannel;

RealtimeChannel?
    _followsChannel;

Timer? _activityRefreshTimer;
Timer? _followsRefreshTimer;

  bool loadingFriendsWatch = true;
bool loadingFollowers = true;
bool loadingFollowing = true;

int newFollowersToday = 0;

int _lastCommunityTabIndex = 0;

List<Map<String, dynamic>>
    friendsWatch = [];

List<Map<String, dynamic>>
    followers = [];

List<Map<String, dynamic>>
    following = [];

    void _startCommunityRealtime() {
  final client =
      Supabase.instance.client;

  final userId =
      client.auth.currentUser?.id ??
          'anonymous';

  // =====================================
  // COMMUNITY ACTIVITY
  // =====================================

  _activityChannel =
      client.channel(
    'community_activity_$userId',
  );

  _activityChannel!
      .onPostgresChanges(
    event:
        PostgresChangeEvent.all,
    schema:
        'public',
    table:
        'community_activity',
    callback: (payload) {
      // Ratings use delete + insert,
      // so debounce rapid changes into
      // one refresh.
      _activityRefreshTimer
          ?.cancel();

      _activityRefreshTimer =
          Timer(
        const Duration(
          milliseconds: 250,
        ),
        () {
          if (!mounted) {
            return;
          }

          unawaited(
            _loadFriendsWatch(),
          );
        },
      );
    },
  ).subscribe();

  // =====================================
  // FOLLOWERS / FOLLOWING
  // =====================================

  _followsChannel =
      client.channel(
    'community_follows_$userId',
  );

  _followsChannel!
      .onPostgresChanges(
    event:
        PostgresChangeEvent.all,
    schema:
        'public',
    table:
        'follows',
    callback: (payload) {
      _followsRefreshTimer
          ?.cancel();

      _followsRefreshTimer =
          Timer(
        const Duration(
          milliseconds: 250,
        ),
        () {
          if (!mounted) {
            return;
          }

          unawaited(
            _loadFollowers(),
          );

          unawaited(
            _loadFollowing(),
          );

          // Following/unfollowing somebody
          // also changes whose activity
          // belongs in Friends Watch.
          unawaited(
            _loadFriendsWatch(),
          );
        },
      );
    },
  ).subscribe();
}

void _onCommunityTabChanged() {
  if (_tabController
      .indexIsChanging) {
    return;
  }

  final index =
      _tabController.index;

  if (index ==
      _lastCommunityTabIndex) {
    return;
  }

  _lastCommunityTabIndex =
      index;

  switch (index) {
    case 0:
      unawaited(
        _loadFriendsWatch(),
      );
      break;

    case 2:
      unawaited(
        _openFollowersTab(),
      );
      break;

    case 3:
      unawaited(
        _loadFollowing(),
      );
      break;
  }
}

  @override
void initState() {
  super.initState();

  _tabController =
      TabController(
    length: 4,
    vsync: this,
  );

  _tabController.addListener(
    _onCommunityTabChanged,
  );

  _loadFriendsWatch();
  _loadFollowers();
  _loadFollowing();

  _startCommunityRealtime();
}

Future<void> _loadFriendsWatch() async {
  try {
    final data =
        await community
            .getFriendsWatch();

    if (!mounted) {
      return;
    }

    setState(() {
      friendsWatch = data;
      loadingFriendsWatch = false;
    });
  } catch (e) {
    debugPrint(
      'Could not load Friends Watch: $e',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      loadingFriendsWatch = false;
    });
  }
}

Future<void> _openCommunityProfile(
  String userId,
) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PublicProfilePage(
        userId: userId,
      ),
    ),
  );

  if (!mounted) {
    return;
  }

  await _loadFriendsWatch();
  await _loadFollowers();
  await _loadFollowing();
}

void _openCommunityMedia(
  Map<String, dynamic> activity,
) {
  final rawId =
      activity['tmdb_id'];

  final mediaType =
      activity['media_type']
          ?.toString();

  if (rawId is! num ||
      mediaType == null) {
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          MediaDetailsPage(
        id: rawId.toInt(),
        mediaType: mediaType,
      ),
    ),
  );
}

Future<void> _openCommunityEpisode(
  Map<String, dynamic> activity,
) async {
  final rawShowId =
      activity['tmdb_id'];

  final rawSeason =
      activity['season_number'];

  final rawEpisode =
      activity['episode_number'];

  if (rawShowId is! num ||
      rawSeason is! num ||
      rawEpisode is! num) {
    return;
  }

  final showId =
      rawShowId.toInt();

  final seasonNumber =
      rawSeason.toInt();

  final episodeNumber =
      rawEpisode.toInt();

  try {
    final episodes =
        await TmdbService()
            .getSeasonEpisodes(
      showId,
      seasonNumber,
    );

    Map<String, dynamic>?
        foundEpisode;

    for (final raw
        in episodes) {
      final episode =
          Map<String, dynamic>.from(
        raw,
      );

      final number =
          episode[
              'episode_number'];

      if (number is num &&
          number.toInt() ==
              episodeNumber) {
        foundEpisode =
            episode;

        break;
      }
    }

    if (!mounted ||
        foundEpisode == null) {
      return;
    }

    final episode =
        foundEpisode;

    final rawRuntime =
        episode['runtime'];

    final rawRating =
        episode['vote_average'];

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SwipeableEpisodePage(
          showId:
              showId,

          seasonNumber:
              seasonNumber,

          episodeNumber:
              episodeNumber,

          title:
              episode['name']
                      ?.toString() ??
                  activity[
                          'episode_title']
                      ?.toString() ??
                  'Episode',

          stillPath:
              episode['still_path']
                  ?.toString(),

          runtime:
              rawRuntime is num
                  ? rawRuntime
                      .toInt()
                  : null,

          rating:
              rawRating is num
                  ? rawRating
                      .toDouble()
                  : null,

          overview:
              episode['overview']
                      ?.toString() ??
                  '',

          airDate:
              episode['air_date']
                  ?.toString(),
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      'Could not open community episode: $e',
    );
  }
}

Future<void> _openActivity(
  Map<String, dynamic> activity,
) async {
  final type =
      activity['activity_type']
          ?.toString();

  if (type ==
      'achievement_unlocked') {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AchievementsPage(),
      ),
    );

    return;
  }

  final bool isEpisodeRating =
      type == 'rated' &&
          activity['season_number']
              is num &&
          activity['episode_number']
              is num;

  if (type ==
          'episode_watched' ||
      isEpisodeRating) {
    await _openCommunityEpisode(
      activity,
    );

    return;
  }

  _openCommunityMedia(
    activity,
  );
}

Future<void> _loadFollowers() async {
  try {
    final data =
        await community
            .getFollowers();

    final client =
        Supabase.instance.client;

    final currentUserId =
        client.auth.currentUser?.id;

    if (currentUserId == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        followers = data;
        newFollowersToday = 0;
        loadingFollowers = false;
      });

      return;
    }

    // Get the actual follow timestamps.
    final followRows =
        await client
            .from('follows')
            .select(
              'follower_id, created_at',
            )
            .eq(
              'following_id',
              currentUserId,
            );

    final followedAtByUser =
        <String, String>{};

    for (final raw
        in followRows) {
      final followerId =
          raw['follower_id']
              ?.toString();

      final createdAt =
          raw['created_at']
              ?.toString();

      if (followerId == null ||
          createdAt == null) {
        continue;
      }

      followedAtByUser[
          followerId] =
          createdAt;
    }

    // Add followed_at to each profile.
    final enrichedFollowers =
        data.map(
      (rawUser) {
        final user =
            Map<String, dynamic>.from(
          rawUser,
        );

        final id =
            user['id']
                ?.toString();

        if (id != null) {
          final followedAt =
              followedAtByUser[id];

          if (followedAt != null) {
            user['followed_at'] =
                followedAt;
          }
        }

        return user;
      },
    ).toList();

    final prefs =
        await SharedPreferences
            .getInstance();

    final seenKey =
        'community_followers_seen_at_$currentUserId';

    final seenRaw =
        prefs.getString(
      seenKey,
    );

    final lastSeen =
        seenRaw != null
            ? DateTime.tryParse(
                seenRaw,
              )?.toLocal()
            : null;

    final now =
        DateTime.now();

    bool isToday(
      DateTime date,
    ) {
      return date.year ==
              now.year &&
          date.month ==
              now.month &&
          date.day ==
              now.day;
    }

    int unreadToday = 0;

    for (final raw
        in followRows) {
      final createdRaw =
          raw['created_at']
              ?.toString();

      if (createdRaw == null) {
        continue;
      }

      final created =
          DateTime.tryParse(
            createdRaw,
          )?.toLocal();

      if (created == null ||
          !isToday(
            created,
          )) {
        continue;
      }

      if (lastSeen == null ||
          created.isAfter(
            lastSeen,
          )) {
        unreadToday++;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      followers =
          enrichedFollowers;

      newFollowersToday =
          unreadToday;

      loadingFollowers =
          false;
    });
  } catch (e) {
    debugPrint(
      'Could not load followers: $e',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      loadingFollowers =
          false;
    });
  }
}

Future<void>
    _markFollowersSeen() async {
  final userId =
      Supabase.instance.client
          .auth.currentUser?.id;

  if (userId == null) {
    return;
  }

  if (mounted) {
    setState(() {
      newFollowersToday = 0;
    });
  }

  final prefs =
      await SharedPreferences
          .getInstance();

  await prefs.setString(
    'community_followers_seen_at_$userId',
    DateTime.now()
        .toUtc()
        .toIso8601String(),
  );
}

Future<void>
    _openFollowersTab() async {
  await _markFollowersSeen();

  await _loadFollowers();
}

Future<void> _loadFollowing() async {
  try {
    final data =
        await community
            .getFollowing();

    if (!mounted) {
      return;
    }

    setState(() {
      following = data;
      loadingFollowing = false;
    });
  } catch (e) {
    debugPrint(
      'Could not load following: $e',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      loadingFollowing = false;
    });
  }
}

  @override
void dispose() {
  _activityRefreshTimer
      ?.cancel();

  _followsRefreshTimer
      ?.cancel();

  if (_activityChannel !=
      null) {
    unawaited(
      _activityChannel!
          .unsubscribe(),
    );
  }

  if (_followsChannel !=
      null) {
    unawaited(
      _followsChannel!
          .unsubscribe(),
    );
  }
_tabController.removeListener(
  _onCommunityTabChanged,
);
  _tabController.dispose();

  super.dispose();
}

  @override
Widget build(
  BuildContext context,
) {
  return SafeArea(
    child: Column(
      children: [
        Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            20,
            20,
            20,
            12,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Community',
                  style:
                      TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              Icon(
                Icons.people_rounded,
                color:
                    chipluxCyan
                        .withValues(
                  alpha: 0.9,
                ),
                size: 28,
              ),
            ],
          ),
        ),

        Padding(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 16,
          ),
          child: Container(
            height: 64,
            padding:
                const EdgeInsets.all(
              4,
            ),
            decoration:
                BoxDecoration(
              color:
                  chipluxSurface
                      .withValues(
                alpha: 0.45,
              ),
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
            ),
            child: TabBar(
              controller:
                  _tabController,

              isScrollable: true,

              tabAlignment:
                  TabAlignment.start,

              indicator:
                  BoxDecoration(
                color:
                    Colors.transparent,

                borderRadius:
                    BorderRadius
                        .circular(
                  18,
                ),

                border:
                    Border.all(
                  color:
                      chipluxCyan,
                  width: 2,
                ),
              ),

              indicatorSize:
                  TabBarIndicatorSize
                      .tab,

              dividerColor:
                  Colors.transparent,

              overlayColor:
                  WidgetStateProperty
                      .all(
                Colors.transparent,
              ),

              splashFactory:
                  NoSplash
                      .splashFactory,

              labelColor:
                  chipluxCyan,

              unselectedLabelColor:
                  Colors.white70,

              labelStyle:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 14,
              ),

              unselectedLabelStyle:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
                fontSize: 14,
              ),

              labelPadding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 20,
              ),

              tabs: [
  const Tab(
    text:
        'Friends Watch',
  ),

  const Tab(
    text:
        'Find Friends',
  ),

  Tab(
    child: Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        const Text(
          'Followers',
        ),

        if (newFollowersToday >
            0) ...[
          const SizedBox(
            width: 6,
          ),

          Container(
            width: 21,
            height: 21,
            alignment:
                Alignment.center,
            decoration:
                const BoxDecoration(
              color:
                  Color(
                0xFFFFC857,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: FittedBox(
              fit:
                  BoxFit.scaleDown,
              child: Padding(
                padding:
                    const EdgeInsets
                        .all(
                  3,
                ),
                child: Text(
                  '$newFollowersToday',
                  style:
                      const TextStyle(
                    color:
                        Colors.black,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  ),

  const Tab(
    text:
        'Following',
  ),
],
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        Expanded(
          child: TabBarView(
            controller:
                _tabController,

            children: [
              // =========================
              // FRIENDS WATCH
              // =========================

              _FriendsWatchList(
                loading:
                    loadingFriendsWatch,

                activities:
                    friendsWatch,

                onRefresh:
                    _loadFriendsWatch,

                onProfileTap:
                    _openCommunityProfile,

                onActivityTap:
                    _openActivity,
              ),

              // =========================
              // FIND FRIENDS
              // =========================

              const _FindFriendsTab(),

              // =========================
              // FOLLOWERS
              // =========================

              _CommunityUsersList(
                loading:
                    loadingFollowers,

                users:
                    followers,

                emptyText:
                    'No followers yet.',

                onRefresh:
                    _loadFollowers,
              ),

              // =========================
              // FOLLOWING
              // =========================

              _CommunityUsersList(
                loading:
                    loadingFollowing,

                users:
                    following,

                emptyText:
                    'You are not following anyone yet.',

                onRefresh:
                    _loadFollowing,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}

class _FindFriendsTab
    extends StatefulWidget {
  const _FindFriendsTab();

  @override
  State<_FindFriendsTab>
      createState() =>
          _FindFriendsTabState();
}

class _FindFriendsTabState
    extends State<_FindFriendsTab> {
  final TextEditingController
      _searchController =
      TextEditingController();

  Timer? _debounce;

  List<Map<String, dynamic>>
      _results = [];

  bool _searching = false;

  String _query = '';

  int _searchGeneration = 0;

  void _onSearchChanged(
    String value,
  ) {
    _debounce?.cancel();

    final query =
        value.trim();

    _searchGeneration++;

    if (query.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _searching = false;
      });

      return;
    }

    setState(() {
      _query = query;
      _searching = true;
    });

    final generation =
        _searchGeneration;

    _debounce =
        Timer(
      const Duration(
        milliseconds: 350,
      ),
      () {
        _search(
          query,
          generation,
        );
      },
    );
  }

  Future<void> _search(
    String query,
    int generation,
  ) async {
    try {
      final client =
          Supabase.instance.client;

      final ownUserId =
          client.auth.currentUser?.id;

      // Search display name.
      final displayResults =
          await client
              .from('profiles')
              .select(
                'id, display_name, username, avatar_url',
              )
              .ilike(
                'display_name',
                '%$query%',
              )
              .limit(20);

      // Search username.
      final usernameResults =
          await client
              .from('profiles')
              .select(
                'id, display_name, username, avatar_url',
              )
              .ilike(
                'username',
                '%$query%',
              )
              .limit(20);

      if (!mounted ||
          generation !=
              _searchGeneration) {
        return;
      }

      // Merge both searches without
      // showing the same user twice.
      final Map<
          String,
          Map<String, dynamic>>
          usersById = {};

      for (final raw
          in displayResults) {
        final user =
            Map<String, dynamic>.from(
          raw,
        );

        final id =
            user['id']
                ?.toString();

        if (id == null ||
            id.isEmpty ||
            id == ownUserId) {
          continue;
        }

        usersById[id] =
            user;
      }

      for (final raw
          in usernameResults) {
        final user =
            Map<String, dynamic>.from(
          raw,
        );

        final id =
            user['id']
                ?.toString();

        if (id == null ||
            id.isEmpty ||
            id == ownUserId) {
          continue;
        }

        usersById[id] =
            user;
      }

      final results =
          usersById.values
              .toList();

      final lowerQuery =
          query.toLowerCase();

      int rank(
        Map<String, dynamic> user,
      ) {
        final displayName =
            user['display_name']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final username =
            user['username']
                    ?.toString()
                    .toLowerCase() ??
                '';

        // Exact matches first.
        if (username ==
                lowerQuery ||
            displayName ==
                lowerQuery) {
          return 0;
        }

        // Then usernames beginning
        // with the query.
        if (username.startsWith(
          lowerQuery,
        )) {
          return 1;
        }

        // Then display names beginning
        // with the query.
        if (displayName.startsWith(
          lowerQuery,
        )) {
          return 2;
        }

        return 3;
      }

      results.sort(
        (a, b) {
          final rankCompare =
              rank(a).compareTo(
            rank(b),
          );

          if (rankCompare != 0) {
            return rankCompare;
          }

          final aName =
              (
                a['display_name'] ??
                a['username'] ??
                ''
              )
                  .toString()
                  .toLowerCase();

          final bName =
              (
                b['display_name'] ??
                b['username'] ??
                ''
              )
                  .toString()
                  .toLowerCase();

          return aName.compareTo(
            bName,
          );
        },
      );

      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      debugPrint(
        'Could not search users: $e',
      );

      if (!mounted ||
          generation !=
              _searchGeneration) {
        return;
      }

      setState(() {
        _results = [];
        _searching = false;
      });
    }
  }

  Future<void> _refresh() async {
    final query =
        _searchController.text
            .trim();

    if (query.isEmpty) {
      return;
    }

    _searchGeneration++;

    final generation =
        _searchGeneration;

    setState(() {
      _searching = true;
    });

    await _search(
      query,
      generation,
    );
  }

  void _clearSearch() {
    _debounce?.cancel();

    _searchController.clear();

    _searchGeneration++;

    setState(() {
      _query = '';
      _results = [];
      _searching = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();

    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            16,
            4,
            16,
            12,
          ),
          child: TextField(
            controller:
                _searchController,

            onChanged:
                _onSearchChanged,

            textInputAction:
                TextInputAction.search,

            decoration:
                InputDecoration(
              hintText:
                  'Search name or username',

              prefixIcon:
                  const Icon(
                Icons.search_rounded,
              ),

              suffixIcon:
                  _query.isNotEmpty
                      ? IconButton(
                          onPressed:
                              _clearSearch,
                          icon:
                              const Icon(
                            Icons
                                .close_rounded,
                          ),
                        )
                      : null,

              filled: true,

              fillColor:
                  chipluxSurface
                      .withValues(
                alpha: 0.88,
              ),

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
                borderSide:
                    BorderSide.none,
              ),

              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
                borderSide:
                    BorderSide(
                  color:
                      Colors.white
                          .withValues(
                    alpha: 0.05,
                  ),
                ),
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      chipluxCyan,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child:
              _CommunityUsersList(
            loading:
                _searching,

            users:
                _results,

            emptyText:
                _query.isEmpty
                    ? 'Search for friends by display name or username.'
                    : 'No users found.',

            onRefresh:
                _refresh,
          ),
        ),
      ],
    );
  }
}

class _CommunityUsersList
    extends StatelessWidget {
  final bool loading;

  final List<Map<String, dynamic>>
      users;

  final String emptyText;

  final Future<void> Function()
    onRefresh;

  const _CommunityUsersList({
  required this.loading,
  required this.users,
  required this.emptyText,
  required this.onRefresh,
});

  @override
  Widget build(
    BuildContext context,
  ) {
    if (loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style:
              const TextStyle(
            color:
                Colors.white54,
          ),
        ),
      );
    }

    return RefreshIndicator(
  onRefresh:
      onRefresh,
      child: ListView.separated(
        padding:
            const EdgeInsets
                .fromLTRB(
          16,
          4,
          16,
          25,
        ),

        itemCount:
            users.length,

        separatorBuilder:
            (
          context,
          index,
        ) =>
                const SizedBox(
          height: 10,
        ),

        itemBuilder:
            (
          context,
          index,
        ) {
          final user =
              users[index];

          final displayName =
              user['display_name']
                      ?.toString()
                      .trim() ??
                  '';

          final username =
              user['username']
                      ?.toString()
                      .trim() ??
                  '';

          final avatarUrl =
              user['avatar_url']
                  ?.toString();

                  final followedAtRaw =
    user['followed_at']
        ?.toString();

final followedAt =
    followedAtRaw != null
        ? DateTime.tryParse(
            followedAtRaw,
          )?.toLocal()
        : null;

final now =
    DateTime.now();

final isNewToday =
    followedAt != null &&
        followedAt.year ==
            now.year &&
        followedAt.month ==
            now.month &&
        followedAt.day ==
            now.day;

          final name =
              displayName.isNotEmpty
                  ? displayName
                  : username.isNotEmpty
                      ? username
                      : 'Chiplux User';

          return InkWell(
            borderRadius:
                BorderRadius
                    .circular(
              16,
            ),

            onTap: () async {
  final userId =
      user['id']
          ?.toString();

  if (userId == null ||
      userId.isEmpty) {
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PublicProfilePage(
        userId: userId,
      ),
    ),
  );
},

            child: Container(
              padding:
                  const EdgeInsets
                      .all(
                14,
              ),

              decoration:
                  BoxDecoration(
                color:
                    chipluxSurface,
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),

                border:
                    Border.all(
                  color:
                      Colors.white
                          .withValues(
                    alpha: 0.05,
                  ),
                ),
              ),

              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,

                    backgroundColor:
                        chipluxSurfaceLight,

                    backgroundImage:
                        avatarUrl !=
                                    null &&
                                avatarUrl
                                    .isNotEmpty
                            ? NetworkImage(
                                avatarUrl,
                              )
                            : null,

                    child:
                        avatarUrl ==
                                    null ||
                                avatarUrl
                                    .isEmpty
                            ? const Icon(
                                Icons
                                    .person,
                                color:
                                    Colors
                                        .white54,
                              )
                            : null,
                  ),

                  const SizedBox(
                    width: 13,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        Text(
                          name,
                          style:
                              const TextStyle(
                            fontSize:
                                16,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        if (username
                            .isNotEmpty) ...[
                          const SizedBox(
                            height:
                                3,
                          ),

                          Text(
                            '@$username',
                            style:
                                const TextStyle(
                              color:
                                  Colors
                                      .white54,
                              fontSize:
                                  13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Column(
  mainAxisSize:
      MainAxisSize.min,
  crossAxisAlignment:
      CrossAxisAlignment.end,
  children: [
    if (isNewToday) ...[
      const Text(
        'New',
        style:
            TextStyle(
          color:
              Color(
            0xFFFFC857,
          ),
          fontSize: 12,
          fontWeight:
              FontWeight.bold,
        ),
      ),

      const SizedBox(
        height: 3,
      ),
    ],

    const Icon(
      Icons
          .chevron_right_rounded,
      color:
          Colors.white38,
    ),
  ],
),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FriendsWatchList
    extends StatelessWidget {
  final bool loading;

  final List<Map<String, dynamic>>
      activities;

  final Future<void> Function()
      onRefresh;

  final Future<void> Function(
    String userId,
  ) onProfileTap;

  final Future<void> Function(
    Map<String, dynamic> activity,
  ) onActivityTap;

  const _FriendsWatchList({
    required this.loading,
    required this.activities,
    required this.onRefresh,
    required this.onProfileTap,
    required this.onActivityTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (activities.isEmpty) {
      return RefreshIndicator(
        onRefresh:
            onRefresh,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 220,
            ),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons
                        .people_outline_rounded,
                    color:
                        Colors.white24,
                    size: 48,
                  ),

                  SizedBox(
                    height: 12,
                  ),

                  Text(
                    'Nothing here yet.',
                    style:
                        TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  SizedBox(
                    height: 5,
                  ),

                  Text(
                    'Activity from you and people you follow will appear here.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          onRefresh,

      child: ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets
                .fromLTRB(
          16,
          4,
          16,
          30,
        ),

        itemCount:
            activities.length,

        separatorBuilder:
            (
          context,
          index,
        ) =>
                const SizedBox(
          height: 10,
        ),

        itemBuilder:
            (
          context,
          index,
        ) {
          final activity =
              activities[index];

          return _FriendsWatchRow(
            activity:
                activity,

            onProfileTap:
                onProfileTap,

            onActivityTap:
                onActivityTap,
          );
        },
      ),
    );
  }
}

class _FriendsWatchRow
    extends StatelessWidget {
  final Map<String, dynamic>
      activity;

  final Future<void> Function(
    String userId,
  ) onProfileTap;

  final Future<void> Function(
    Map<String, dynamic> activity,
  ) onActivityTap;

  const _FriendsWatchRow({
    required this.activity,
    required this.onProfileTap,
    required this.onActivityTap,
  });

  String _userName() {
    final profile =
        activity['profile'];

    if (profile is! Map) {
      return 'Chiplux User';
    }

    final displayName =
        profile['display_name']
                ?.toString()
                .trim() ??
            '';

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final username =
        profile['username']
                ?.toString()
                .trim() ??
            '';

    if (username.isNotEmpty) {
      return username;
    }

    return 'Chiplux User';
  }

  String? _avatarUrl() {
    final profile =
        activity['profile'];

    if (profile is! Map) {
      return null;
    }

    return profile['avatar_url']
        ?.toString();
  }

  String _prefixText() {
    final type =
        activity['activity_type']
            ?.toString();

    switch (type) {
      case 'episode_watched':
        final season =
            activity[
                'season_number'];

        final episode =
            activity[
                'episode_number'];

        if (season is num &&
            episode is num) {
          final code =
              'S${season.toInt().toString().padLeft(2, '0')}'
              'E${episode.toInt().toString().padLeft(2, '0')}';

          return 'watched $code of';
        }

        return 'watched an episode of';

      case 'season_watched':
        final season =
            activity[
                'season_number'];

        return season is num
            ? 'watched Season ${season.toInt()} of'
            : 'watched a season of';

      case 'movie_watched':
        return 'watched';

      case 'tv_watched':
  return 'has completed';

case 'started_watching':
  return 'started watching';

case 'rated':
  final season =
      activity[
          'season_number'];

  final episode =
      activity[
          'episode_number'];

  if (season is num &&
      episode is num) {
    final code =
        'S${season.toInt().toString().padLeft(2, '0')}'
        'E${episode.toInt().toString().padLeft(2, '0')}';

    return 'rated $code of';
  }

  return 'rated';

      case 'plan_to_watch':
        return 'plans to watch';

      case 'dropped':
        return 'dropped';

      case 'favorite':
        return 'added to favorites';

      case 'achievement_unlocked':
        return 'unlocked';

      default:
        return '';
    }
  }

  String _targetText() {
    final type =
        activity['activity_type']
            ?.toString();

    if (type ==
        'achievement_unlocked') {
      return activity[
                  'achievement_title']
              ?.toString() ??
          'an achievement';
    }

    return activity[
                'media_title']
            ?.toString() ??
        'Unknown title';
  }

  String? _ratingText() {
    if (activity[
            'activity_type'] !=
        'rated') {
      return null;
    }

    final stars =
        activity['rating_stars'];

    if (stars is! num) {
      return null;
    }

    return '★' *
        stars
            .toInt()
            .clamp(
              1,
              5,
            );
  }

  String _timeAgo() {
    final raw =
        activity['created_at']
            ?.toString();

    if (raw == null) {
      return '';
    }

    final date =
        DateTime.tryParse(
      raw,
    );

    if (date == null) {
      return '';
    }

    final difference =
        DateTime.now()
            .difference(
      date.toLocal(),
    );

    if (difference.inSeconds <
        60) {
      return 'just now';
    }

    if (difference.inMinutes <
        60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours <
        24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays <
        7) {
      return '${difference.inDays}d ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final userId =
        activity['user_id']
            ?.toString();

    final avatarUrl =
        _avatarUrl();

    final name =
        _userName();

    final prefix =
        _prefixText();

    final target =
        _targetText();

    final rating =
        _ratingText();

    final type =
        activity['activity_type']
            ?.toString();

    final canOpenTarget =
        type !=
            'achievement_unlocked';

    return Container(
      padding:
          const EdgeInsets
              .all(
        14,
      ),

      decoration:
          BoxDecoration(
        color:
            chipluxSurface
                .withValues(
          alpha: 0.88,
        ),

        borderRadius:
            BorderRadius
                .circular(
          18,
        ),

        border:
            Border.all(
          color:
              Colors.white
                  .withValues(
            alpha: 0.05,
          ),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          InkWell(
            onTap:
                userId == null
                    ? null
                    : () {
                        onProfileTap(
                          userId,
                        );
                      },

            borderRadius:
                BorderRadius
                    .circular(
              30,
            ),

            child: CircleAvatar(
              radius: 23,

              backgroundColor:
                  chipluxSurfaceLight,

              backgroundImage:
                  avatarUrl !=
                              null &&
                          avatarUrl
                              .isNotEmpty
                      ? NetworkImage(
                          avatarUrl,
                        )
                      : null,

              child:
                  avatarUrl ==
                              null ||
                          avatarUrl
                              .isEmpty
                      ? const Icon(
                          Icons.person,
                          color:
                              Colors.white54,
                        )
                      : null,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment:
                      WrapCrossAlignment
                          .center,

                  children: [
                    InkWell(
                      onTap:
                          userId ==
                                  null
                              ? null
                              : () {
                                  onProfileTap(
                                    userId,
                                  );
                                },

                      child: Text(
                        name,
                        style:
                            const TextStyle(
                          fontSize:
                              15,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Colors.white,
                        ),
                      ),
                    ),

                    Text(
                      prefix,
                      style:
                          const TextStyle(
                        color:
                            Colors.white60,
                        fontSize:
                            14,
                      ),
                    ),

                    InkWell(
                      onTap:
                          canOpenTarget
                              ? () {
                                  onActivityTap(
                                    activity,
                                  );
                                }
                              : null,

                      child: Text(
                        target,
                        style:
                            TextStyle(
                          color:
                              canOpenTarget
                                  ? chipluxCyan
                                  : chipluxViolet,

                          fontSize:
                              14,

                          fontWeight:
                              FontWeight
                                  .w700,

                          decoration:
                              canOpenTarget
                                  ? TextDecoration
                                      .underline
                                  : TextDecoration
                                      .none,

                          decorationColor:
                              chipluxCyan,
                        ),
                      ),
                    ),

                    if (rating !=
                        null)
                      Text(
                        rating,
                        style:
                            const TextStyle(
                          color:
                              Colors.amber,
                          fontSize:
                              15,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  height: 7,
                ),

                Text(
                  _timeAgo(),
                  style:
                      const TextStyle(
                    color:
                        Colors.white30,
                    fontSize:
                        12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PublicStatsSyncService {
  PublicStatsSyncService._();

  static final PublicStatsSyncService
      instance =
      PublicStatsSyncService._();

  Timer? _debounce;

  bool _started = false;

  void start() {
    if (_started) {
      return;
    }

    _started = true;

    LibraryService.instance
        .addListener(
      _scheduleSync,
    );

    CriticService.instance
        .addListener(
      _scheduleSync,
    );

    MedalPinService.instance
        .addListener(
      _scheduleSync,
    );

    _scheduleSync();
  }

  void _scheduleSync() {
    _debounce?.cancel();

    _debounce =
        Timer(
      const Duration(
        milliseconds: 600,
      ),
      () {
        unawaited(
          syncNow(),
        );
      },
    );
  }

  Future<void> syncNow() async {
    final client =
        Supabase.instance.client;

    final user =
        client.auth.currentUser;

    if (user == null) {
      return;
    }

    final library =
        LibraryService.instance;

    final critic =
        CriticService.instance;

    final achievementGroup =
        _movieAchievementGroupFor(
      library.moviesWatchedCount,
    );

    final unlockedIds =
        achievementGroup.tiers
            .where(
              (achievement) =>
                  achievement.unlocked,
            )
            .map(
              (achievement) =>
                  achievement.id,
            )
            .toList();

    final genreRuntime =
        _buildGenreRuntime(
      library,
    );

    final distribution =
        <String, int>{};

    for (int rating = 1;
        rating <= 5;
        rating++) {
      distribution[
          '$rating'] =
          critic.ratingDistribution[
                  rating] ??
              0;
    }

    try {
      await client
          .from('profiles')
          .update({
        'public_stats': {
          'total_watched_minutes':
              library
                  .totalWatchedMinutes,

          'viewer_title':
              library.viewerTitle,

          'movies_watched':
              library
                  .moviesWatchedCount,

          'episodes_watched':
              library
                  .watchedEpisodeCount,

          'critic_level':
              critic.level,

          'critic_title':
              critic.title,

          'critic_xp':
              critic.xpInLevel,

          'critic_required_xp':
              critic.requiredXp,

          'total_ratings':
              critic.totalRatings,

          'episode_ratings':
              critic
                  .episodeRatingCount,

          'title_ratings':
              critic
                      .movieRatingCount +
                  critic
                      .tvRatingCount,

          'average_stars':
              critic.averageStars,

          'title_coverage':
              critic
                  .titleRatingCoverage,

          'episode_coverage':
              critic
                  .episodeRatingCoverage,

          'rating_distribution':
              distribution,

          'genre_runtime':
              genreRuntime,

          'unlocked_achievement_ids':
              unlockedIds,
        },

        'pinned_achievement_id':
            MedalPinService
                .instance
                .pinnedAchievementId,
      }).eq(
        'id',
        user.id,
      );
    } catch (e) {
      debugPrint(
        'Could not sync public profile stats: $e',
      );
    }
  }

  List<Map<String, dynamic>>
      _buildGenreRuntime(
    LibraryService library,
  ) {
    final titleCounts =
        <int, int>{};

    final watchedMinutes =
        <int, int>{};

    for (final item
        in library.items) {
      final genres =
          item.genreIds
              .toSet();

      if (genres.isEmpty) {
        continue;
      }

      final itemMinutes =
          library
              .watchedMinutesForItem(
        item,
      );

      for (final genreId
          in genres) {
        titleCounts[
            genreId] =
            (titleCounts[
                        genreId] ??
                    0) +
                1;

        watchedMinutes[
            genreId] =
            (watchedMinutes[
                        genreId] ??
                    0) +
                itemMinutes;
      }
    }

    final total =
        watchedMinutes.values.fold<int>(
      0,
      (
        sum,
        minutes,
      ) =>
          sum + minutes,
    );

    final result =
        <Map<String, dynamic>>[];

    for (final entry
        in titleCounts.entries) {
      final genreId =
          entry.key;

      final minutes =
          watchedMinutes[
                  genreId] ??
              0;

      final percentage =
          total > 0
              ? (minutes /
                      total) *
                  100
              : 0.0;

      result.add({
        'genre_id':
            genreId,
        'genre':
            _genreName(
          genreId,
        ),
        'minutes':
            minutes,
        'percentage':
            percentage,
        'title_count':
            entry.value,
      });
    }

    result.sort(
      (
        a,
        b,
      ) {
        final aMinutes =
            (a['minutes']
                    as num)
                .toInt();

        final bMinutes =
            (b['minutes']
                    as num)
                .toInt();

        return bMinutes
            .compareTo(
          aMinutes,
        );
      },
    );

    return result;
  }

  String _genreName(
    int genreId,
  ) {
    switch (genreId) {
      case 28:
        return 'Action';
      case 12:
        return 'Adventure';
      case 16:
        return 'Animation';
      case 35:
        return 'Comedy';
      case 80:
        return 'Crime';
      case 99:
        return 'Documentary';
      case 18:
        return 'Drama';
      case 10751:
        return 'Family';
      case 14:
        return 'Fantasy';
      case 36:
        return 'History';
      case 27:
        return 'Horror';
      case 10402:
        return 'Music';
      case 9648:
        return 'Mystery';
      case 10749:
        return 'Romance';
      case 878:
        return 'Science Fiction';
      case 10770:
        return 'TV Movie';
      case 53:
        return 'Thriller';
      case 10752:
        return 'War';
      case 37:
        return 'Western';

      case 10759:
        return 'Action & Adventure';
      case 10762:
        return 'Kids';
      case 10763:
        return 'News';
      case 10764:
        return 'Reality';
      case 10765:
        return 'Sci-Fi & Fantasy';
      case 10766:
        return 'Soap';
      case 10767:
        return 'Talk';
      case 10768:
        return 'War & Politics';

      default:
        return 'Other';
    }
  }
}

class PublicProfilePage
    extends StatefulWidget {
  final String userId;

  const PublicProfilePage({
    super.key,
    required this.userId,
  });

  @override
  State<PublicProfilePage>
      createState() =>
          _PublicProfilePageState();
}

class _PublicProfilePageState
    extends State<PublicProfilePage> {
  final CommunityService community =
      CommunityService.instance;

  Map<String, dynamic>? profile;

  bool loading = true;
  bool following = false;
  bool changingFollow = false;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    try {
      final client =
          Supabase.instance.client;

      final rawProfile =
    await client
        .from('profiles')
        .select(
          'id, '
          'display_name, '
          'username, '
          'avatar_url, '
          'banner_path, '
          'public_stats, '
          'pinned_achievement_id',
        )
        .eq(
          'id',
          widget.userId,
        )
        .maybeSingle();

final isFollowing =
    await community.isFollowing(
  widget.userId,
);

if (!mounted) {
  return;
}

setState(() {
  profile =
      rawProfile != null
          ? Map<String, dynamic>.from(
              rawProfile,
            )
          : null;

  following =
      isFollowing;

  loading = false;
});
    } catch (e) {
      debugPrint(
        'Could not load public profile: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });
    }
  }

  Future<void>
      _toggleFollow() async {
    if (changingFollow) {
      return;
    }

    setState(() {
      changingFollow = true;
    });

    try {
      if (following) {
        await community
            .unfollowUser(
          widget.userId,
        );
      } else {
        await community
            .followUser(
          widget.userId,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        following =
            !following;
      });
    } catch (e) {
      debugPrint(
        'Could not change follow state: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          changingFollow = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (loading) {
      return const Scaffold(
        backgroundColor:
            chipluxBackground,
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (profile == null) {
      return Scaffold(
        backgroundColor:
            chipluxBackground,
        appBar: AppBar(
          backgroundColor:
              Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Profile not found.',
          ),
        ),
      );
    }

    // =========================
    // BASIC PROFILE
    // =========================

    final displayName =
        profile!['display_name']
                ?.toString()
                .trim() ??
            '';

    final username =
        profile!['username']
                ?.toString()
                .trim() ??
            '';

    final avatarUrl =
        profile!['avatar_url']
            ?.toString();

    final bannerPath =
        profile!['banner_path']
            ?.toString();

    final name =
        displayName.isNotEmpty
            ? displayName
            : username.isNotEmpty
                ? username
                : 'Chiplux User';

    final bannerUrl =
        bannerPath != null &&
                bannerPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w1280$bannerPath'
            : null;

    final ownUserId =
        Supabase.instance.client
            .auth.currentUser?.id;

    final isOwnProfile =
        ownUserId ==
            widget.userId;

    // =========================
    // PUBLIC STATS
    // =========================

    final rawStats =
        profile!['public_stats'];

    final publicStats =
        rawStats is Map
            ? Map<String, dynamic>.from(
                rawStats,
              )
            : <String, dynamic>{};

    int intStat(
      String key,
    ) {
      final value =
          publicStats[key];

      if (value is num) {
        return value.toInt();
      }

      return 0;
    }

    double doubleStat(
      String key,
    ) {
      final value =
          publicStats[key];

      if (value is num) {
        return value.toDouble();
      }

      return 0.0;
    }

    final totalWatchedMinutes =
        intStat(
      'total_watched_minutes',
    );

    final moviesWatched =
        intStat(
      'movies_watched',
    );

    final episodesWatched =
        intStat(
      'episodes_watched',
    );

    final episodeRatings =
        intStat(
      'episode_ratings',
    );

    final titleRatings =
        intStat(
      'title_ratings',
    );

    final criticLevel =
        intStat(
      'critic_level',
    );

    final criticXp =
        intStat(
      'critic_xp',
    );

    final criticRequiredXp =
        intStat(
      'critic_required_xp',
    );

    final totalRatings =
        intStat(
      'total_ratings',
    );

    final averageStars =
        doubleStat(
      'average_stars',
    );

    final titleCoverage =
        doubleStat(
      'title_coverage',
    );

    final episodeCoverage =
        doubleStat(
      'episode_coverage',
    );

    final rawViewerTitle =
        publicStats[
                'viewer_title']
            ?.toString()
            .trim();

    final viewerTitle =
        rawViewerTitle != null &&
                rawViewerTitle
                    .isNotEmpty
            ? rawViewerTitle
            : 'VIEWER';

    final rawCriticTitle =
        publicStats[
                'critic_title']
            ?.toString()
            .trim();

    final criticTitle =
        rawCriticTitle != null &&
                rawCriticTitle
                    .isNotEmpty
            ? rawCriticTitle
            : 'NEW CRITIC';

    // =========================
    // GENRE RUNTIME
    // =========================

    final genreRuntime =
        <Map<String, dynamic>>[];

    final rawGenreRuntime =
        publicStats[
            'genre_runtime'];

    if (rawGenreRuntime
        is List) {
      for (final item
          in rawGenreRuntime) {
        if (item is Map) {
          genreRuntime.add(
            Map<String, dynamic>.from(
              item,
            ),
          );
        }
      }
    }

    // =========================
    // RATING DISTRIBUTION
    // =========================

    final ratingDistribution =
        <int, int>{
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
    };

    final rawDistribution =
        publicStats[
            'rating_distribution'];

    if (rawDistribution
        is Map) {
      for (int rating = 1;
          rating <= 5;
          rating++) {
        final value =
            rawDistribution[
                '$rating'];

        if (value is num) {
          ratingDistribution[
                  rating] =
              value.toInt();
        }
      }
    }

    // =========================
    // ACHIEVEMENTS + MEDAL
    // =========================

    final movieGroup =
        _movieAchievementGroupFor(
      moviesWatched,
    );

    final pinnedId =
        profile![
                'pinned_achievement_id']
            ?.toString();

    final _Achievement?
        pinnedAchievement =
        pinnedId ==
                movieGroup.id
            ? movieGroup
                .highestUnlockedTier
            : null;

    return Scaffold(
      backgroundColor:
          chipluxBackground,

      body: ChipluxBackground(
        style:
            ChipluxBackgroundStyle
                .profile,

        child: SafeArea(
          child: RefreshIndicator(
            color:
                chipluxCyan,

            backgroundColor:
                chipluxSurface,

            onRefresh:
                _load,

            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              padding:
                  const EdgeInsets
                      .fromLTRB(
                18,
                12,
                18,
                35,
              ),

              children: [
                // =========================
                // TOP BAR
                // =========================

                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },
                      icon:
                          const Icon(
                        Icons
                            .arrow_back_rounded,
                      ),
                    ),

                    const Spacer(),

                    const Text(
                      'Profile',
                      style:
                          TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    _FollowerCountBadge(
  userId:
      widget.userId,
),
                  ],
                ),

                const SizedBox(
                  height: 8,
                ),

                // =========================
                // BANNER
                // =========================

                SizedBox(
                  height: 150,
                  child:
                      ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      22,
                    ),
                    child:
                        _ProfileBanner(
                      imageUrl:
                          bannerUrl,
                    ),
                  ),
                ),

                // =========================
                // AVATAR / NAME / FOLLOW
                // =========================

                Transform.translate(
                  offset:
                      const Offset(
                    0,
                    -42,
                  ),

                  child: Column(
                    children: [
                      Container(
                        width: 94,
                        height: 94,
                        padding:
                            const EdgeInsets
                                .all(
                          3,
                        ),
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,

                          border:
                              Border.all(
                            color:
                                Colors.white,
                            width: 2,
                          ),

                          color:
                              chipluxBackground,

                          boxShadow: [
                            BoxShadow(
                              color:
                                  chipluxViolet
                                      .withValues(
                                alpha: 0.15,
                              ),
                              blurRadius:
                                  20,
                            ),
                          ],
                        ),

                        child:
                            Container(
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,

                            gradient:
                                avatarUrl ==
                                            null ||
                                        avatarUrl
                                            .isEmpty
                                    ? const LinearGradient(
                                        colors: [
                                          chipluxCyan,
                                          chipluxViolet,
                                          chipluxPurple,
                                        ],
                                      )
                                    : null,

                            image:
                                avatarUrl !=
                                            null &&
                                        avatarUrl
                                            .isNotEmpty
                                    ? DecorationImage(
                                        image:
                                            NetworkImage(
                                          avatarUrl,
                                        ),
                                        fit:
                                            BoxFit.cover,
                                      )
                                    : null,
                          ),

                          child:
                              avatarUrl ==
                                          null ||
                                      avatarUrl
                                          .isEmpty
                                  ? Center(
                                      child:
                                          Text(
                                        name.isNotEmpty
                                            ? name[0]
                                                .toUpperCase()
                                            : 'C',
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              38,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      // DISPLAY NAME + PINNED MEDAL

                      Stack(
                        clipBehavior:
                            Clip.none,
                        alignment:
                            Alignment.center,
                        children: [
                          Container(
                            padding:
                                EdgeInsets
                                    .fromLTRB(
                              pinnedAchievement !=
                                      null
                                  ? 34
                                  : 20,
                              8,
                              20,
                              8,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  chipluxSurface
                                      .withValues(
                                alpha:
                                    0.94,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                29,
                              ),
                              border:
                                  Border.all(
                                color:
                                    Colors.white
                                        .withValues(
                                  alpha:
                                      0.12,
                                ),
                              ),
                            ),
                            child:
                                Text(
                              name,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),

                          if (pinnedAchievement !=
                              null)
                            Positioned(
                              left: -12,
                              top: 6,
                              child:
                                  _PinnedAchievementBadge(
                                achievement:
                                    pinnedAchievement,
                              ),
                            ),
                        ],
                      ),

                      if (username
    .isNotEmpty) ...[
  const SizedBox(
    height: 6,
  ),

  Text(
    '@$username',
    style:
        const TextStyle(
      color:
          Colors.white54,
      fontSize:
          14,
    ),
  ),
],


if (!isOwnProfile) ...[
  const SizedBox(
    height: 18,
  ),

                        SizedBox(
                          width: 180,
                          height: 46,
                          child:
                              ElevatedButton
                                  .icon(
                            onPressed:
                                changingFollow
                                    ? null
                                    : _toggleFollow,

                            icon:
                                changingFollow
                                    ? const SizedBox(
                                        width:
                                            18,
                                        height:
                                            18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : Icon(
                                        following
                                            ? Icons
                                                .check_rounded
                                            : Icons
                                                .person_add_alt_1_rounded,
                                      ),

                            label:
                                Text(
                              following
                                  ? 'Following'
                                  : 'Follow',
                            ),

                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  following
                                      ? chipluxSurfaceLight
                                      : chipluxViolet,

                              foregroundColor:
                                  Colors.white,

                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Compensates for the upward
                // profile-header translation.
                const SizedBox(
                  height: 2,
                ),

                if (publicStats
                    .isEmpty)
                  Container(
                    padding:
                        const EdgeInsets
                            .all(
                      20,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          chipluxSurface,
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),
                    child:
                        const Column(
                      children: [
                        Icon(
                          Icons
                              .bar_chart_rounded,
                          color:
                              Colors.white38,
                          size: 34,
                        ),

                        SizedBox(
                          height: 10,
                        ),

                        Text(
                          'No public stats yet.',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        SizedBox(
                          height: 5,
                        ),

                        Text(
                          'Stats will appear after this user syncs their profile.',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // =========================
                  // ACHIEVEMENTS
                  // =========================

                  _PublicAchievementsCard(
                    group:
                        movieGroup,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // =========================
                  // RUNTIME LEVEL
                  // =========================

                  _LevelCard(
                    totalMinutes:
                        totalWatchedMinutes,
                    title:
                        viewerTitle,
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Column(
  children: [
    _WatchStatCard(
      value:
          episodesWatched,

      label:
          'Episodes Watched',

      icon:
          Icons
              .playlist_add_check_rounded,
    ),

    const SizedBox(
      height:
          7,
    ),

    _WatchStatCard(
      value:
          moviesWatched,

      label:
          'Movies Watched',

      icon:
          Icons
              .movie_outlined,
    ),
  ],
),

                  const SizedBox(
                    height: 16,
                  ),

                  // =========================
                  // RATING LEVEL
                  // =========================

                  _CriticReputationCard(
                    level:
                        criticLevel <= 0
                            ? 1
                            : criticLevel,

                    title:
                        criticTitle,

                    xp:
                        criticXp,

                    requiredXp:
                        criticRequiredXp <=
                                0
                            ? 10
                            : criticRequiredXp,

                    totalRatings:
                        totalRatings,

                    titleCoverage:
                        titleCoverage,

                    episodeCoverage:
                        episodeCoverage,

                    averageStars:
                        averageStars,
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Column(
  children: [
    _RatingStatCard(
      value:
          episodeRatings,

      label:
          'Episodes Rated',

      icon:
          Icons.tv_outlined,
    ),

    const SizedBox(
      height:
          7,
    ),

    _RatingStatCard(
      value:
          titleRatings,

      label:
          'Titles Rated',

      icon:
          Icons
              .movie_filter_outlined,
    ),
  ],
),

                  const SizedBox(
                    height: 24,
                  ),

                  // =========================
                  // GENRE RUNTIME
                  // =========================

                  _PublicGenreRuntimeCard(
                    stats:
                        genreRuntime,
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // =========================
                  // RATING DISTRIBUTION
                  // =========================

                  _PublicRatingDistributionCard(
                    distribution:
                        ratingDistribution,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicAchievementsCard
    extends StatelessWidget {
  final _AchievementGroup group;

  const _PublicAchievementsCard({
    required this.group,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final unlocked =
        group.tiers
            .where(
              (
                achievement,
              ) =>
                  achievement
                      .unlocked,
            )
            .toList();

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color:
            chipluxSurface,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              chipluxViolet
                  .withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .workspace_premium_rounded,
                color:
                    chipluxViolet,
                size: 27,
              ),

              SizedBox(
                width: 10,
              ),

              Text(
                'Achievements',
                style:
                    TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          if (unlocked
              .isEmpty)
            const Text(
              'No achievements unlocked yet.',
              style:
                  TextStyle(
                color:
                    Colors.white54,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  unlocked.map(
                (
                  achievement,
                ) {
                  return Container(
                    width: 155,
                    padding:
                        const EdgeInsets
                            .all(
                      11,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          chipluxSurfaceLight
                              .withValues(
                        alpha: 0.65,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child:
                              _AchievementMedal(
                            achievement:
                                achievement,
                          ),
                        ),

                        const SizedBox(
                          width: 9,
                        ),

                        Expanded(
                          child:
                              Text(
                            achievement
                                .title,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize:
                                  12,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ).toList(),
            ),
        ],
      ),
    );
  }
}

class _PublicGenreRuntimeCard
    extends StatefulWidget {
  final List<
      Map<String, dynamic>>
      stats;

  const _PublicGenreRuntimeCard({
    required this.stats,
  });

  @override
  State<_PublicGenreRuntimeCard>
      createState() =>
          _PublicGenreRuntimeCardState();
}

class _PublicGenreRuntimeCardState
    extends State<
        _PublicGenreRuntimeCard> {
  bool expanded = false;

  String _formatRuntime(
    int totalMinutes,
  ) {
    final hours =
        totalMinutes ~/ 60;

    final minutes =
        totalMinutes % 60;

    if (hours > 0 &&
        minutes > 0) {
      return '${hours}h ${minutes}m';
    }

    if (hours > 0) {
      return '${hours}h';
    }

    return '${minutes}m';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final stats =
        widget.stats;

    final visible =
        expanded
            ? stats
            : stats
                .take(4)
                .toList();

    const colors =
        <Color>[
      chipluxCyan,
      Color(0xFF55C7FF),
      chipluxViolet,
      chipluxPurple,
      Color(0xFF6F7CFF),
      Color(0xFF43B8FF),
      Color(0xFFB56DFF),
      Color(0xFF5363B8),
    ];

    Color statColor(
      int index,
    ) {
      return colors[
          index %
              colors.length];
    }

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color:
            chipluxSurface,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              chipluxCyan
                  .withValues(
            alpha: 0.14,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .bar_chart_rounded,
                color:
                    chipluxCyan,
                size: 27,
              ),

              SizedBox(
                width: 10,
              ),

              Text(
                'Genre Runtime',
                style:
                    TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          if (stats.isEmpty)
            const Text(
              'No genre runtime yet.',
              style:
                  TextStyle(
                color:
                    Colors.white54,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius:
                  BorderRadius
                      .circular(
                30,
              ),
              child: SizedBox(
                height: 20,
                child: Row(
                  children:
                      stats
                          .asMap()
                          .entries
                          .where(
                    (entry) {
                      final minutes =
                          entry.value[
                              'minutes'];

                      return minutes
                              is num &&
                          minutes
                                  .toInt() >
                              0;
                    },
                  ).map(
                    (entry) {
                      final minutes =
                          (entry.value[
                                      'minutes']
                                  as num)
                              .toInt();

                      return Expanded(
                        flex:
                            minutes,
                        child:
                            Container(
                          color:
                              statColor(
                            entry.key,
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            for (int i = 0;
                i < visible.length;
                i++) ...[
              Builder(
                builder:
                    (
                  context,
                ) {
                  final stat =
                      visible[i];

                  final genre =
                      stat['genre']
                              ?.toString() ??
                          'Other';

                  final minutes =
                      stat['minutes']
                              is num
                          ? (stat[
                                      'minutes']
                                  as num)
                              .toInt()
                          : 0;

                  final percentage =
                      stat['percentage']
                              is num
                          ? (stat[
                                      'percentage']
                                  as num)
                              .toDouble()
                          : 0.0;

                  return Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            color:
                                statColor(
                              i,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child:
                              Text(
                            genre,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),

                        SizedBox(
                          width: 62,
                          child:
                              Text(
                            '${percentage.toStringAsFixed(1)}%',
                            textAlign:
                                TextAlign
                                    .right,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        SizedBox(
                          width: 75,
                          child:
                              Text(
                            _formatRuntime(
                              minutes,
                            ),
                            textAlign:
                                TextAlign
                                    .right,
                            style:
                                const TextStyle(
                              color:
                                  Colors
                                      .white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            if (stats.length >
                4) ...[
              const SizedBox(
                height: 10,
              ),

              InkWell(
                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
                onTap: () {
                  setState(() {
                    expanded =
                        !expanded;
                  });
                },
                child: Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 11,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        chipluxSurfaceLight
                            .withValues(
                      alpha: 0.55,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      Text(
                        expanded
                            ? 'Show less'
                            : 'Show all ${stats.length} genres',
                        style:
                            const TextStyle(
                          color:
                              chipluxCyan,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      Icon(
                        expanded
                            ? Icons
                                .keyboard_arrow_up_rounded
                            : Icons
                                .keyboard_arrow_down_rounded,
                        color:
                            chipluxCyan,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PublicRatingDistributionCard
    extends StatelessWidget {
  final Map<int, int>
      distribution;

  const _PublicRatingDistributionCard({
    required this.distribution,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    const criticGold =
        Color(
      0xFFFFC857,
    );

    const criticOrange =
        Color(
      0xFFFF8A4C,
    );

    final total =
        distribution.values
            .fold<int>(
      0,
      (
        sum,
        value,
      ) =>
          sum + value,
    );

    Color ratingColor(
      int rating,
    ) {
      final t =
          (rating - 1) / 4;

      if (t < 0.5) {
        return Color.lerp(
          criticOrange,
          criticGold,
          t * 2,
        )!;
      }

      return Color.lerp(
        criticGold,
        chipluxPurple,
        (t - 0.5) * 2,
      )!;
    }

    final active =
        <int>[];

    for (int rating = 1;
        rating <= 5;
        rating++) {
      if ((distribution[
                  rating] ??
              0) >
          0) {
        active.add(
          rating,
        );
      }
    }

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color:
            chipluxSurface,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              criticGold
                  .withValues(
            alpha: 0.14,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .star_rate_rounded,
                color:
                    criticGold,
                size: 27,
              ),

              SizedBox(
                width: 10,
              ),

              Text(
                'Rating Distribution',
                style:
                    TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              30,
            ),
            child: Container(
              height: 20,
              color:
                  Colors.white10,
              child:
                  active.isEmpty
                      ? const SizedBox
                          .expand()
                      : Row(
                          children:
                              active.map(
                            (
                              rating,
                            ) {
                              final count =
                                  distribution[
                                          rating] ??
                                      0;

                              return Expanded(
                                flex:
                                    count,
                                child:
                                    Container(
                                  color:
                                      ratingColor(
                                    rating,
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                        ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          for (int rating = 1;
              rating <= 5;
              rating++) ...[
            Builder(
              builder:
                  (
                context,
              ) {
                final count =
                    distribution[
                            rating] ??
                        0;

                final percentage =
                    total > 0
                        ? (count /
                                total) *
                            100
                        : 0.0;

                return Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .star_rounded,
                        color:
                            ratingColor(
                          rating,
                        ),
                        size: 18,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      SizedBox(
                        width: 50,
                        child:
                            Text(
                          '$rating ★',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),

                      Expanded(
                        child:
                            Text(
                          '$count ${count == 1 ? 'rating' : 'ratings'}',
                          style:
                              const TextStyle(
                            color:
                                Colors
                                    .white60,
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 64,
                        child:
                            Text(
                          '${percentage.toStringAsFixed(1)}%',
                          textAlign:
                              TextAlign.right,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipluxBottomNav
    extends StatelessWidget {
  final int currentIndex;
  final String? avatarUrl;
  final ValueChanged<int> onTap;

  const _ChipluxBottomNav({
    required this.currentIndex,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
  (
    label: 'Discover',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  (
    label: 'Search',
    icon: Icons.search,
    selectedIcon: Icons.search,
  ),
  (
    label: 'Watch',
    icon:
        Icons.video_library_outlined,
    selectedIcon:
        Icons.video_library,
  ),
  (
    label: 'Community',
    icon:
        Icons.people_outline,
    selectedIcon:
        Icons.people,
  ),
  (
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

    return SafeArea(
      top: false,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: const Color(
            0xFF091521,
          ),
          border: Border(
            top: BorderSide(
              color: Colors.white
                  .withValues(
                alpha: 0.04,
              ),
            ),
          ),
        ),
        child: LayoutBuilder(
          builder:
              (context, constraints) {
            final itemWidth =
                constraints.maxWidth /
                    items.length;

            return Stack(
              children: [
                // MOVING GRADIENT PILL
                AnimatedPositioned(
                  duration:
                      const Duration(
                    milliseconds: 320,
                  ),
                  curve:
                      Curves
                          .easeInOutCubic,
                  left:
                      currentIndex *
                          itemWidth +
                      17,
                  top: 12,
                  width:
                      itemWidth - 34,
                  height: 40,
                  child: Container(
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius
                              .circular(
                        24,
                      ),
                      gradient:
                          LinearGradient(
                        colors: [
                          chipluxCyan
                              .withValues(
                            alpha:
                                0.24,
                          ),
                          chipluxViolet
                              .withValues(
                            alpha:
                                0.22,
                          ),
                          chipluxPurple
                              .withValues(
                            alpha:
                                0.24,
                          ),
                        ],
                      ),
                      border:
                          Border.all(
                        color:
                            chipluxViolet
                                .withValues(
                          alpha:
                              0.25,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              chipluxPurple
                                  .withValues(
                            alpha:
                                0.08,
                          ),
                          blurRadius:
                              15,
                        ),
                      ],
                    ),
                  ),
                ),

                Row(
                  children: [
                    for (int i = 0;
                        i <
                            items
                                .length;
                        i++)
                      Expanded(
                        child:
                            _BottomNavItem(
                          label:
                              items[i]
                                  .label,
                          icon:
                              items[i]
                                  .icon,
                          selectedIcon:
                              items[i]
                                  .selectedIcon,
                          selected:
                              currentIndex ==
                                  i,
                          avatarUrl:
    i == 4
        ? avatarUrl
        : null,
                          onTap:
                              () =>
                                  onTap(
                            i,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BottomNavItem
    extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 88,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 31,
              child: Center(
                child: avatarUrl !=
                            null &&
                        avatarUrl!
                            .trim()
                            .isNotEmpty
                    ? _BottomNavAvatar(
                        avatarUrl:
                            avatarUrl,
                        selected:
                            selected,
                      )
                    : selected
                        ? ShaderMask(
                            shaderCallback:
                                (bounds) {
                              return const LinearGradient(
                                colors: [
                                  chipluxCyan,
                                  chipluxViolet,
                                  chipluxPurple,
                                ],
                              ).createShader(
                                bounds,
                              );
                            },
                            child:
                                Icon(
                              selectedIcon,
                              color:
                                  Colors
                                      .white,
                              size: 27,
                            ),
                          )
                        : Icon(
                            icon,
                            color:
                                Colors
                                    .white70,
                            size: 26,
                          ),
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            SizedBox(
  height: 18,
  width: double.infinity,
  child: Padding(
    padding:
        const EdgeInsets.symmetric(
      horizontal: 4,
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: selected
          ? GradientText(
              label,
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
              ),
            )
          : Text(
              label,
              maxLines: 1,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize: 13,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
    ),
  ),
),
          ],
        ),
      ),
    );
  }
}

class _BottomNavAvatar
    extends StatelessWidget {
  final String? avatarUrl;
  final bool selected;

  const _BottomNavAvatar({
    required this.avatarUrl,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        avatarUrl != null &&
        avatarUrl!.trim().isNotEmpty;

    if (!hasAvatar) {
      return Icon(
        selected
            ? Icons.person
            : Icons.person_outline,
      );
    }

    return Container(
      width: 28,
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? chipluxCyan
              : Colors.white38,
          width: selected ? 2 : 1,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return Icon(
              selected
                  ? Icons.person
                  : Icons.person_outline,
              size: 20,
            );
          },
        ),
      ),
    );
  }
}

class ChipluxWordmark
    extends StatelessWidget {
  final double fontSize;

  const ChipluxWordmark({
    super.key,
    this.fontSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Chip',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: Colors.white,
          ),
        ),
        GradientText(
          'lux',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
      ],
    );
  }
}

class GradientText
    extends StatelessWidget {
  final String text;
  final TextStyle style;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            chipluxCyan,
            chipluxViolet,
            chipluxPurple,
          ],
        ).createShader(bounds);
      },
      child: Text(
        text,
        style: style.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

class BrandedTitle extends StatelessWidget {
  final String whitePart;
  final String gradientPart;
  final double fontSize;

  const BrandedTitle({
    super.key,
    required this.whitePart,
    required this.gradientPart,
    this.fontSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          whitePart,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            color: Colors.white,
          ),
        ),
        GradientText(
          gradientPart,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
        ),
      ],
    );
  }
}

enum ChipluxTopListType {
  movies,
  tvShows,
  shortMovies,
  superheroMovies,
  hiddenGems,
}

class ChipluxListDefinition {
  final ChipluxTopListType type;
  final String title;
  final String subtitle;
  final String mediaType;
  final IconData icon;

  const ChipluxListDefinition({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.mediaType,
    required this.icon,
  });
}

const chipluxTopLists =
    <ChipluxListDefinition>[
  ChipluxListDefinition(
    type:
        ChipluxTopListType.movies,
    title:
        'Top 100 Movies of All Time',
    subtitle:
        'The highest-rated movies on TMDB',
    mediaType: 'movie',
    icon:
        Icons.local_movies_outlined,
  ),

  ChipluxListDefinition(
    type:
        ChipluxTopListType.tvShows,
    title:
        'Top 100 TV Shows of All Time',
    subtitle:
        'The highest-rated TV series on TMDB',
    mediaType: 'tv',
    icon:
        Icons.tv_outlined,
  ),

  ChipluxListDefinition(
    type:
        ChipluxTopListType.shortMovies,
    title:
        'Top 100 Movies Under 90 Minutes',
    subtitle:
        'Highly-rated movies for a shorter watch',
    mediaType: 'movie',
    icon:
        Icons.timer_outlined,
  ),

  ChipluxListDefinition(
    type:
        ChipluxTopListType
            .superheroMovies,
    title:
        'Top 100 Superhero Movies',
    subtitle:
        'Heroes, villains and comic-book worlds',
    mediaType: 'movie',
    icon:
        Icons.bolt_outlined,
  ),

  ChipluxListDefinition(
    type:
        ChipluxTopListType.hiddenGems,
    title:
        'Top 100 Hidden Gems',
    subtitle:
        'Highly-rated movies outside the mainstream',
    mediaType: 'movie',
    icon:
        Icons.diamond_outlined,
  ),
];

class HomePage
    extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState
    extends State<HomePage> {
  final TmdbService tmdbService =
      TmdbService();

  final LibraryService library =
      LibraryService.instance;

  // 0 = Trending
  // 1 = 100 Lists
  // 2 = Today
  int discoverTab = 0;

  // ====================================================
  // TRENDING CACHE
  // ====================================================

  static const String
      _discoverCacheKey =
      'chiplux_discover_cache_v1';

  static List<dynamic>? _memoryTv;
  static List<dynamic>?
      _memoryMovies;
  static List<dynamic>?
      _memoryAnime;

  static int?
      _memoryUpdatedAt;

  List<dynamic> trendingTv = [];
  List<dynamic> trendingMovies = [];
  List<dynamic> trendingAnime = [];

  bool loading = true;
  String? errorMessage;

  // ====================================================
  // TODAY
  // ====================================================

  static const String
      _todayCacheKey =
      'chiplux_today_cache_v1';

  Map<String, dynamic>?
      todaysMovie;

  Map<String, dynamic>?
      todaysTvShow;

  Map<String, dynamic>?
      releasedTodayMovie;

  Map<String, dynamic>?
      airingTodayTv;

  bool todayLoading = false;
  String? todayError;

  @override
  void initState() {
    super.initState();

    _loadCachedThenRefresh();
  }

  // ====================================================
  // TRENDING
  // ====================================================

  bool _cacheIsOld(
    int? updatedAt,
  ) {
    if (updatedAt == null) {
      return true;
    }

    final age =
        DateTime.now()
                .millisecondsSinceEpoch -
            updatedAt;

    return age >
        const Duration(
          minutes: 30,
        ).inMilliseconds;
  }

  Future<void>
      _loadCachedThenRefresh() async {
    if (_memoryTv != null &&
        _memoryMovies != null &&
        _memoryAnime != null) {
      trendingTv =
          List<dynamic>.from(
        _memoryTv!,
      );

      trendingMovies =
          List<dynamic>.from(
        _memoryMovies!,
      );

      trendingAnime =
          List<dynamic>.from(
        _memoryAnime!,
      );

      loading = false;
      errorMessage = null;

      if (_cacheIsOld(
        _memoryUpdatedAt,
      )) {
        unawaited(
          loadTrending(
            showLoader: false,
          ),
        );
      }

      return;
    }

    try {
      final prefs =
          await SharedPreferences
              .getInstance();

      final raw =
          prefs.getString(
        _discoverCacheKey,
      );

      if (raw != null &&
          raw.isNotEmpty) {
        final decoded =
            jsonDecode(raw);

        if (decoded is Map) {
          final tv =
              decoded['tv'];

          final movies =
              decoded['movies'];

          final anime =
              decoded['anime'];

          final updatedAt =
              decoded['updatedAt'];

          if (tv is List &&
              movies is List &&
              anime is List) {
            _memoryTv =
                List<dynamic>.from(
              tv,
            );

            _memoryMovies =
                List<dynamic>.from(
              movies,
            );

            _memoryAnime =
                List<dynamic>.from(
              anime,
            );

            _memoryUpdatedAt =
                updatedAt is num
                    ? updatedAt
                        .toInt()
                    : null;

            if (!mounted) return;

            setState(() {
              trendingTv =
                  List<dynamic>.from(
                _memoryTv!,
              );

              trendingMovies =
                  List<dynamic>.from(
                _memoryMovies!,
              );

              trendingAnime =
                  List<dynamic>.from(
                _memoryAnime!,
              );

              loading = false;
              errorMessage = null;
            });

            if (_cacheIsOld(
              _memoryUpdatedAt,
            )) {
              unawaited(
                loadTrending(
                  showLoader:
                      false,
                ),
              );
            }

            return;
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Could not load Discover cache: $e',
      );
    }

    await loadTrending(
      showLoader: true,
    );
  }

  Future<void>
      _saveDiscoverCache() async {
    try {
      final prefs =
          await SharedPreferences
              .getInstance();

      await prefs.setString(
        _discoverCacheKey,
        jsonEncode({
          'updatedAt':
              DateTime.now()
                  .millisecondsSinceEpoch,
          'tv': trendingTv,
          'movies':
              trendingMovies,
          'anime':
              trendingAnime,
        }),
      );
    } catch (e) {
      debugPrint(
        'Could not save Discover cache: $e',
      );
    }
  }

  Future<void> loadTrending({
    bool showLoader = true,
  }) async {
    final hasExistingContent =
        trendingTv.isNotEmpty ||
        trendingMovies.isNotEmpty ||
        trendingAnime.isNotEmpty;

    if (showLoader &&
        !hasExistingContent &&
        mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final results =
          await Future.wait([
        tmdbService
            .getTrendingTv(),
        tmdbService
            .getTrendingMovies(),
        tmdbService
            .getTrendingAnime(),
      ]);

      if (!mounted) return;

      final now =
          DateTime.now()
              .millisecondsSinceEpoch;

      setState(() {
        trendingTv =
            results[0];

        trendingMovies =
            results[1];

        trendingAnime =
            results[2];

        loading = false;
        errorMessage = null;
      });

      _memoryTv =
          List<dynamic>.from(
        results[0],
      );

      _memoryMovies =
          List<dynamic>.from(
        results[1],
      );

      _memoryAnime =
          List<dynamic>.from(
        results[2],
      );

      _memoryUpdatedAt = now;

      unawaited(
        _saveDiscoverCache(),
      );
    } catch (e) {
      if (!mounted) return;

      if (hasExistingContent) {
        setState(() {
          loading = false;
        });

        return;
      }

      setState(() {
        loading = false;
        errorMessage =
            'Could not load trending titles.';
      });
    }
  }

  // ====================================================
  // DISCOVER TABS
  // ====================================================

  void _selectDiscoverTab(
    int index,
  ) {
    if (discoverTab == index) {
      return;
    }

    setState(() {
      discoverTab = index;
    });

    if (index == 2) {
      unawaited(
        _loadToday(),
      );
    }
  }

  Widget _buildDiscoverTabs() {
    const labels = [
      'Trending',
      '100 Lists',
      'Today',
    ];

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Container(
        height: 54,
        padding:
            const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: chipluxSurface,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: LayoutBuilder(
          builder:
              (
                context,
                constraints,
              ) {
            final width =
                constraints.maxWidth /
                    labels.length;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration:
                      const Duration(
                    milliseconds: 300,
                  ),
                  curve:
                      Curves
                          .easeInOutCubic,
                  left:
                      discoverTab *
                          width,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: Container(
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                      gradient:
                          LinearGradient(
                        colors: [
                          chipluxCyan
                              .withValues(
                            alpha:
                                .22,
                          ),
                          chipluxViolet
                              .withValues(
                            alpha:
                                .22,
                          ),
                          chipluxPurple
                              .withValues(
                            alpha:
                                .22,
                          ),
                        ],
                      ),
                      border:
                          Border.all(
                        color:
                            chipluxViolet
                                .withValues(
                          alpha:
                              .30,
                        ),
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    for (int i = 0;
                        i <
                            labels
                                .length;
                        i++)
                      Expanded(
                        child: InkWell(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          onTap: () {
                            _selectDiscoverTab(
                              i,
                            );
                          },
                          child: Center(
                            child: Text(
                              labels[i],
                              style:
                                  TextStyle(
                                fontSize:
                                    14,
                                fontWeight:
                                    discoverTab ==
                                            i
                                        ? FontWeight
                                            .bold
                                        : FontWeight
                                            .w500,
                                color:
                                    discoverTab ==
                                            i
                                        ? Colors
                                            .white
                                        : Colors
                                            .white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ====================================================
  // TODAY
  // ====================================================

  String _dayKey(
    DateTime date,
  ) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>?
      _mapFromDynamic(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return null;
  }

  bool _movieIsUnwatched(
    Map<String, dynamic> movie,
  ) {
    final id =
        movie['id'];

    if (id is! num) {
      return false;
    }

    final libraryItem =
        library.getItem(
      id.toInt(),
      'movie',
    );

    return libraryItem?.status !=
        'completed';
  }

  bool _tvIsUnwatched(
    Map<String, dynamic> show,
  ) {
    final id =
        show['id'];

    if (id is! num) {
      return false;
    }

    final showId =
        id.toInt();

    if (library
            .watchedCountForShow(
          showId,
        ) >
        0) {
      return false;
    }

    final libraryItem =
        library.getItem(
      showId,
      'tv',
    );

    return libraryItem?.status !=
        'completed';
  }

  Map<String, dynamic>?
      _dailyPick(
    List<dynamic> items,
    int salt,
  ) {
    if (items.isEmpty) {
      return null;
    }

    final now =
        DateTime.now();

    final seed =
        now.year * 10000 +
            now.month * 100 +
            now.day +
            salt;

    final index =
        seed.abs() %
            items.length;

    final item =
        items[index];

    if (item is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(
      item,
    );
  }

  Future<void> _loadToday({
    bool forceRefresh = false,
  }) async {
    if (todayLoading) {
      return;
    }

    final now =
        DateTime.now();

    final today =
        _dayKey(now);

    if (!forceRefresh) {
      try {
        final prefs =
            await SharedPreferences
                .getInstance();

        final raw =
            prefs.getString(
          _todayCacheKey,
        );

        if (raw != null &&
            raw.isNotEmpty) {
          final decoded =
              jsonDecode(raw);

          if (decoded is Map &&
              decoded['day'] ==
                  today) {
            final cachedMovie =
                _mapFromDynamic(
              decoded[
                  'todayMovie'],
            );

            final cachedTv =
                _mapFromDynamic(
              decoded[
                  'todayTv'],
            );

            final cachedRelease =
                _mapFromDynamic(
              decoded[
                  'releasedMovie'],
            );

            final cachedAiring =
                _mapFromDynamic(
              decoded[
                  'airingTv'],
            );

            final movieStillValid =
                cachedMovie ==
                        null ||
                    _movieIsUnwatched(
                      cachedMovie,
                    );

            final tvStillValid =
                cachedTv == null ||
                    _tvIsUnwatched(
                      cachedTv,
                    );

            if (movieStillValid &&
                tvStillValid) {
              if (!mounted) {
                return;
              }

              setState(() {
                todaysMovie =
                    cachedMovie;

                todaysTvShow =
                    cachedTv;

                releasedTodayMovie =
                    cachedRelease;

                airingTodayTv =
                    cachedAiring;

                todayLoading =
                    false;

                todayError =
                    null;
              });

              return;
            }
          }
        }
      } catch (e) {
        debugPrint(
          'Could not load Today cache: $e',
        );
      }
    }

    if (mounted) {
      setState(() {
        todayLoading = true;
        todayError = null;
      });
    }

    try {
      final results =
          await Future.wait([
        tmdbService
            .getDailyMoviePool(),
        tmdbService
            .getDailyTvPool(),
        tmdbService
            .getMoviesReleasedOn(
          now,
        ),
        tmdbService
            .getTvAiringOn(
          now,
        ),
      ]);

      final moviePool =
          results[0].where(
        (item) {
          if (item is! Map) {
            return false;
          }

          return _movieIsUnwatched(
            Map<String, dynamic>.from(
              item,
            ),
          );
        },
      ).toList();

      final tvPool =
          results[1].where(
        (item) {
          if (item is! Map) {
            return false;
          }

          return _tvIsUnwatched(
            Map<String, dynamic>.from(
              item,
            ),
          );
        },
      ).toList();

      final newMovie =
          _dailyPick(
        moviePool,
        17,
      );

      final newTv =
          _dailyPick(
        tvPool,
        41,
      );

      final newRelease =
          _dailyPick(
        results[2],
        73,
      );

      final newAiring =
          _dailyPick(
        results[3],
        101,
      );

      if (!mounted) return;

      setState(() {
        todaysMovie =
            newMovie;

        todaysTvShow =
            newTv;

        releasedTodayMovie =
            newRelease;

        airingTodayTv =
            newAiring;

        todayLoading = false;
        todayError = null;
      });

      final prefs =
          await SharedPreferences
              .getInstance();

      await prefs.setString(
        _todayCacheKey,
        jsonEncode({
          'day': today,
          'todayMovie':
              newMovie,
          'todayTv':
              newTv,
          'releasedMovie':
              newRelease,
          'airingTv':
              newAiring,
        }),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        todayLoading = false;
        todayError =
            'Could not load today\'s picks.';
      });
    }
  }

  Future<void> _openTodayItem(
    Map<String, dynamic> item,
    String mediaType,
  ) async {
    final id =
        item['id'];

    if (id is! num) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MediaDetailsPage(
          id: id.toInt(),
          mediaType:
              mediaType,
        ),
      ),
    );

    if (!mounted) return;

    // If the user watched/completed
    // the recommendation, replace it.
    unawaited(
      _loadToday(),
    );
  }

  // ====================================================
  // PAGES
  // ====================================================

  Widget _buildTrendingPage() {
    return RefreshIndicator(
      color: chipluxCyan,
      backgroundColor:
          chipluxSurface,
      onRefresh: () {
        return loadTrending(
          showLoader: false,
        );
      },
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(
          top: 18,
          bottom: 30,
        ),
        children: [
          if (loading)
            const Padding(
              padding:
                  EdgeInsets.only(
                top: 90,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            ),

          if (errorMessage !=
              null)
            Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Text(
                errorMessage!,
                style:
                    const TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
            ),

          if (!loading &&
              errorMessage ==
                  null) ...[
            const _SectionTitle(
              title:
                  'Trending TV Shows',
            ),

            const SizedBox(
              height: 14,
            ),

            _TrendingRow(
              items:
                  trendingTv,
              mediaType: 'tv',
            ),

            const SizedBox(
              height: 32,
            ),

            const _SectionTitle(
              title:
                  'Trending Movies',
            ),

            const SizedBox(
              height: 14,
            ),

            _TrendingRow(
              items:
                  trendingMovies,
              mediaType:
                  'movie',
            ),

            const SizedBox(
              height: 32,
            ),

            const _SectionTitle(
              title:
                  'Trending Anime',
            ),

            const SizedBox(
              height: 14,
            ),

            _TrendingRow(
              items:
                  trendingAnime,
              mediaType: 'tv',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListsPage() {
    return ListView.separated(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        35,
      ),
      itemCount:
          chipluxTopLists.length,
      separatorBuilder:
          (_, _) =>
              const SizedBox(
        height: 12,
      ),
      itemBuilder:
          (context, index) {
        final definition =
            chipluxTopLists[
                index];

        return _DiscoverListCard(
          definition:
              definition,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DiscoverTop100Page(
                  definition:
                      definition,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTodayPage() {
    if (todayLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (todayError != null) {
      return RefreshIndicator(
        color: chipluxCyan,
        onRefresh: () {
          return _loadToday(
            forceRefresh: true,
          );
        },
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(
              height: 120,
            ),
            Center(
              child: Text(
                todayError!,
                style:
                    const TextStyle(
                  color:
                      Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // First frame after changing
    // to Today.
    if (todaysMovie == null &&
        todaysTvShow == null &&
        releasedTodayMovie ==
            null &&
        airingTodayTv == null) {
      unawaited(
        _loadToday(),
      );

      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      color: chipluxCyan,
      backgroundColor:
          chipluxSurface,
      onRefresh: () {
        return _loadToday(
          forceRefresh: true,
        );
      },
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          20,
          22,
          20,
          35,
        ),
        children: [
  // =========================
  // RELEASED TODAY
  // =========================

  const Text(
    'Released Today',
    style: TextStyle(
      fontSize: 22,
      fontWeight:
          FontWeight.bold,
    ),
  ),

  const SizedBox(
    height: 12,
  ),

  _TodayCompactMediaCard(
  item:
      releasedTodayMovie,
    mediaType:
        'movie',
    emptyText:
        'No notable movie releases today.',
    onTap:
        releasedTodayMovie ==
                null
            ? null
            : () {
                _openTodayItem(
                  releasedTodayMovie!,
                  'movie',
                );
              },
  ),

  

  const SizedBox(
    height: 28,
  ),

  // =========================
  // AIRING TODAY
  // =========================

  const Text(
    'Airing Today',
    style: TextStyle(
      fontSize: 22,
      fontWeight:
          FontWeight.bold,
    ),
  ),

  const SizedBox(
    height: 12,
  ),

  _TodayCompactMediaCard(
  item:
      airingTodayTv,
    mediaType:
        'tv',
    emptyText:
        'No notable TV show is airing today.',
    onTap:
        airingTodayTv ==
                null
            ? null
            : () {
                _openTodayItem(
                  airingTodayTv!,
                  'tv',
                );
              },
  ),

  const SizedBox(
  height: 28,
),

// =========================
// TODAY'S MOVIE FOR YOU
// =========================

const Text(
  'Today\'s Random Movie for You',
    style: TextStyle(
      fontSize: 22,
      fontWeight:
          FontWeight.bold,
    ),
  ),

  const SizedBox(
    height: 12,
  ),

  _TodayMediaCard(
    item:
        todaysMovie,
    mediaType:
        'movie',
    emptyText:
        'No movie recommendation available.',
    onTap:
        todaysMovie == null
            ? null
            : () {
                _openTodayItem(
                  todaysMovie!,
                  'movie',
                );
              },
  ),

  const SizedBox(
    height: 28,
  ),

  // =========================
  // RANDOM TV SHOW
  // =========================

  const Text(
    'Today\'s Random TV Show for You',
    style: TextStyle(
      fontSize: 22,
      fontWeight:
          FontWeight.bold,
    ),
  ),

  const SizedBox(
    height: 12,
  ),

  _TodayMediaCard(
    item:
        todaysTvShow,
    mediaType:
        'tv',
    emptyText:
        'No TV recommendation available.',
    onTap:
        todaysTvShow == null
            ? null
            : () {
                _openTodayItem(
                  todaysTvShow!,
                  'tv',
                );
              },
  ),
],
      ),
    );
  }

  // ====================================================
  // BUILD
  // ====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              20,
              20,
              20,
              12,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      ChipluxWordmark(
                        fontSize: 34,
                      ),

                      SizedBox(
                        height: 4,
                      ),

                      Text(
                        'Your Watchlist · Your Word',
                        style:
                            TextStyle(
                          color:
                              Colors.white54,
                          fontSize: 11,
                          letterSpacing:
                              1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(
                    color:
                        chipluxSurface,
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),
                  child: IconButton(
                    tooltip: 'Menu',
                    icon:
                        const Icon(
                      Icons.menu_rounded,
                      size: 28,
                    ),
                    onPressed: () {
                      ScaffoldMessenger
                              .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Chiplux menu coming soon.',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          _buildDiscoverTabs(),

          const SizedBox(
            height: 4,
          ),

          Expanded(
            child:
                IndexedStack(
              index:
                  discoverTab,
              children: [
                _buildTrendingPage(),
                _buildListsPage(),
                _buildTodayPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverListCard
    extends StatelessWidget {
  final ChipluxListDefinition
      definition;

  final VoidCallback onTap;

  const _DiscoverListCard({
    required this.definition,
    required this.onTap,
  });

    Color _accentColor() {
  switch (definition.type) {
    case ChipluxTopListType.movies:
      return chipluxCyan;

    case ChipluxTopListType.tvShows:
      return chipluxViolet;

    case ChipluxTopListType.shortMovies:
      return const Color(
        0xFF43D9C5,
      );

    case ChipluxTopListType.superheroMovies:
      return chipluxPurple;

    case ChipluxTopListType.hiddenGems:
      return const Color(
        0xFFFFB84D,
      );
  }
}

List<Color> _backgroundColors() {
  final accent =
      _accentColor();

  return [
    Color.alphaBlend(
      accent.withValues(
        alpha: 0.16,
      ),
      chipluxSurface,
    ),
    Color.alphaBlend(
      chipluxViolet.withValues(
        alpha: 0.08,
      ),
      chipluxSurface,
    ),
    chipluxSurface,
  ];
}

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration: BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors:
        _backgroundColors(),
  ),
  borderRadius:
      BorderRadius.circular(
    20,
  ),
  border: Border.all(
    color:
        _accentColor()
            .withValues(
      alpha: 0.22,
    ),
  ),
  boxShadow: [
    BoxShadow(
      color:
          _accentColor()
              .withValues(
        alpha: 0.06,
      ),
      blurRadius: 18,
    ),
  ],
),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(
                    16,
                  ),
                  gradient: LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    _accentColor()
        .withValues(
      alpha: 0.40,
    ),
    chipluxPurple
        .withValues(
      alpha: 0.30,
    ),
  ],
),
                ),
                child: Icon(
                  definition.icon,
                  color:
                      _accentColor(),
                  size: 27,
                ),
              ),

              const SizedBox(
                width: 15,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      definition
                          .title,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      definition
                          .subtitle,
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayMediaCard
    extends StatelessWidget {
  final Map<String, dynamic>?
      item;

  final String mediaType;
  final String emptyText;
  final VoidCallback? onTap;

  const _TodayMediaCard({
    required this.item,
    required this.mediaType,
    required this.emptyText,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (item == null) {
      return Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.all(
          22,
        ),
        decoration:
            BoxDecoration(
          color: chipluxSurface,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),
        child: Text(
          emptyText,
          style:
              const TextStyle(
            color:
                Colors.white54,
          ),
        ),
      );
    }

    final title =
        item!['title'] ??
            item!['name'] ??
            'Unknown';

    final posterPath =
        item!['poster_path'];

    final posterUrl =
        posterPath != null
            ? 'https://image.tmdb.org/t/p/w342$posterPath'
            : null;

    final date =
        item!['release_date'] ??
            item![
                'first_air_date'] ??
            '';

    final year =
        date
                    .toString()
                    .length >=
                4
            ? date
                .toString()
                .substring(
                  0,
                  4,
                )
            : '';

    final rating =
        item!['vote_average']
                is num
            ? (item![
                        'vote_average']
                    as num)
                .toDouble()
            : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: Container(
  constraints:
      const BoxConstraints(
    minHeight: 165,
  ),
  padding:
      const EdgeInsets.all(
    12,
  ),
          decoration:
              BoxDecoration(
            color: chipluxSurface,
            borderRadius:
                BorderRadius
                    .circular(
              20,
            ),
            border: Border.all(
              color:
                  chipluxViolet
                      .withValues(
                alpha: .12,
              ),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
                child:
                    posterUrl !=
                            null
                        ? Image
                            .network(
                            posterUrl,
                            width:
                                96,
                            height:
                                141,
                            fit: BoxFit
                                .cover,
                          )
                        : Container(
                            width:
                                96,
                            height:
                                141,
                            color:
                                chipluxSurfaceLight,
                            child:
                                const Icon(
                              Icons
                                  .movie_outlined,
                            ),
                          ),
              ),

              const SizedBox(
                width: 15,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      mediaType ==
                              'tv'
                          ? 'TV Show'
                          : 'Movie',
                      style:
                          const TextStyle(
                        color:
                            chipluxCyan,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),

                    if (year
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        year,
                        style:
                            const TextStyle(
                          color:
                              Colors.white54,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 10,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color:
                              Colors.amber,
                          size: 18,
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        Text(
                          rating > 0
                              ? rating
                                  .toStringAsFixed(
                                    1,
                                  )
                              : '--',
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCompactMediaCard
    extends StatelessWidget {
  final Map<String, dynamic>?
      item;

  final String mediaType;
  final String emptyText;
  final VoidCallback? onTap;

  const _TodayCompactMediaCard({
    required this.item,
    required this.mediaType,
    required this.emptyText,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (item == null) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(
          18,
        ),
        decoration:
            BoxDecoration(
          color: chipluxSurface,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: Text(
          emptyText,
          style:
              const TextStyle(
            color:
                Colors.white54,
            fontSize: 13,
          ),
        ),
      );
    }

    final title =
        item!['title'] ??
            item!['name'] ??
            'Unknown';

    final posterPath =
        item!['poster_path'];

    final posterUrl =
        posterPath != null
            ? 'https://image.tmdb.org/t/p/w342$posterPath'
            : null;

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        child: Container(
          height: 125,
          padding:
              const EdgeInsets.all(
            10,
          ),
          decoration:
              BoxDecoration(
            color:
                chipluxSurface,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border:
                Border.all(
              color:
                  chipluxViolet
                      .withValues(
                alpha: 0.12,
              ),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                child:
                    posterUrl != null
                        ? Image.network(
                            posterUrl,
                            width: 72,
                            height: 105,
                            fit:
                                BoxFit.cover,
                          )
                        : Container(
                            width: 72,
                            height: 105,
                            color:
                                chipluxSurfaceLight,
                            child:
                                const Icon(
                              Icons.movie_outlined,
                              size: 22,
                            ),
                          ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      mediaType ==
                              'tv'
                          ? 'TV Show'
                          : 'Movie',
                      style:
                          const TextStyle(
                        color:
                            chipluxCyan,
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Colors.white38,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoverTop100Page
    extends StatefulWidget {
  final ChipluxListDefinition
      definition;

  const DiscoverTop100Page({
    super.key,
    required this.definition,
  });

  @override
  State<DiscoverTop100Page>
      createState() =>
          _DiscoverTop100PageState();
}

class _DiscoverTop100PageState
    extends State<
        DiscoverTop100Page> {
  final tmdb =
      TmdbService();

  static final Map<
          ChipluxTopListType,
          List<dynamic>>
      _memoryCache = {};

  List<dynamic> items = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<List<dynamic>>
      _fetchList() {
    switch (
        widget.definition.type) {
      case ChipluxTopListType
            .movies:
        return tmdb
            .getTop100Movies();

      case ChipluxTopListType
            .tvShows:
        return tmdb
            .getTop100TvShows();

      case ChipluxTopListType
            .shortMovies:
        return tmdb
            .getTop100ShortMovies();

      case ChipluxTopListType
            .superheroMovies:
        return tmdb
            .getTop100SuperheroMovies();

      case ChipluxTopListType
            .hiddenGems:
        return tmdb
            .getTop100HiddenGems();
    }
  }

  Future<void> _load({
    bool force = false,
  }) async {
    if (!force) {
      final cached =
          _memoryCache[
              widget.definition.type];

      if (cached != null) {
        setState(() {
          items =
              List<dynamic>.from(
            cached,
          );

          loading = false;
          error = null;
        });

        return;
      }
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result =
          await _fetchList();

      if (!mounted) return;

      _memoryCache[
              widget.definition.type] =
          List<dynamic>.from(
        result,
      );

      setState(() {
        items =
            result.take(100).toList();

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error =
            'Could not load this list.';
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          chipluxBackground,
      appBar: AppBar(
        backgroundColor:
            chipluxBackground,
        title: Text(
          widget.definition.title,
        ),
      ),
      body: ChipluxBackground(
        style:
            ChipluxBackgroundStyle
                .discover,
        child: loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : error != null
                ? Center(
                    child: Text(
                      error!,
                      style:
                          const TextStyle(
                        color:
                            Colors.redAccent,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color:
                        chipluxCyan,
                    onRefresh: () {
                      return _load(
                        force: true,
                      );
                    },
                    child:
                        ListView.separated(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        35,
                      ),
                      itemCount:
                          items.length,
                      separatorBuilder:
                          (_, _) =>
                              const SizedBox(
                        height: 8,
                      ),
                      itemBuilder:
                          (
                            context,
                            index,
                          ) {
                        final item =
                            items[
                                index];

                        return _Top100Row(
                          rank:
                              index +
                                  1,
                          item:
                              item,
                          mediaType:
                              widget
                                  .definition
                                  .mediaType,
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _Top100Row
    extends StatelessWidget {
  final int rank;
  final dynamic item;
  final String mediaType;

  const _Top100Row({
    required this.rank,
    required this.item,
    required this.mediaType,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final title =
        item['title'] ??
            item['name'] ??
            'Unknown';

    final posterPath =
        item['poster_path'];

    final posterUrl =
        posterPath != null
            ? 'https://image.tmdb.org/t/p/w185$posterPath'
            : null;

    final date =
        item['release_date'] ??
            item[
                'first_air_date'] ??
            '';

    final year =
        date
                    .toString()
                    .length >=
                4
            ? date
                .toString()
                .substring(
                  0,
                  4,
                )
            : '';

    final rating =
        item['vote_average']
                is num
            ? (item[
                        'vote_average']
                    as num)
                .toDouble()
            : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MediaDetailsPage(
                id:
                    (item['id']
                            as num)
                        .toInt(),
                mediaType:
                    mediaType,
              ),
            ),
          );
        },
        child: Container(
          height: 105,
          padding:
              const EdgeInsets.all(
            8,
          ),
          decoration:
              BoxDecoration(
            color: chipluxSurface,
            borderRadius:
                BorderRadius
                    .circular(
              16,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Center(
                  child: GradientText(
                    '#$rank',
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                ),
              ),

              ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(
                  10,
                ),
                child:
                    posterUrl !=
                            null
                        ? Image
                            .network(
                            posterUrl,
                            width: 58,
                            height: 89,
                            fit: BoxFit
                                .cover,
                          )
                        : Container(
                            width: 58,
                            height: 89,
                            color:
                                chipluxSurfaceLight,
                          ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Row(
                      children: [
                        if (year
                            .isNotEmpty)
                          Text(
                            year,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white54,
                              fontSize:
                                  12,
                            ),
                          ),

                        if (year
                                .isNotEmpty &&
                            rating >
                                0)
                          const Text(
                            '  •  ',
                            style:
                                TextStyle(
                              color:
                                  Colors.white38,
                            ),
                          ),

                        if (rating >
                            0) ...[
                          const Icon(
                            Icons.star,
                            color:
                                Colors.amber,
                            size: 14,
                          ),

                          const SizedBox(
                            width: 4,
                          ),

                          Text(
                            rating
                                .toStringAsFixed(
                                  1,
                                ),
                            style:
                                const TextStyle(
                              color:
                                  Colors.white60,
                              fontSize:
                                  12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right,
                color:
                    Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingRow
    extends StatelessWidget {
  final List<dynamic> items;
  final String mediaType;

  const _TrendingRow({
    required this.items,
    required this.mediaType,
  });

  @override
Widget build(
  BuildContext context,
) {
  final textScale =
      MediaQuery.textScalerOf(
    context,
  ).scale(1.0);

  final extraHeight =
      ((textScale - 1.0)
                  .clamp(
            0.0,
            0.5,
          )) *
          32;

  return SizedBox(
    height:
        266 + extraHeight,
      child: ListView.separated(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
        ),
        scrollDirection:
            Axis.horizontal,
        itemCount: items.length,
        separatorBuilder:
            (_, _) =>
                const SizedBox(
          width: 14,
        ),
        itemBuilder:
            (context, index) {
          final item = items[index];

          return _TrendingCard(
            item: item,
            mediaType: mediaType,
          );
        },
      ),
    );
  }
}

class _TrendingCard
    extends StatelessWidget {
  final dynamic item;
  final String mediaType;

  const _TrendingCard({
    required this.item,
    required this.mediaType,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final posterPath =
        item['poster_path'];

    final posterUrl =
        posterPath != null
            ? 'https://image.tmdb.org/t/p/w342$posterPath'
            : null;

    final title =
        item['name'] ??
        item['title'] ??
        'Unknown';

    final rating =
        (item['vote_average']
                is num)
            ? (item['vote_average']
                    as num)
                .toDouble()
            : 0.0;

    return SizedBox(
      width: 145,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MediaDetailsPage(
                id: item['id'],
                mediaType:
                    mediaType,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                      16),
              child: posterUrl != null
                  ? Image.network(
                      posterUrl,
                      width: 145,
                      height: 205,
                      fit:
                          BoxFit.cover,
                    )
                  : Container(
                      width: 145,
                      height: 205,
                      color:
                          chipluxSurface,
                      child:
                          const Icon(
                        Icons
                            .image_not_supported_outlined,
                      ),
                    ),
            ),

            const SizedBox(
                height: 8),

            Text(
              title,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
                height: 3),

            Row(
              children: [
                const Icon(
                  Icons.star,
                  size: 14,
                  color:
                      Colors.amber,
                ),

                const SizedBox(
                    width: 4),

                Text(
                  rating > 0
                      ? rating
                          .toStringAsFixed(
                              1)
                      : '--',
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle
    extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'watching':
      return 'Watching';
    case 'completed':
      return 'Completed';
    case 'dropped':
      return 'Dropped';
    default:
      return 'Plan to Watch';
  }
}

class SearchPage
    extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() =>
      _SearchPageState();
}

class _SearchPageState
    extends State<SearchPage> {
  final TextEditingController controller =
      TextEditingController();

  final TmdbService tmdbService =
      TmdbService();

Timer? _searchDebounce;

  List<dynamic> results = [];

  bool isLoading = false;

  String? errorMessage;

  Future<void> performSearch([String? value]) async {
  final query =
      (value ?? controller.text).trim();

  if (query.length < 2) {
    setState(() {
      results = [];
      errorMessage = null;
      isLoading = false;
    });
    return;
  }

  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final searchResults =
        await tmdbService.search(query);

    if (!mounted) return;

    // Ignore results if the user has already
    // typed something different.
    if (controller.text.trim() != query) {
      return;
    }

    setState(() {
      results = searchResults;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      errorMessage = 'Search failed';
    });
  } finally {
    if (mounted &&
        controller.text.trim() == query) {
      setState(() {
        isLoading = false;
      });
    }
  }
}

void onSearchChanged(String value) {
  _searchDebounce?.cancel();

  final query = value.trim();

  if (query.length < 2) {
    setState(() {
      results = [];
      errorMessage = null;
      isLoading = false;
    });
    return;
  }

  _searchDebounce = Timer(
    const Duration(milliseconds: 300),
    () {
      performSearch(query);
    },
  );
}

  @override
void dispose() {
  _searchDebounce?.cancel();
  controller.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              15,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const BrandedTitle(
  whitePart: 'Se',
  gradientPart: 'arch',
  fontSize: 30,
),

                const SizedBox(height: 15),

                TextField(
                  controller: controller,
                  onChanged: onSearchChanged,
                  onSubmitted:
                      (_) =>
                          performSearch(),
                  decoration:
                      InputDecoration(
                    hintText:
                        'Movies and TV shows',
                    prefixIcon:
                        const Icon(
                      Icons.search,
                    ),
                    suffixIcon:
                        IconButton(
                      icon: const Icon(
                        Icons
                            .arrow_forward,
                      ),
                      onPressed:
                          performSearch,
                    ),
                    filled: true,
                    fillColor:
                        chipluxSurface,
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(18),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isLoading)
            const Padding(
              padding:
                  EdgeInsets.all(20),
              child:
                  CircularProgressIndicator(),
            ),

          if (errorMessage != null)
            Text(
              errorMessage!,
              style: const TextStyle(
                color:
                    Colors.redAccent,
              ),
            ),

          if (!isLoading)
            Expanded(
              child:
                  ListView.separated(
                padding:
                    const EdgeInsets.all(
                        20),
                itemCount:
                    results.length,
                separatorBuilder:
                    (_, _) =>
                        const SizedBox(
                  height: 12,
                ),
                itemBuilder:
                    (context, index) {
                  final item =
                      results[index];

                  final mediaType =
                      item['media_type'];

                  final title =
                      item['title'] ??
                      item['name'] ??
                      'Unknown';

                  final date =
                      item['release_date'] ??
                      item[
                          'first_air_date'] ??
                      '';

                  final year =
                      date
                                  .toString()
                                  .length >=
                              4
                          ? date
                              .toString()
                              .substring(
                                  0, 4)
                          : '';  

                  final posterPath =
                      item['poster_path'];

                  final posterUrl =
                      posterPath != null
                          ? 'https://image.tmdb.org/t/p/w185$posterPath'
                          : null;

                  return InkWell(
                    borderRadius:
                        BorderRadius
                            .circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MediaDetailsPage(
                            id:
                                item['id'],
                            mediaType:
                                mediaType,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding:
                          const EdgeInsets
                              .all(10),
                      decoration:
                          BoxDecoration(
                        color:
                            chipluxSurface,
                        borderRadius:
                            BorderRadius
                                .circular(
                                    16),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius
                                    .circular(
                                        12),
                            child:
                                posterUrl !=
                                        null
                                    ? Image
                                        .network(
                                        posterUrl,
                                        width:
                                            72,
                                        height:
                                            105,
                                        fit: BoxFit
                                            .cover,
                                      )
                                    : Container(
                                        width:
                                            72,
                                        height:
                                            105,
                                        color:
                                            chipluxSurfaceLight,
                                      ),
                          ),

                          const SizedBox(
                              width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  title,
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        16,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(
                                    height: 7),

                                Text(
                                  mediaType ==
                                          'tv'
                                      ? 'TV Show'
                                      : 'Movie',
                                  style:
                                      const TextStyle(
                                    color:
                                        chipluxCyan,
                                  ),
                                ),

                                if (year
                                    .isNotEmpty) ...[
                                  const SizedBox(
                                      height:
                                          4),
                                  Text(
                                    year,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const Icon(
                            Icons
                                .chevron_right,
                            color:
                                Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class LibraryPage
    extends StatefulWidget {
  final String initialFilter;
  final String initialMediaType;
  final String? initialSortMode;
  final int openRequest;

  const LibraryPage({
    super.key,
    this.initialFilter = 'watching',
    this.initialMediaType = 'tv',
    this.initialSortMode,
    this.openRequest = 0,
  });

  @override
  State<LibraryPage> createState() =>
      _LibraryPageState();
}

class _LibraryPageState
    extends State<LibraryPage> {

  late String filter;
late String selectedMediaType;

final ScrollController
    _filterScrollController =
        ScrollController();

  final mediaUserDataService =
      MediaUserDataService.instance;

      final Map<String, String>
    _sortModeByList = {};

    static const String
    _watchingRecencyKey =
    'chiplux_watching_recency_v1';

final Map<int, int>
    _watchingRecency = {};

Future<void>
    _loadWatchingRecency()
    async {
  try {
    final prefs =
        await SharedPreferences
            .getInstance();

    final raw =
        prefs.getString(
      _watchingRecencyKey,
    );

    if (raw == null ||
        raw.isEmpty) {
      return;
    }

    final decoded =
        jsonDecode(raw);

    if (decoded is! Map) {
      return;
    }

    final loaded =
        <int, int>{};

    for (final entry
        in decoded.entries) {
      final showId =
          int.tryParse(
        entry.key.toString(),
      );

      final value =
          entry.value;

      if (showId == null ||
          value is! num) {
        continue;
      }

      loaded[showId] =
          value.toInt();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _watchingRecency
        ..clear()
        ..addAll(
          loaded,
        );
    });
  } catch (e) {
    debugPrint(
      'Could not load Watching recency: $e',
    );
  }
}

Future<void>
    _markWatchingShowRecent(
  int showId,
) async {
  final now =
      DateTime.now()
          .millisecondsSinceEpoch;

  _watchingRecency[showId] =
      now;

  if (mounted) {
    setState(() {});
  }

  try {
    final prefs =
        await SharedPreferences
            .getInstance();

    final data =
        <String, int>{};

    for (final entry
        in _watchingRecency
            .entries) {
      data[
          entry.key.toString()] =
          entry.value;
    }

    await prefs.setString(
      _watchingRecencyKey,
      jsonEncode(data),
    );
  } catch (e) {
    debugPrint(
      'Could not save Watching recency: $e',
    );
  }
}

String get _currentSortKey {
  final usesMediaType =
      filter == 'favorites' ||
      filter == 'completed' ||
      filter == 'plan' ||
      filter == 'dropped';

  if (usesMediaType) {
    return '$filter:$selectedMediaType';
  }

  return filter;
}

bool _isFullyRated(
  LibraryItem item,
) {
  final critic =
      CriticService.instance;

  if (item.mediaType ==
      'movie') {
    return critic.isMovieRated(
      item.id,
    );
  }

  final total =
      item.totalEpisodes;

  if (total <= 0) {
    return false;
  }

  final overallRating =
      critic.titleRatingStars(
    item.id,
    'tv',
  );

  final ratedEpisodes =
      critic
          .ratedEpisodeCountForShow(
    item.id,
  );

  return overallRating != null &&
      ratedEpisodes >= total;
}

void _sortCurrentList(
  List<LibraryItem> items,
) {
  final sortMode =
      _sortModeByList[
          _currentSortKey];

  items.sort(
    (a, b) {
      final bool aRated =
          _isFullyRated(a);

      final bool bRated =
          _isFullyRated(b);

      // =========================
      // SORT BY RATED
      // =========================

      if (sortMode == 'rated') {
        if (aRated != bRated) {
          return aRated
              ? -1
              : 1;
        }

        return b.addedAt
            .compareTo(
          a.addedAt,
        );
      }

      // =========================
      // SORT BY NOT RATED
      // =========================

      if (sortMode ==
          'notRated') {
        // Not-rated titles first.
        if (aRated != bRated) {
          return aRated
              ? 1
              : -1;
        }

        // If BOTH are unfinished TV shows,
        // put the one closest to being
        // fully rated first.
        if (!aRated &&
            !bRated &&
            a.mediaType == 'tv' &&
            b.mediaType == 'tv') {
          final critic =
              CriticService.instance;

          final int aTotal =
              a.totalEpisodes;

          final int bTotal =
              b.totalEpisodes;

          final int aRatedEpisodes =
              critic
                  .ratedEpisodeCountForShow(
            a.id,
          );

          final int bRatedEpisodes =
              critic
                  .ratedEpisodeCountForShow(
            b.id,
          );

          final double aProgress =
              aTotal > 0
                  ? aRatedEpisodes /
                      aTotal
                  : 0.0;

          final double bProgress =
              bTotal > 0
                  ? bRatedEpisodes /
                      bTotal
                  : 0.0;

          final int progressCompare =
              bProgress.compareTo(
            aProgress,
          );

          if (progressCompare != 0) {
            return progressCompare;
          }

          // If percentage is exactly
          // the same, prefer the show
          // with more rated episodes.
          final int countCompare =
              bRatedEpisodes.compareTo(
            aRatedEpisodes,
          );

          if (countCompare != 0) {
            return countCompare;
          }
        }

        // Movies, ties, and already-rated
        // titles keep newest first.
        return b.addedAt
            .compareTo(
          a.addedAt,
        );
      }

      // =========================
      // NORMAL ORDER
      // =========================

      return b.addedAt
          .compareTo(
        a.addedAt,
      );
    },
  );
}

Widget _buildSortButton() {
  final key =
      _currentSortKey;

  final selected =
      _sortModeByList[key];

  return Container(
    width: 44,
    height: 44,
    decoration:
        BoxDecoration(
      color:
          chipluxSurface,
      borderRadius:
          BorderRadius.circular(
        14,
      ),
      border:
          Border.all(
        color:
            selected != null
                ? chipluxViolet
                    .withValues(
                      alpha:
                          0.45,
                    )
                : Colors.white
                    .withValues(
                      alpha:
                          0.05,
                    ),
      ),
    ),
    child:
        PopupMenuButton<
            String>(
      tooltip:
          'Sort',
      padding:
          EdgeInsets.zero,
      icon:
          Icon(
        Icons.sort_rounded,
        size: 27,
        color:
            selected != null
                ? chipluxCyan
                : Colors.white70,
      ),
      color:
          chipluxSurface,
      onSelected:
          (value) {
        setState(() {
          _sortModeByList[
                  key] =
              value;
        });
      },
      itemBuilder:
          (context) {
        return [
          PopupMenuItem<
              String>(
            value:
                'rated',
            child: Row(
              children: [
                Icon(
                  Icons
                      .star_rounded,
                  color:
                      selected ==
                              'rated'
                          ? const Color(
                              0xFFFFC857,
                            )
                          : Colors
                              .white54,
                  size: 21,
                ),

                const SizedBox(
                  width: 10,
                ),

                Text(
                  'Sort by Rated',
                  style:
                      TextStyle(
                    color:
                        selected ==
                                'rated'
                            ? const Color(
                                0xFFFFC857,
                              )
                            : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          PopupMenuItem<
              String>(
            value:
                'notRated',
            child: Row(
              children: [
                Icon(
                  Icons
                      .star_outline_rounded,
                  color:
                      selected ==
                              'notRated'
                          ? Colors
                              .white
                          : Colors
                              .white54,
                  size: 21,
                ),

                const SizedBox(
                  width: 10,
                ),

                Text(
                  'Sort by Not Rated',
                  style:
                      TextStyle(
                    color:
                        selected ==
                                'notRated'
                            ? Colors
                                .white
                            : Colors
                                .white70,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    ),
  );
}

@override
void initState() {
  super.initState();

  unawaited(
    _loadWatchingRecency(),
  );

  filter =
      widget.initialFilter;

  selectedMediaType =
      widget.initialMediaType;

      if (widget.initialSortMode !=
    null) {
  _sortModeByList[
          _currentSortKey] =
      widget.initialSortMode!;
}

  mediaUserDataService
      .loadFavorites();

  unawaited(
    CriticService.instance
        .refresh(),
  );
}

void _scrollFilterIntoView(
  int index,
) {
  WidgetsBinding.instance
      .addPostFrameCallback((_) {
    if (!_filterScrollController
        .hasClients) {
      return;
    }

    const horizontalPadding = 20.0;

    final itemLeft =
        horizontalPadding +
        index *
            (_filterTabWidth +
                _filterGap);

    final itemRight =
        itemLeft +
        _filterTabWidth;

    final position =
        _filterScrollController
            .position;

    final currentOffset =
        position.pixels;

    final viewportWidth =
        position.viewportDimension;

    const edgePadding = 12.0;

    double target =
        currentOffset;

    // Selected tab is cut off
    // on the right.
    if (itemRight >
        currentOffset +
            viewportWidth -
            edgePadding) {
      target =
          itemRight -
          viewportWidth +
          edgePadding;
    }

    // Selected tab is cut off
    // on the left.
    if (itemLeft <
        currentOffset +
            edgePadding) {
      target =
          itemLeft -
          edgePadding;
    }

    target = target.clamp(
      0.0,
      position.maxScrollExtent,
    );

    _filterScrollController
        .animateTo(
      target,
      duration:
          const Duration(
        milliseconds: 320,
      ),
      curve:
          Curves.easeInOutCubic,
    );
  });
}

@override
void didUpdateWidget(
  covariant LibraryPage oldWidget,
) {
  super.didUpdateWidget(
    oldWidget,
  );

  if (oldWidget.openRequest !=
          widget.openRequest ||
      oldWidget.initialFilter !=
          widget.initialFilter ||
      oldWidget.initialMediaType !=
          widget.initialMediaType ||
      oldWidget.initialSortMode !=
          widget.initialSortMode) {
    setState(() {
      filter =
          widget.initialFilter;

      selectedMediaType =
          widget.initialMediaType;

      if (widget.initialSortMode !=
          null) {
        _sortModeByList[
                _currentSortKey] =
            widget.initialSortMode!;
      }
    });
  }
}

  Widget _mediaTypeSelector() {
  return Container(
    height: 54,
    margin: const EdgeInsets.fromLTRB(
      20,
      8,
      20,
      6,
    ),
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: chipluxSurface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth =
            (constraints.maxWidth - 10) / 2;

        final movieSelected =
            selectedMediaType == 'movie';

        return Stack(
          children: [
            AnimatedPositioned(
              duration:
                  const Duration(
                milliseconds: 250,
              ),
              curve:
                  Curves.easeInOutCubic,
              left: movieSelected
                  ? tabWidth
                  : 0,
              top: 0,
              bottom: 0,
              width: tabWidth,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      chipluxSurfaceLight,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                        chipluxViolet
                            .withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    onTap: () {
                      setState(() {
                        selectedMediaType =
                            'tv';
                      });
                    },
                    child: Center(
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 6,
                        ),
                        child: FittedBox(
                          fit:
                              BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              Icon(
                                Icons
                                    .tv_outlined,
                                size: 19,
                                color:
                                    selectedMediaType ==
                                            'tv'
                                        ? chipluxCyan
                                        : Colors
                                            .white38,
                              ),
                              const SizedBox(
                                width: 7,
                              ),
                              Text(
                                'TV Shows',
                                maxLines: 1,
                                style:
                                    TextStyle(
                                  fontSize:
                                      15,
                                  fontWeight:
                                      selectedMediaType ==
                                              'tv'
                                          ? FontWeight
                                              .bold
                                          : FontWeight
                                              .w500,
                                  color:
                                      selectedMediaType ==
                                              'tv'
                                          ? Colors
                                              .white
                                          : Colors
                                              .white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    onTap: () {
                      setState(() {
                        selectedMediaType =
                            'movie';
                      });
                    },
                    child: Center(
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 6,
                        ),
                        child: FittedBox(
                          fit:
                              BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              Icon(
                                Icons
                                    .movie_outlined,
                                size: 19,
                                color:
                                    selectedMediaType ==
                                            'movie'
                                        ? chipluxPurple
                                        : Colors
                                            .white38,
                              ),
                              const SizedBox(
                                width: 7,
                              ),
                              Text(
                                'Movies',
                                maxLines: 1,
                                style:
                                    TextStyle(
                                  fontSize:
                                      15,
                                  fontWeight:
                                      selectedMediaType ==
                                              'movie'
                                          ? FontWeight
                                              .bold
                                          : FontWeight
                                              .w500,
                                  color:
                                      selectedMediaType ==
                                              'movie'
                                          ? Colors
                                              .white
                                          : Colors
                                              .white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

  @override
  Widget build(
    BuildContext context,
  ) {
    final library =
        LibraryService.instance;

    return SafeArea(
      child: AnimatedBuilder(
        animation:
    Listenable.merge([
  library,
  mediaUserDataService,
  CriticService.instance,
]),
        builder: (context, _) {
          List<LibraryItem> items =
              library.items.toList();

          final bool showMediaTypeSelector =
    filter == 'favorites' ||
    filter == 'completed' ||
    filter == 'plan' ||
    filter == 'dropped';

if (filter == 'favorites') {
  items = items.where(
    (item) {
      return mediaUserDataService
          .isFavorite(
        item.id,
        item.mediaType,
      );
    },
  ).toList();
} else {
  items = items.where(
    (item) {
      return item.status ==
          filter;
    },
  ).toList();
}

if (showMediaTypeSelector) {
  items = items.where(
    (item) {
      return item.mediaType ==
          selectedMediaType;
    },
  ).toList();
}

          _sortCurrentList(
  items,
);

          return Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Padding(
  padding:
      const EdgeInsets
          .fromLTRB(
    20,
    20,
    20,
    8,
  ),
  child: Row(
    children: [
      const BrandedTitle(
        whitePart:
            'Wa',
        gradientPart:
            'tch',
        fontSize:
            30,
      ),

      const Spacer(),

      _buildSortButton(),
    ],
  ),
),

              _buildAnimatedFilterBar(),

              if (filter == 'favorites' ||
    filter == 'completed' ||
    filter == 'plan' ||
    filter == 'dropped')
  _mediaTypeSelector(),

              Expanded(
                child:
                    items.isEmpty
                        ? const Center(
                            child: Text(
                              'Nothing here yet.',
                              style:
                                  TextStyle(
                                color: Colors
                                    .white54,
                              ),
                            ),
                          )
                        : filter ==
                                'watching'
                            ? _buildWatchingContent(
                                items,
                              )
                            : _buildNormalLibraryGrid(
                                items,
                              ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWatchingContent(
    List<LibraryItem> items,
  ) {

    final tvItems =
        items
            .where(
              (item) =>
                  item.mediaType ==
                  'tv',
            )
            .toList();

            tvItems.sort(
  (a, b) {
    final aTime =
        _watchingRecency[
                a.id] ??
            a.addedAt;

    final bTime =
        _watchingRecency[
                b.id] ??
            b.addedAt;

    return bTime.compareTo(
      aTime,
    );
  },
);

    final movieItems =
        items
            .where(
              (item) =>
                  item.mediaType ==
                  'movie',
            )
            .toList();

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        30,
      ),
      children: [
        ...tvItems.map(
          (item) =>
              Padding(
            padding:
                const EdgeInsets
                    .only(
              bottom: 12,
            ),
            child:
    _WatchingTvCard(
  key: ValueKey(
    'watching-${item.id}',
  ),
  item: item,
  onMarkedWatched: () {
    unawaited(
      _markWatchingShowRecent(
        item.id,
      ),
    );
  },
),
          ),
        ),

        if (movieItems
            .isNotEmpty) ...[
          const SizedBox(
              height: 8),

          LayoutBuilder(
            builder:
                (context,
                    constraints) {
              int columns = 2;

              final textScale =
    MediaQuery.textScalerOf(
  context,
).scale(1.0);

final scaleExtra =
    (textScale - 1.0)
        .clamp(
  0.0,
  0.5,
);

final cardAspectRatio =
    0.58 -
        (scaleExtra * 0.08);

              if (constraints
                      .maxWidth >
                  900) {
                columns = 6;
              } else if (constraints
                      .maxWidth >
                  650) {
                columns = 4;
              } else if (constraints
                      .maxWidth >
                  450) {
                columns = 3;
              }

              return GridView
                  .builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      columns,
                  crossAxisSpacing:
                      14,
                  mainAxisSpacing:
                      18,
                  childAspectRatio:
    cardAspectRatio,
                ),
                itemCount:
                    movieItems
                        .length,
                itemBuilder:
                    (context,
                        index) {
                  final item =
                      movieItems[
                          index];

                  return _LibraryPosterCard(
                    item: item,
                    onMenu: () {
                      _showItemMenu(
                        context,
                        item,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

 Widget _buildNormalLibraryGrid(
  List<LibraryItem> items,
) {
  return ListView.separated(
    padding:
        const EdgeInsets.fromLTRB(
      20,
      16,
      20,
      30,
    ),
    itemCount:
        items.length,
    separatorBuilder:
        (_, _) =>
            const SizedBox(
      height: 9,
    ),
    itemBuilder:
        (context, index) {
      final item =
          items[index];

      return _LibraryListCard(
  item: item,
  showRatingInfo: true,
);
    },
  );
}


  static const double _filterTabWidth = 140;
static const double _filterTabHeight = 46;
static const double _filterGap = 4;

Color _filterAccent(
  String value,
) {
  switch (value) {
    case 'watching':
      return chipluxCyan;

    case 'favorites':
      return const Color(
        0xFFFFB84D,
      );

    case 'completed':
      return const Color(
        0xFF7BE8A8,
      );

    case 'plan':
      return chipluxPurple;

    case 'dropped':
      return const Color(
        0xFFFF6B6B,
      );

    default:
      return chipluxCyan;
  }
}

Color _filterBackground(
  String value,
) {
  switch (value) {
    case 'watching':
      return const Color(
        0xFF173A50,
      );

    case 'favorites':
      return const Color(
        0xFF3A2A17,
      );

    case 'completed':
      return const Color(
        0xFF173A29,
      );

    case 'plan':
      return const Color(
        0xFF3A2047,
      );

    case 'dropped':
      return const Color(
        0xFF3A1C22,
      );

    default:
      return chipluxSurfaceLight;
  }
}

IconData _filterIcon(
  String value,
) {
  switch (value) {
    case 'watching':
      return Icons.visibility_outlined;

    case 'favorites':
      return Icons.favorite;

    case 'completed':
      return Icons.emoji_events_outlined;

    case 'plan':
      return Icons.calendar_month_outlined;

    case 'dropped':
      return Icons.delete_outline;

    default:
      return Icons.circle_outlined;
  }
}

String _filterLabel(
  String value,
) {
  switch (value) {
    case 'watching':
      return 'Watching';

    case 'favorites':
      return 'Favorites';

    case 'completed':
      return 'Completed';

    case 'plan':
      return 'Plan';

    case 'dropped':
      return 'Dropped';

    default:
      return value;
  }
}

Widget _buildAnimatedFilterBar() {
  const filters = [
    'watching',
    'favorites',
    'completed',
    'plan',
    'dropped',
  ];

  final rawIndex =
      filters.indexOf(filter);

  final selectedIndex =
      rawIndex < 0 ? 0 : rawIndex;

  final selectedAccent =
      _filterAccent(
    filters[selectedIndex],
  );

  final selectedBackground =
      _filterBackground(
    filters[selectedIndex],
  );

  final totalWidth =
      (_filterTabWidth *
              filters.length) +
          (_filterGap *
              (filters.length - 1)) +
          8;

  return SizedBox(
    height: 58,
    child: SingleChildScrollView(
      controller:
    _filterScrollController,
      scrollDirection:
          Axis.horizontal,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Container(
        width: totalWidth,
        height: 54,
        padding:
            const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: chipluxSurface,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: Stack(
          children: [
            // MOVING HIGHLIGHT
            AnimatedPositioned(
              duration:
                  const Duration(
                milliseconds: 320,
              ),
              curve:
                  Curves.easeInOutCubic,
              left:
                  selectedIndex *
                      (_filterTabWidth +
                          _filterGap),
              top: 0,
              bottom: 0,
              width:
                  _filterTabWidth,
              child:
                  AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 280,
                ),
                curve:
                    Curves.easeInOut,
                decoration:
                    BoxDecoration(
                  color:
                      selectedBackground,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  border:
                      Border.all(
                    color:
                        selectedAccent
                            .withValues(
                      alpha: 0.65,
                    ),
                    width: 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          selectedAccent
                              .withValues(
                        alpha: 0.12,
                      ),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),

            // BUTTONS
            Row(
              children: [
                for (int i = 0;
                    i <
                        filters.length;
                    i++) ...[
                  SizedBox(
                    width:
                        _filterTabWidth,
                    height:
                        _filterTabHeight,
                    child: InkWell(
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                      onTap: () {
  setState(() {
    filter =
        filters[i];
  });

  _scrollFilterIntoView(
    i,
  );
},
                      child: Center(
  child: Padding(
    padding:
        const EdgeInsets.symmetric(
      horizontal: 6,
    ),
    child: FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
                            Icon(
                              _filterIcon(
                                filters[
                                    i],
                              ),
                              size: 18,
                              color:
                                  filter ==
                                          filters[
                                              i]
                                      ? _filterAccent(
                                          filters[
                                              i],
                                        )
                                      : Colors
                                          .white60,
                            ),

                            const SizedBox(
                              width: 7,
                            ),

                            Text(
                              _filterLabel(
                                filters[
                                    i],
                              ),
                              style:
                                  TextStyle(
                                fontSize:
                                    15,
                                fontWeight:
                                    filter ==
                                            filters[
                                                i]
                                        ? FontWeight
                                            .bold
                                        : FontWeight
                                            .w500,
                                color:
                                    filter ==
                                            filters[
                                                i]
                                        ? _filterAccent(
                                            filters[
                                                i],
                                          )
                                        : Colors
                                            .white70,
                              ),
                            ),
                                ],
      ),
    ),
  ),
),
                    ),
                  ),

                  if (i !=
                      filters.length -
                          1)
                    const SizedBox(
                      width:
                          _filterGap,
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showItemMenu(
    BuildContext context,
    LibraryItem item,
  ) {
    final library =
        LibraryService.instance;

    showModalBottomSheet(
      context: context,
      backgroundColor:
          chipluxSurface,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              _statusMenuItem(
                context,
                item,
                'watching',
                'Watching',
                Icons
                    .play_circle_outline,
              ),
              _statusMenuItem(
                context,
                item,
                'completed',
                'Completed',
                Icons
                    .check_circle_outline,
              ),
              _statusMenuItem(
                context,
                item,
                'plan',
                'Plan to Watch',
                Icons
                    .bookmark_border,
              ),
              _statusMenuItem(
                context,
                item,
                'dropped',
                'Dropped',
                Icons.close,
              ),

              const Divider(),

              ListTile(
                leading:
                    const Icon(
                  Icons
                      .delete_outline,
                  color: Colors
                      .redAccent,
                ),
                title:
                    const Text(
                  'Remove from Watch',
                  style:
                      TextStyle(
                    color: Colors
                        .redAccent,
                  ),
                ),
                onTap: () async {
  Navigator.pop(
    context,
  );

  await library.remove(
    item.id,
    item.mediaType,
  );

  await CriticService.instance
      .clearAllRatingsForRemovedMedia(
    tmdbId:
        item.id,
    mediaType:
        item.mediaType,
  );

  try {
    await CommunityService.instance
        .deleteActivity(
      activityType:
          'rated',
      mediaType:
          item.mediaType,
      tmdbId:
          item.id,
    );
  } catch (e) {
    debugPrint(
      'Could not remove rating activities: $e',
    );
  }
},
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusMenuItem(
    BuildContext context,
    LibraryItem item,
    String status,
    String label,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () async {
  final library =
      LibraryService.instance;

  final pageContext =
      this.context;

  final bool wasCompleted =
      item.status ==
          'completed';

  final int previousMovieCount =
      library.moviesWatchedCount;

  await library.updateStatus(
    item.id,
    item.mediaType,
    status,
  );

  if (item.mediaType == 'movie' &&
    wasCompleted &&
    status != 'completed') {
  await CriticService.instance
      .clearAllRatingsForRemovedMedia(
    tmdbId:
        item.id,
    mediaType:
        'movie',
  );

  try {
    await CommunityService.instance
        .deleteActivity(
      activityType:
          'rated',
      mediaType:
          'movie',
      tmdbId:
          item.id,
      titleLevelOnly:
          true,
    );
  } catch (e) {
    debugPrint(
      'Could not remove movie rating activity: $e',
    );
  }
}

  if (context.mounted) {
    Navigator.pop(
      context,
    );
  }

  if (status ==
          'completed' &&
      !wasCompleted &&
      item.mediaType ==
          'movie') {
    await Future<void>.delayed(
      const Duration(
        milliseconds: 200,
      ),
    );

    if (!pageContext.mounted) {
      return;
    }

    showCompletionBurst(
      pageContext,
    );

    await _checkMovieAchievementUnlock(
      pageContext,
      previousCount:
          previousMovieCount,
      currentCount:
          library.moviesWatchedCount,
    );
  }
},
    );
  }
}



class _WatchingTvCard
    extends StatefulWidget {
  final LibraryItem item;

  final VoidCallback?
      onMarkedWatched;

  const _WatchingTvCard({
    super.key,
    required this.item,
    this.onMarkedWatched,
  });

  @override
  State<_WatchingTvCard> createState() =>
      _WatchingTvCardState();
}

class _WatchingTvCardState
    extends State<_WatchingTvCard> {
      static const String _nextEpisodeCacheKey =
    'chiplux_next_episode_cache_v1';

static final Map<int, Map<String, dynamic>>
    _nextEpisodeCache = {};

static Future<void>? _cacheLoadFuture;
  final TmdbService tmdbService =
      TmdbService();

  final LibraryService library =
      LibraryService.instance;

  bool loading = true;

double _swipeProgress = 0.0;

int? seasonNumber;
int? episodeNumber;

  String episodeName = '';
  int? runtime;
  double? episodeRating;

Future<void> _ensureCacheLoaded() {
  _cacheLoadFuture ??=
      _loadCacheFromDisk();

  return _cacheLoadFuture!;
}

Future<void> _loadCacheFromDisk() async {
  try {
    final prefs =
        await SharedPreferences
            .getInstance();

    final raw =
        prefs.getString(
      _nextEpisodeCacheKey,
    );

    if (raw == null ||
        raw.isEmpty) {
      return;
    }

    final decoded =
        jsonDecode(raw);

    if (decoded is! Map) {
      return;
    }

    for (final entry
        in decoded.entries) {
      final showId =
          int.tryParse(
        entry.key.toString(),
      );

      if (showId == null ||
          entry.value is! Map) {
        continue;
      }

      _nextEpisodeCache[
              showId] =
          Map<String, dynamic>.from(
        entry.value,
      );
    }
  } catch (e) {
    debugPrint(
      'Could not load next episode cache: $e',
    );
  }
}

Future<void> _saveCacheToDisk() async {
  try {
    final prefs =
        await SharedPreferences
            .getInstance();

    final data =
        <String, dynamic>{};

    for (final entry
        in _nextEpisodeCache.entries) {
      data[
          entry.key.toString()] =
          entry.value;
    }

    await prefs.setString(
      _nextEpisodeCacheKey,
      jsonEncode(data),
    );
  } catch (e) {
    debugPrint(
      'Could not save next episode cache: $e',
    );
  }
}
void _applyCachedEpisode(
  Map<String, dynamic> cached,
) {
  final cachedRating =
      cached['episodeRating'];

  setState(() {
    seasonNumber =
        cached['seasonNumber']
            as int?;

    episodeNumber =
        cached['episodeNumber']
            as int?;

    episodeName =
        cached['episodeName']
                ?.toString() ??
            '';

    runtime =
        cached['runtime']
            as int?;

    episodeRating =
        cachedRating is num
            ? cachedRating
                .toDouble()
            : null;

    loading = false;
  });
}

  @override
void initState() {
  super.initState();

  _loadCachedThenRefresh();
}

Future<void>
    _loadCachedThenRefresh() async {
  await _ensureCacheLoaded();

  if (!mounted) return;

  final cached =
      _nextEpisodeCache[
          widget.item.id];

  final currentWatched =
      library.watchedCountForShow(
    widget.item.id,
  );

  bool validCache = false;
  bool cacheIsOld = true;

  if (cached != null &&
      cached['watchedCount'] ==
          currentWatched) {
    validCache = true;

    _applyCachedEpisode(
      cached,
    );

    final updatedAt =
        cached['updatedAt'];

    if (updatedAt is num) {
      final age =
          DateTime.now()
              .millisecondsSinceEpoch -
              updatedAt.toInt();

      cacheIsOld =
          age >
              const Duration(
                minutes: 15,
              ).inMilliseconds;
    }
  }

  // No usable cached information:
  // load normally.
  if (!validCache) {
    await _loadNextEpisode(
      forceRefresh: true,
      showLoader: true,
    );

    return;
  }

  // We already displayed the cache.
  // Only refresh TMDB in the background
  // if the cache is old.
  if (cacheIsOld) {
    unawaited(
      _loadNextEpisode(
        forceRefresh: true,
        showLoader: false,
      ),
    );
  }
}

  Future<void> _loadNextEpisode({
  bool forceRefresh = false,
  bool showLoader = true,
}) async {
  final int currentWatchedCount =
      library.watchedCountForShow(
    widget.item.id,
  );

  // Use the already calculated result immediately.
  final cached =
      _nextEpisodeCache[
          widget.item.id];

  if (!forceRefresh &&
      cached != null &&
      cached['watchedCount'] ==
          currentWatchedCount) {
    if (!mounted) return;

    setState(() {
      seasonNumber =
          cached['seasonNumber']
              as int?;

      episodeNumber =
          cached['episodeNumber']
              as int?;

      episodeName =
          cached['episodeName']
                  ?.toString() ??
              '';

      runtime =
          cached['runtime']
              as int?;

      final cachedRating =
          cached['episodeRating'];

      episodeRating =
          cachedRating is num
              ? cachedRating
                  .toDouble()
              : null;

      loading = false;
    });

    return;
  }

  if (showLoader && mounted) {
  setState(() {
    loading = true;
  });
}

  try {
    final details =
        await tmdbService.getDetails(
      widget.item.id,
      'tv',
    );

    final List<dynamic> seasons =
        details['seasons'] ?? [];

    final validSeasons =
        seasons.where(
      (season) {
        final number =
            season[
                'season_number'];

        return number is num &&
            number.toInt() > 0;
      },
    ).toList();

    validSeasons.sort(
      (a, b) {
        final aNumber =
            (a['season_number']
                    as num)
                .toInt();

        final bNumber =
            (b['season_number']
                    as num)
                .toInt();

        return aNumber.compareTo(
          bNumber,
        );
      },
    );

    Map<String, dynamic>?
        nextEpisode;

    int? foundSeason;

    for (final season
        in validSeasons) {
      final int seasonNo =
          (season[
                  'season_number']
              as num)
              .toInt();

      final int episodeCount =
          season['episode_count']
                  is num
              ? (season[
                          'episode_count']
                      as num)
                  .toInt()
              : 0;

      final int watchedInSeason =
          library
              .watchedCountForSeason(
        widget.item.id,
        seasonNo,
      );

      // IMPORTANT:
      // We already know this whole
      // season is watched, so there is
      // no reason to download it from
      // TMDB.
      if (episodeCount > 0 &&
          watchedInSeason >=
              episodeCount) {
        continue;
      }

      // Only download the first
      // incomplete season.
      final episodes =
          await tmdbService
              .getSeasonEpisodes(
        widget.item.id,
        seasonNo,
      );

      for (final rawEpisode
          in episodes) {
        final episode =
            Map<String, dynamic>.from(
          rawEpisode,
        );

        final rawEpisodeNumber =
            episode[
                'episode_number'];

        if (rawEpisodeNumber
            is! num) {
          continue;
        }

        final int episodeNo =
            rawEpisodeNumber
                .toInt();

        final watched =
            library
                .isEpisodeWatched(
          widget.item.id,
          seasonNo,
          episodeNo,
        );

        if (!watched) {
          nextEpisode =
              episode;

          foundSeason =
              seasonNo;

          break;
        }
      }

      if (nextEpisode != null) {
        break;
      }
    }

    if (!mounted) return;

    if (nextEpisode == null) {
      _nextEpisodeCache[
    widget.item.id] = {
  'watchedCount':
      library
          .watchedCountForShow(
    widget.item.id,
  ),

  'seasonNumber': null,
  'episodeNumber': null,

  'episodeName':
      'All episodes watched',

  'runtime': null,
  'episodeRating': null,

  'updatedAt':
      DateTime.now()
          .millisecondsSinceEpoch,
};

unawaited(
  _saveCacheToDisk(),
);

      setState(() {
        seasonNumber = null;
        episodeNumber = null;
        episodeName =
            'All episodes watched';
        runtime = null;
        episodeRating = null;
        loading = false;
      });

      return;
    }

    final rawRuntime =
        nextEpisode['runtime'];

    final rawRating =
        nextEpisode[
            'vote_average'];

    final int? newRuntime =
        rawRuntime is num
            ? rawRuntime.toInt()
            : null;

    final double?
        newEpisodeRating =
        rawRating is num &&
                rawRating.toDouble() >
                    0
            ? rawRating.toDouble()
            : null;

    final int newEpisodeNumber =
        (nextEpisode[
                    'episode_number']
                as num)
            .toInt();

    _nextEpisodeCache[
        widget.item.id] = {
      'watchedCount':
          library
              .watchedCountForShow(
        widget.item.id,
      ),
      'seasonNumber':
          foundSeason,
      'episodeNumber':
          newEpisodeNumber,
      'episodeName':
          nextEpisode['name'] ??
              'Episode',
      'runtime':
          newRuntime,
      'episodeRating':
          newEpisodeRating,
'updatedAt':
      DateTime.now()
          .millisecondsSinceEpoch,
    };

    unawaited(
  _saveCacheToDisk(),
);

    setState(() {
      seasonNumber =
          foundSeason;

      episodeNumber =
          newEpisodeNumber;

      episodeName =
          nextEpisode!['name'] ??
              'Episode';

      runtime =
          newRuntime;

      episodeRating =
          newEpisodeRating;

      loading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      loading = false;
    });

    debugPrint(
      'Could not load next episode: $e',
    );
  }
}

  Future<bool> _markWatched() async {
    if (seasonNumber == null ||
        episodeNumber == null) {
      return false;
    }

    await library.toggleEpisode(
  widget.item.id,
  seasonNumber!,
  episodeNumber!,
  runtimeMinutes:
      runtime ?? 0,
);

    if (!mounted) {
      return false;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          'S${seasonNumber!.toString().padLeft(2, '0')}'
          'E${episodeNumber!.toString().padLeft(2, '0')} marked watched',
        ),
      ),
    );

    await _loadNextEpisode(
  forceRefresh: true,
);

final onMarkedWatched =
    widget.onMarkedWatched;

// Let the Dismissible finish returning
// to its normal position first, then
// move the show to the top.
unawaited(
  Future<void>.delayed(
    const Duration(
      milliseconds: 220,
    ),
    () {
      onMarkedWatched?.call();
    },
  ),
);

return false;
  }

  Future<void>
    _openNextEpisode() async {
  final int? nextSeason =
      seasonNumber;

  final int? nextEpisode =
      episodeNumber;

  // Nothing left to watch.
  if (nextSeason == null ||
      nextEpisode == null) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MediaDetailsPage(
          id:
              widget.item.id,
          mediaType:
              'tv',
        ),
      ),
    );

    return;
  }

  try {
    final episodes =
        await tmdbService
            .getSeasonEpisodes(
      widget.item.id,
      nextSeason,
    );

    Map<String, dynamic>?
        episode;

    for (final raw
        in episodes) {
      if (raw is! Map) {
        continue;
      }

      final map =
          Map<String, dynamic>.from(
        raw,
      );

      final number =
          map['episode_number'];

      if (number is num &&
          number.toInt() ==
              nextEpisode) {
        episode =
            map;

        break;
      }
    }

    if (!mounted) {
      return;
    }

    if (episode == null) {
      return;
    }

    final rawRuntime =
        episode['runtime'];

    final rawRating =
        episode[
            'vote_average'];

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SwipeableEpisodePage(
          showId:
              widget.item.id,
          seasonNumber:
              nextSeason,
          episodeNumber:
              nextEpisode,
          title:
              episode?['name']
                      ?.toString() ??
                  episodeName,
          stillPath:
              episode?['still_path']
                  ?.toString(),
          runtime:
              rawRuntime is num
                  ? rawRuntime
                      .toInt()
                  : runtime,
          rating:
              rawRating is num
                  ? rawRating
                      .toDouble()
                  : episodeRating,
          overview:
              episode?['overview']
                      ?.toString() ??
                  '',
          airDate:
              episode?['air_date']
                  ?.toString(),
        ),
      ),
    );
  } catch (e) {
    debugPrint(
      'Could not open next episode: $e',
    );
  }

  if (!mounted) {
    return;
  }

  await _loadNextEpisode(
    forceRefresh:
        true,
  );
}

  @override
  Widget build(BuildContext context) {
    final posterUrl =
        widget.item.posterPath != null
            ? 'https://image.tmdb.org/t/p/w342${widget.item.posterPath}'
            : null;

    final watched =
        library.watchedCountForShow(
      widget.item.id,
    );

    final total =
        widget.item.totalEpisodes;

    final progress =
        total <= 0
            ? 0.0
            : (watched / total)
                .clamp(0.0, 1.0);

    final completionPercent =
    total <= 0
        ? 0
        : ((watched / total) * 100).round();

    final episodeCode =
        seasonNumber != null &&
                episodeNumber != null
            ? 'S${seasonNumber!.toString().padLeft(2, '0')}'
                'E${episodeNumber!.toString().padLeft(2, '0')}'
            : '';

    return Dismissible(
  key: ValueKey(
    'watching-${widget.item.id}',
  ),

  direction:
      DismissDirection.startToEnd,

  // Only about 22% of the card needs
  // to be swiped before it triggers.
  dismissThresholds: const {
    DismissDirection.startToEnd:
        0.22,
  },

  // Faster snap / return animation.
  movementDuration:
      const Duration(
    milliseconds: 140,
  ),

  onUpdate: (details) {
    setState(() {
      _swipeProgress =
          details.progress
              .clamp(
                0.0,
                1.0,
              )
              .toDouble();
    });
  },

  confirmDismiss: (_) =>
      _markWatched(),

      background: Container(
  padding:
      const EdgeInsets.all(
    1.2,
  ),

  decoration:
      BoxDecoration(
    borderRadius:
        BorderRadius.circular(
      18,
    ),

    // Chiplux gradient FRAME only.
    gradient:
        const LinearGradient(
      begin:
          Alignment.centerLeft,
      end:
          Alignment.centerRight,
      colors: [
        chipluxCyan,
        chipluxViolet,
        chipluxPurple,
      ],
    ),

    boxShadow: [
      BoxShadow(
        color:
            chipluxViolet
                .withValues(
          alpha:
              0.04 +
              (_swipeProgress *
                  0.12),
        ),
        blurRadius:
            8 +
            (_swipeProgress *
                10),
      ),
    ],
  ),

  child: Container(
    alignment:
        Alignment.centerLeft,

    padding:
        const EdgeInsets.symmetric(
      horizontal: 22,
    ),

    decoration:
        BoxDecoration(
      borderRadius:
          BorderRadius.circular(
        17,
      ),

      // Dark / restrained swipe area.
      color:
          Color.alphaBlend(
        chipluxViolet.withValues(
          alpha:
              0.025 +
              (_swipeProgress *
                  0.035),
        ),
        chipluxBackground,
      ),
    ),

    child: Transform.scale(
      alignment:
          Alignment.centerLeft,

      scale:
          0.86 +
          (_swipeProgress *
              0.14),

      child: Opacity(
        opacity:
            0.55 +
            (_swipeProgress *
                0.45),

        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback:
                  (bounds) {
                return const LinearGradient(
                  begin:
                      Alignment.topLeft,
                  end:
                      Alignment.bottomRight,
                  colors: [
                    chipluxCyan,
                    chipluxViolet,
                    chipluxPurple,
                  ],
                ).createShader(
                  bounds,
                );
              },

              child:
                  const Icon(
                Icons
                    .check_circle_outline_rounded,
                color:
                    Colors.white,
                size: 27,
              ),
            ),

            const SizedBox(
              width: 11,
            ),

            const GradientText(
              'Mark as watched',
              style:
                  TextStyle(
                fontSize: 15,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(18),

        onTap: () async {
  await _openNextEpisode();
},

        child: Container(
  constraints:
      const BoxConstraints(
    minHeight: 138,
  ),
  padding:
      const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: chipluxSurface,
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white
                  .withValues(
                    alpha: 0.06,
                  ),
            ),
          ),

          child: loading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : Row(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                                  12),
                      child:
                          posterUrl !=
                                  null
                              ? Image
                                  .network(
                                  posterUrl,
                                  width: 82,
                                  height: 118,
                                  fit: BoxFit
                                      .cover,
                                )
                              : Container(
                                  width:
                                      82,
                                  height:
                                      118,
                                  color:
                                      chipluxSurfaceLight,
                                  child:
                                      const Icon(
                                    Icons
                                        .tv_outlined,
                                  ),
                                ),
                    ),

                    const SizedBox(
                        width: 10),

                    Expanded(
  child: Column(
    mainAxisSize:
        MainAxisSize.min,
    crossAxisAlignment:
        CrossAxisAlignment.start,
    children: [
                          Row(
                            children: [
                              Expanded(
                                child:
                                    Text(
                                  widget.item
                                      .title,
                                  maxLines:
                                      1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        17,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),

                              const Icon(
                                Icons
                                    .chevron_right,
                                color: Colors
                                    .white60,
                              ),
                            ],
                          ),

                          const SizedBox(
                              height: 7),

                          Text(
                            episodeCode
                                    .isEmpty
                                ? episodeName
                                : '$episodeCode • $episodeName',
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color: Colors
                                  .white70,
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(
                              height: 10),

                          Row(
                            children: [
                              const Icon(
                                Icons
                                    .access_time_rounded,
                                size: 17,
                                color: Colors
                                    .white54,
                              ),

                              const SizedBox(
                                  width: 5),

                              Text(
                                runtime !=
                                        null
                                    ? '${runtime}m'
                                    : '--m',
                                style:
                                    const TextStyle(
                                  color: Colors
                                      .white60,
                                  fontSize:
                                      12,
                                ),
                              ),

                              const SizedBox(
                                  width: 10),

                              const Icon(
                                Icons.star,
                                size: 18,
                                color: Colors
                                    .amber,
                              ),

                              const SizedBox(
                                  width: 5),

                              Text(
                                episodeRating !=
                                        null
                                    ? '${episodeRating!.toStringAsFixed(1)}/10'
                                    : '--/10',
                                style:
                                    const TextStyle(
                                  color: Colors
                                      .white60,
                                  fontSize:
                                      13,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
  height: 10,
),

                          Row(
                            children: [
                              Expanded(
                                child:
                                    ClipRRect(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              20),
                                  child:
                                      LinearProgressIndicator(
                                    value:
                                        progress,
                                    minHeight:
                                        6,
                                    backgroundColor:
                                        Colors
                                            .white12,
                                    valueColor:
                                        const AlwaysStoppedAnimation<
                                            Color>(
                                      chipluxPurple,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(
                                  width: 12),

                              SizedBox(
  width: 46,
  height: 22,
  child: FittedBox(
    fit: BoxFit.scaleDown,
    alignment:
        Alignment.centerRight,
    child: Text(
      '$completionPercent%',
      maxLines: 1,
      style:
          const TextStyle(
        fontSize: 15,
        fontWeight:
            FontWeight.bold,
        color:
            Colors.white,
      ),
    ),
  ),
),
                            ],
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

class _LibraryListCard
    extends StatelessWidget {
      String _genreName(
  int genreId,
) {
  switch (genreId) {
    case 28:
      return 'Action';
    case 12:
      return 'Adventure';
    case 16:
      return 'Animation';
    case 35:
      return 'Comedy';
    case 80:
      return 'Crime';
    case 99:
      return 'Documentary';
    case 18:
      return 'Drama';
    case 10751:
      return 'Family';
    case 14:
      return 'Fantasy';
    case 36:
      return 'History';
    case 27:
      return 'Horror';
    case 10402:
      return 'Music';
    case 9648:
      return 'Mystery';
    case 10749:
      return 'Romance';
    case 878:
      return 'Science Fiction';
    case 10770:
      return 'TV Movie';
    case 53:
      return 'Thriller';
    case 10752:
      return 'War';
    case 37:
      return 'Western';

    // TV
    case 10759:
      return 'Action & Adventure';
    case 10762:
      return 'Kids';
    case 10763:
      return 'News';
    case 10764:
      return 'Reality';
    case 10765:
      return 'Sci-Fi & Fantasy';
    case 10766:
      return 'Soap';
    case 10767:
      return 'Talk';
    case 10768:
      return 'War & Politics';

    default:
      return '';
  }
}
  final LibraryItem item;
  final bool showRatingInfo;

  const _LibraryListCard({
    required this.item,
    this.showRatingInfo = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final library =
        LibraryService.instance;

    final critic =
        CriticService.instance;

    final mediaUserDataService =
        MediaUserDataService.instance;

    final bool isTv =
        item.mediaType == 'tv';
        
        final String genre =
    item.genreIds.isNotEmpty
        ? _genreName(
            item.genreIds.first,
          )
        : '';

    final bool isFavorite =
        mediaUserDataService
            .isFavorite(
      item.id,
      item.mediaType,
    );

    const Color ratedGold =
        Color(
      0xFFFFC857,
    );

    const Color favoriteRed =
        Color(
      0xFFFF5C72,
    );

    final posterUrl =
        item.posterPath != null
            ? 'https://image.tmdb.org/t/p/w185${item.posterPath}'
            : null;

    final int watched =
        isTv
            ? library
                .watchedCountForShow(
                item.id,
              )
            : 0;

    // =====================================
    // RATING INFORMATION
    // =====================================

    final int ratedEpisodes =
        isTv
            ? critic
                .ratedEpisodeCountForShow(
                item.id,
              )
            : 0;

            final int? titleRatingStars =
    critic.titleRatingStars(
  item.id,
  item.mediaType,
);

    final int totalEpisodes =
        item.totalEpisodes;

    final bool fullyRated;

    if (isTv) {
  fullyRated =
      titleRatingStars != null &&
      totalEpisodes > 0 &&
      ratedEpisodes >=
          totalEpisodes;
} else {
  fullyRated =
      critic.isMovieRated(
    item.id,
  );
}

    final int shownRatedEpisodes =
        totalEpisodes > 0
            ? ratedEpisodes.clamp(
                0,
                totalEpisodes,
              )
            : ratedEpisodes;

    final String episodeRatingText =
        totalEpisodes > 0
            ? '$shownRatedEpisodes/$totalEpisodes'
            : '$ratedEpisodes/?';

    final Color ratingColor =
        fullyRated
            ? ratedGold
            : Colors.white38;

    // =====================================
    // STATUS
    // =====================================

    String statusText;

    switch (item.status) {
      case 'completed':
        statusText =
            isTv
                ? 'Completed'
                : 'Watched';
        break;

      case 'plan':
        statusText =
            'Plan';
        break;

      case 'dropped':
        statusText =
            'Dropped';
        break;

      case 'watching':
        statusText =
            'Watching';
        break;

      default:
        statusText =
            item.status;
    }

    Color statusColor;

    switch (item.status) {
      case 'completed':
        statusColor =
            const Color(
          0xFF7BE8A8,
        );
        break;

      case 'plan':
        statusColor =
            chipluxPurple;
        break;

      case 'dropped':
        statusColor =
            const Color(
          0xFFFF6B6B,
        );
        break;

      default:
        statusColor =
            chipluxCyan;
    }

    // =====================================
    // OUTER FRAME
    // =====================================

    final bool hasSpecialFrame =
        fullyRated ||
            isFavorite;

    final Gradient frameGradient;

    if (fullyRated &&
    isFavorite) {
  // Rated + Favorite
  frameGradient =
      const LinearGradient(
    begin:
        Alignment.centerLeft,
    end:
        Alignment.centerRight,
    colors: [
      ratedGold,
      favoriteRed,
    ],
  );
} else if (fullyRated) {
  // Rated
  frameGradient =
      const LinearGradient(
    colors: [
      ratedGold,
      ratedGold,
    ],
  );
} else if (isFavorite) {
  // Favorite
  frameGradient =
      const LinearGradient(
    colors: [
      favoriteRed,
      favoriteRed,
    ],
  );
} else {
  // Normal card
  frameGradient =
      LinearGradient(
    colors: [
      Colors.white.withValues(
        alpha: 0.05,
      ),
      Colors.white.withValues(
        alpha: 0.05,
      ),
    ],
  );
}

    return Padding(
      // Room for star / heart
      // sitting on the border.
      padding:
          EdgeInsets.only(
        top:
            showRatingInfo ||
                    isFavorite
                ? 10
                : 0,
      ),
      child: Stack(
        clipBehavior:
            Clip.none,
        children: [
          // =====================================
          // OUTER FRAME
          // =====================================

          Container(
            padding:
                EdgeInsets.all(
              hasSpecialFrame
                  ? 1.4
                  : 1,
            ),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              gradient:
                  frameGradient,
              boxShadow: [
                if (fullyRated)
                  BoxShadow(
                    color:
                        ratedGold
                            .withValues(
                      alpha:
                          0.08,
                    ),
                    blurRadius:
                        12,
                  ),

                if (isFavorite)
                  BoxShadow(
                    color:
                        favoriteRed
                            .withValues(
                      alpha:
                          0.07,
                    ),
                    blurRadius:
                        12,
                  ),           
              ],
            ),

            // =====================================
            // ACTUAL CARD
            // =====================================

            child: Material(
              color:
                  Colors.transparent,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              clipBehavior:
                  Clip.antiAlias,
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MediaDetailsPage(
                        id: item.id,
                        mediaType:
                            item.mediaType,
                      ),
                    ),
                  );
                },
                child: Container(
  constraints:
      const BoxConstraints(
    minHeight: 96,
  ),
  padding:
      const EdgeInsets.all(
    8,
  ),
                  decoration:
                      BoxDecoration(
                    color:
                        chipluxSurface,
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child: Row(
                    children: [
                      // =========================
                      // POSTER
                      // =========================

                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                        child:
                            posterUrl !=
                                    null
                                ? Image.network(
                                    posterUrl,
                                    width:
                                        54,
                                    height:
                                        80,
                                    fit:
                                        BoxFit
                                            .cover,
                                  )
                                : Container(
                                    width:
                                        54,
                                    height:
                                        80,
                                    color:
                                        chipluxSurfaceLight,
                                    child:
                                        const Icon(
                                      Icons
                                          .movie_outlined,
                                      size:
                                          20,
                                    ),
                                  ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      // =========================
                      // TITLE + INFO
                      // =========================

                      Expanded(
  child: Column(
    mainAxisSize:
        MainAxisSize.min,
    crossAxisAlignment:
        CrossAxisAlignment.start,
    children: [
                            Text(
                              item.title,
                              maxLines:
                                  1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                fontSize:
                                    15,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            Text(
  isTv
      ? [
          '$watched / ${item.totalEpisodes} episodes',
          if (genre.isNotEmpty)
            genre,
        ].join(' • ')
      : [
          if (item.year.isNotEmpty)
            item.year,
          if (genre.isNotEmpty)
            genre,
        ].join(' • '),
  maxLines: 1,
  overflow:
      TextOverflow.ellipsis,
  style:
      const TextStyle(
    color:
        Colors.white54,
    fontSize: 11,
  ),
),

                            const SizedBox(
                              height: 7,
                            ),

                            Wrap(
  spacing: 8,
  runSpacing: 6,
  crossAxisAlignment:
      WrapCrossAlignment.center,
  children: [
    // STATUS
                                // =================
                                // STATUS
                                // =================

                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        7,
                                    vertical:
                                        3,
                                  ),
                                  decoration:
    BoxDecoration(
  color:
      statusColor.withValues(
    alpha: 0.14,
  ),
  borderRadius:
      BorderRadius.circular(
    8,
  ),
  border:
      Border.all(
    color:
        statusColor.withValues(
      alpha: 0.55,
    ),
    width: 0.8,
  ),
),
                                  child:
                                      Text(
                                    statusText,
                                    style:
                                        TextStyle(
                                      color:
                                          statusColor,
                                      fontSize:
                                          9,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),

                                if (showRatingInfo) ...[

  // =========================
  // RATED / NOT RATED
  // =========================

  if (fullyRated)
    Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration:
          BoxDecoration(
        color:
            ratedGold.withValues(
          alpha: 0.18,
        ),
        borderRadius:
            BorderRadius.circular(
          8,
        ),
        border:
            Border.all(
          color:
              ratedGold.withValues(
            alpha: 0.55,
          ),
          width: 0.8,
        ),
      ),
      child:
          const Text(
        'Rated',
        style:
            TextStyle(
          color:
              ratedGold,
          fontSize: 9,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    )
  else
    const Text(
      'Not Rated',
      style:
          TextStyle(
        color:
            Colors.white38,
        fontSize: 9,
        fontWeight:
            FontWeight.bold,
      ),
    ),

  // =========================
  // EPISODE RATING COUNT
  // TV ONLY
  // =========================

  if (isTv) ...[
    const SizedBox(
      width: 7,
    ),

    Text(
      episodeRatingText,
      style:
          TextStyle(
        color:
            ratingColor,
        fontSize: 9,
        fontWeight:
            fullyRated
                ? FontWeight.bold
                : FontWeight.w500,
      ),
    ),
  ],

  // =========================
  // FAVORITE - LAST
  // =========================

  if (isFavorite) ...[
    const SizedBox(
      width: 7,
    ),

    Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration:
          BoxDecoration(
        color:
            favoriteRed.withValues(
          alpha: 0.16,
        ),
        borderRadius:
            BorderRadius.circular(
          8,
        ),
        border:
            Border.all(
          color:
              favoriteRed.withValues(
            alpha: 0.50,
          ),
          width: 0.8,
        ),
      ),
      child:
          const Text(
        'Favorite',
        style:
            TextStyle(
          color:
              favoriteRed,
          fontSize: 9,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    ),
  ],
],
                              ],
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

// =====================================
// RATING BADGE - LEFT
// =====================================

if (showRatingInfo)
  Positioned(
    top: -11,
    left: 18,
    child: Container(
      height: 27,
      padding:
          EdgeInsets.symmetric(
        horizontal:
            fullyRated &&
                    titleRatingStars !=
                        null
                ? 8
                : 4,
      ),
      decoration:
          BoxDecoration(
        color:
            chipluxSurface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              fullyRated
                  ? ratedGold
                  : Colors.white24,
          width:
              1.4,
        ),
        boxShadow: [
          if (fullyRated)
            BoxShadow(
              color:
                  ratedGold
                      .withValues(
                alpha: 0.20,
              ),
              blurRadius:
                  8,
            ),
        ],
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 17,
            color:
                fullyRated
                    ? ratedGold
                    : Colors.white38,
          ),

          // Only show the actual
          // score once the WHOLE
          // TV rating is complete.
          if (fullyRated &&
              titleRatingStars !=
                  null) ...[
            const SizedBox(
              width: 3,
            ),

            Text(
              '$titleRatingStars',
              style:
                  const TextStyle(
                color:
                    ratedGold,
                fontSize: 12,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    ),
  ),

          // =====================================
          // FAVORITE HEART - RIGHT
          // =====================================

          if (isFavorite)
            Positioned(
              top: -11,
              right: 18,
              child: Container(
                width: 27,
                height: 27,
                decoration:
                    BoxDecoration(
                  color:
                      chipluxSurface,
                  shape:
                      BoxShape.circle,
                  border:
                      Border.all(
                    color:
                        favoriteRed,
                    width:
                        1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          favoriteRed
                              .withValues(
                        alpha:
                            0.22,
                      ),
                      blurRadius:
                          8,
                    ),
                  ],
                ),
                child:
                    const Icon(
                  Icons
                      .favorite_rounded,
                  size: 16,
                  color:
                      favoriteRed,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LibraryPosterCard
    extends StatelessWidget {
  final LibraryItem item;
  final VoidCallback onMenu;

  const _LibraryPosterCard({
    required this.item,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final library =
        LibraryService.instance;

    final posterUrl =
        item.posterPath != null
            ? 'https://image.tmdb.org/t/p/w342${item.posterPath}'
            : null;

    final watched =
        item.mediaType == 'tv'
            ? library
                .watchedCountForShow(
                    item.id)
            : 0;

    return InkWell(
      borderRadius:
          BorderRadius.circular(16),
      onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          MediaDetailsPage(
        id: item.id,
        mediaType: item.mediaType,
      ),
    ),
  );
},
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius
                          .circular(16),
                  child: posterUrl != null
                      ? Image.network(
                          posterUrl,
                          fit:
                              BoxFit.cover,
                        )
                      : Container(
                          color:
                              chipluxSurface,
                          child:
                              const Icon(
                            Icons
                                .movie_outlined,
                          ),
                        ),
                ),

                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.black54,
                      borderRadius:
                          BorderRadius
                              .circular(20),
                    ),
                    child:
                        IconButton(
                      constraints:
                          const BoxConstraints(
                        minWidth: 35,
                        minHeight: 35,
                      ),
                      padding:
                          EdgeInsets.zero,
                      icon:
                          const Icon(
                        Icons
                            .more_vert,
                        size: 20,
                      ),
                      onPressed:
                          onMenu,
                    ),
                  ),
                ),

                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.black87,
                      borderRadius:
                          BorderRadius
                              .circular(10),
                    ),
                    child: Text(
                      _statusLabel(
                          item.status),
                      style:
                          const TextStyle(
                        fontSize: 10,
                        color:
                            chipluxCyan,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            item.title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            item.mediaType == 'tv'
                ? '$watched / ${item.totalEpisodes} episodes'
                : item.year,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreRuntimeStat {
  final String genre;
  final int titleCount;
  final int watchedMinutes;
  final double percentage;

  const _GenreRuntimeStat({
    required this.genre,
    required this.titleCount,
    required this.watchedMinutes,
    required this.percentage,
  });
}

Future<void>
    _showProfileBannerPicker(
  BuildContext context,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor:
        chipluxSurface,
    shape:
        const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(
        top:
            Radius.circular(
          24,
        ),
      ),
    ),
    builder: (context) {
      return const _BannerPickerSheet();
    },
  );
}

class _BannerPickerSheet
    extends StatelessWidget {
  const _BannerPickerSheet();

  @override
  Widget build(
    BuildContext context,
  ) {
    final library =
        LibraryService.instance;

    final profile =
        ProfileService.instance;

    final completed =
        library.items.where(
      (item) {
        return item.status ==
                'completed' &&
            (item.mediaType ==
                    'movie' ||
                item.mediaType ==
                    'tv');
      },
    ).toList();

    completed.sort(
      (a, b) =>
          b.addedAt.compareTo(
        a.addedAt,
      ),
    );

    return SafeArea(
      top: false,
      child: SizedBox(
        height:
            MediaQuery.sizeOf(
                  context,
                ).height *
                0.78,
        child: Column(
          children: [
            const SizedBox(
              height: 12,
            ),

            Container(
              width: 42,
              height: 4,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white24,
                borderRadius:
                    BorderRadius.circular(
                  50,
                ),
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 20,
              ),
              child: Row(
                children: [
                  const Text(
                    'Choose Banner',
                    style:
                        TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const Spacer(),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon:
                        const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding:
                  EdgeInsets
                      .fromLTRB(
                20,
                0,
                20,
                16,
              ),
              child: Align(
                alignment:
                    Alignment
                        .centerLeft,
                child: Text(
                  'Backdrops from movies and TV shows you completed.',
                  style:
                      TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            if (profile.bannerPath !=
                    null &&
                profile.bannerPath!
                    .isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  20,
                  0,
                  20,
                  14,
                ),
                child: InkWell(
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  onTap:
                      () async {
                    await profile
                        .removeBanner();

                    if (context
                        .mounted) {
                      Navigator.pop(
                        context,
                      );
                    }
                  },
                  child: Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          chipluxSurfaceLight,
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child:
                        const Row(
                      children: [
                        Icon(
                          Icons
                              .hide_image_outlined,
                          color:
                              Colors
                                  .white70,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Remove banner',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Expanded(
              child:
                  completed.isEmpty
                      ? const Center(
                          child:
                              Padding(
                            padding:
                                EdgeInsets
                                    .all(
                              30,
                            ),
                            child: Text(
                              'Complete a movie or TV show to unlock profile banners.',
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  TextStyle(
                                color:
                                    Colors
                                        .white54,
                              ),
                            ),
                          ),
                        )
                      : LayoutBuilder(
    builder:
        (
      context,
      constraints,
    ) {
      final int columns;

      if (constraints.maxWidth <
          360) {
        columns = 1;
      } else if (
          constraints.maxWidth >=
              750) {
        columns = 3;
      } else {
        columns = 2;
      }

      return GridView.builder(
        padding:
            const EdgeInsets
                .fromLTRB(
          20,
          0,
          20,
          24,
        ),

        gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:
              columns,

          crossAxisSpacing:
              12,

          mainAxisSpacing:
              12,

          childAspectRatio:
              1.65,
        ),

        itemCount:
            completed.length,

        itemBuilder:
            (
          context,
          index,
        ) {
          return _BannerOptionTile(
            item:
                completed[index],
          );
        },
      );
    },
  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerOptionTile
    extends StatefulWidget {
  final LibraryItem item;

  const _BannerOptionTile({
    required this.item,
  });

  @override
  State<_BannerOptionTile>
      createState() =>
          _BannerOptionTileState();
}

class _BannerOptionTileState
    extends State<
        _BannerOptionTile> {
  late final Future<
          Map<String, dynamic>>
      _detailsFuture;

  @override
  void initState() {
    super.initState();

    _detailsFuture =
        TmdbService()
            .getDetails(
      widget.item.id,
      widget.item.mediaType,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder<
        Map<String, dynamic>>(
      future:
          _detailsFuture,
      builder:
          (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            decoration:
                BoxDecoration(
              color:
                  chipluxSurfaceLight,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child:
                const Center(
              child:
                  SizedBox(
                width: 22,
                height: 22,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final details =
            snapshot.data!;

        final path =
            details[
                    'backdrop_path']
                ?.toString();

        final hasBackdrop =
            path != null &&
                path.isNotEmpty;

        final url =
            hasBackdrop
                ? 'https://image.tmdb.org/t/p/w780$path'
                : null;

        return InkWell(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          onTap:
              !hasBackdrop
                  ? null
                  : () async {
                      await ProfileService
                          .instance
                          .updateBanner(
                        tmdbId:
                            widget
                                .item
                                .id,
                        mediaType:
                            widget
                                .item
                                .mediaType,
                        bannerPath:
                            path,
                      );

                      if (context
                          .mounted) {
                        Navigator.pop(
                          context,
                        );
                      }
                    },
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            child: Stack(
              fit:
                  StackFit.expand,
              children: [
                if (url !=
                    null)
                  Image.network(
                    url,
                    fit:
                        BoxFit.cover,
                  )
                else
                  Container(
                    color:
                        chipluxSurfaceLight,
                    alignment:
                        Alignment
                            .center,
                    child:
                        const Text(
                      'No backdrop',
                      style:
                          TextStyle(
                        color:
                            Colors
                                .white38,
                        fontSize:
                            12,
                      ),
                    ),
                  ),

                DecoratedBox(
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment
                              .topCenter,
                      end:
                          Alignment
                              .bottomCenter,
                      colors: [
                        Colors
                            .transparent,
                        Colors.black
                            .withValues(
                          alpha:
                              0.82,
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  left: 9,
                  right: 9,
                  bottom: 8,
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            Text(
                          widget
                              .item
                              .title,
                          maxLines:
                              1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize:
                                12,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      Text(
                        widget.item
                                    .mediaType ==
                                'tv'
                            ? 'TV'
                            : 'MOVIE',
                        style:
                            const TextStyle(
                          color:
                              chipluxCyan,
                          fontSize:
                              9,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileBanner
    extends StatelessWidget {
  final String? imageUrl;

  const _ProfileBanner({
    required this.imageUrl,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final hasBanner =
        imageUrl != null &&
        imageUrl!.isNotEmpty;

    return Container(
      decoration:
          BoxDecoration(
        color:
            chipluxSurface,
        image:
            hasBanner
                ? DecorationImage(
                    image:
                        NetworkImage(
                      imageUrl!,
                    ),
                    fit:
                        BoxFit.cover,
                  )
                : null,
      ),
      child: Stack(
        fit:
            StackFit.expand,
        children: [
          if (!hasBanner)
            DecoratedBox(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment
                          .topLeft,
                  end:
                      Alignment
                          .bottomRight,
                  colors: [
                    chipluxViolet
                        .withValues(
                      alpha: 0.18,
                    ),
                    chipluxPurple
                        .withValues(
                      alpha: 0.12,
                    ),
                    chipluxCyan
                        .withValues(
                      alpha: 0.10,
                    ),
                  ],
                ),
              ),
            ),

          // Makes Profile title/menu readable.
          DecoratedBox(
            decoration:
                BoxDecoration(
              gradient:
                  LinearGradient(
                begin:
                    Alignment
                        .topCenter,
                end:
                    Alignment
                        .bottomCenter,
                colors: [
                  Colors.black
                      .withValues(
                    alpha: 0.18,
                  ),
                  chipluxBackground
                      .withValues(
                    alpha: 0.08,
                  ),
                  chipluxBackground
                      .withValues(
                    alpha: 0.82,
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

enum _AchievementRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

class _Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int current;
  final int target;
  final _AchievementRarity rarity;
  

  const _Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
    required this.rarity,
  });

  bool get unlocked =>
      current >= target;

  double get progress {
    if (target <= 0) {
      return 0;
    }

    return (current / target)
        .clamp(
      0.0,
      1.0,
    );
  }
}

class _AchievementGroup {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int current;
  final List<_Achievement> tiers;

  const _AchievementGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.tiers,
  });

  _Achievement?
      get highestUnlockedTier {
    _Achievement? result;

    for (final tier in tiers) {
      if (tier.unlocked) {
        result = tier;
      }
    }

    return result;
  }

  _Achievement?
      get nextTier {
    for (final tier in tiers) {
      if (!tier.unlocked) {
        return tier;
      }
    }

    return null;
  }

  bool get hasUnlockedTier =>
      highestUnlockedTier != null;

  bool get completed =>
      nextTier == null;

  double get progress {
    final next =
        nextTier;

    if (next == null) {
      return 1.0;
    }

    return (current /
            next.target)
        .clamp(
      0.0,
      1.0,
    );
  }
}

class AchievementsPage
    extends StatelessWidget {
  const AchievementsPage({
    super.key,
  });

  void _showAchievementGroup(
  BuildContext context,
  _AchievementGroup group,
) {
  final pinService =
      MedalPinService.instance;

  final bool canPin =
      group.hasUnlockedTier;

  final bool isPinned =
      pinService.isPinned(
    group.id,
  );

  final currentTier =
      group.highestUnlockedTier;

  final Color accent =
      currentTier != null
          ? _achievementAccent(
              currentTier.rarity,
            )
          : Colors.white38;

  final IconData achievementIcon =
      currentTier?.icon ??
          group.icon;

  showModalBottomSheet(
    context: context,

    // Transparent so our custom
    // bordered container is visible.
    backgroundColor:
        Colors.transparent,

    isScrollControlled: true,

    builder: (
      sheetContext,
    ) {
      return SafeArea(
        child: Container(
          margin:
              const EdgeInsets.only(
            left: 10,
            right: 10,
            bottom: 6,
          ),
          padding:
              const EdgeInsets
                  .fromLTRB(
            20,
            20,
            20,
            24,
          ),
          decoration:
              BoxDecoration(
            color:
                chipluxSurface,

            borderRadius:
                const BorderRadius
                    .vertical(
              top: Radius.circular(
                24,
              ),
              bottom:
                  Radius.circular(
                24,
              ),
            ),

            // SAME COLOR AS
            // CURRENT MILESTONE
            border:
                Border.all(
              color:
                  accent.withValues(
                alpha: 0.75,
              ),
              width: 1.5,
            ),

            boxShadow: [
              BoxShadow(
                color:
                    accent.withValues(
                  alpha: 0.15,
                ),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              // =========================
              // ACHIEVEMENT ICON
              // =========================

              Icon(
                achievementIcon,
                color: accent,
                size: 34,
              ),

              const SizedBox(
                height: 8,
              ),

              // =========================
              // TITLE
              // =========================

              Text(
                group.title,
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color: accent,
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                '${group.current} watched',
                style:
                    TextStyle(
                  color:
                      accent.withValues(
                    alpha: 0.65,
                  ),
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // =========================
              // TIERS
              // =========================

              for (int i = 0;
                  i <
                      group.tiers
                          .length;
                  i++) ...[
                _AchievementTierRow(
                  tier:
                      group.tiers[i],
                  isCurrent:
                      group
                              .highestUnlockedTier
                              ?.id ==
                          group
                              .tiers[i]
                              .id,
                ),

                if (i <
                    group.tiers.length -
                        1)
                  const SizedBox(
                    height: 9,
                  ),
              ],

              const SizedBox(
                height: 20,
              ),

              // =========================
              // PIN BUTTON
              // =========================

              SizedBox(
                width:
                    double.infinity,
                child:
                    ElevatedButton.icon(
                  style:
                      ElevatedButton
                          .styleFrom(
                    foregroundColor:
                        accent,

                    backgroundColor:
                        accent
                            .withValues(
                      alpha: 0.10,
                    ),

                    side:
                        BorderSide(
                      color:
                          accent
                              .withValues(
                        alpha: 0.45,
                      ),
                    ),

                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 13,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                  ),

                  onPressed:
                      !canPin
                          ? null
                          : () async {
                              Navigator.pop(
                                sheetContext,
                              );

                              if (isPinned) {
                                await pinService
                                    .unpin();
                              } else {
                                await pinService
                                    .pin(
                                  group.id,
                                );
                              }
                            },

                  icon:
                      Icon(
                    isPinned
                        ? Icons
                            .push_pin_outlined
                        : Icons
                            .push_pin_rounded,

                    // SAME COLOR
                    color: accent,
                  ),

                  label:
                      Text(
                    !canPin
                        ? 'Unlock a tier first'
                        : isPinned
                            ? 'Remove from Display Name'
                            : 'Pin to Display Name',

                    style:
                        TextStyle(
                      color: accent,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(
    BuildContext context,
  ) {
    final library =
        LibraryService.instance;

    final pinService =
        MedalPinService.instance;

    return Scaffold(
      backgroundColor:
          chipluxBackground,

      appBar: AppBar(
        backgroundColor:
            chipluxBackground,
        elevation: 0,
        title:
            const Text(
          'Achievements',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body: ChipluxBackground(
        style:
            ChipluxBackgroundStyle
                .profile,

        child: AnimatedBuilder(
          animation:
              Listenable.merge([
            library,
            pinService,
          ]),

          builder: (
            context,
            _,
          ) {
            // =========================
            // MOVIES ACHIEVEMENT GROUP
            // =========================

            final int moviesWatched =
                library
                    .moviesWatchedCount;

            final movieGroup =
                _movieAchievementGroupFor(
              moviesWatched,
            );

            final groups =
                <_AchievementGroup>[
              movieGroup,
            ];

            // =========================
            // COLLECTION STATS
            // =========================

            final allTiers =
                groups.expand(
              (group) =>
                  group.tiers,
            ).toList();

            final int unlocked =
                allTiers.where(
              (tier) =>
                  tier.unlocked,
            ).length;

            final int collectionPercent =
                allTiers.isEmpty
                    ? 0
                    : ((unlocked /
                                allTiers
                                    .length) *
                            100)
                        .round();

            return ListView(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                18,
                12,
                18,
                35,
              ),
              children: [
                // =========================
                // MEDAL COLLECTION
                // =========================

                Container(
                  padding:
                      const EdgeInsets
                          .all(
                    1.2,
                  ),
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),

                    gradient:
                        const LinearGradient(
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment
                              .bottomRight,
                      colors: [
                        chipluxCyan,
                        chipluxViolet,
                        chipluxPurple,
                      ],
                    ),
                  ),

                  child: Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 17,
                      vertical: 15,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          chipluxSurface,
                      borderRadius:
                          BorderRadius
                              .circular(
                        19,
                      ),
                    ),

                    child: Row(
                      children: [
                        // Same gradient medal icon
                        // used on the Profile page.
                        ShaderMask(
                          shaderCallback:
                              (bounds) {
                            return const LinearGradient(
                              begin:
                                  Alignment
                                      .topLeft,
                              end:
                                  Alignment
                                      .bottomRight,
                              colors: [
                                chipluxCyan,
                                chipluxViolet,
                                chipluxPurple,
                              ],
                            ).createShader(
                              bounds,
                            );
                          },

                          child:
                              const Icon(
                            Icons
                                .workspace_premium_rounded,
                            color:
                                Colors.white,
                            size: 31,
                          ),
                        ),

                        const SizedBox(
                          width: 13,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Text(
                                'Medal Collection',
                                style:
                                    TextStyle(
                                  fontSize:
                                      17,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                height: 3,
                              ),

                              Text(
                                '$unlocked / ${allTiers.length} unlocked',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white54,
                                  fontSize:
                                      12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Text(
                          '$collectionPercent%',
                          style:
                              const TextStyle(
                            color:
                                chipluxCyan,
                            fontSize: 15,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 25,
                ),

                // =========================
                // MOVIES SECTION
                // =========================

                const Text(
                  'Movies',
                  style:
                      TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  '$moviesWatched movies watched',
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0x75FFFFFF,
                    ),
                    fontSize: 12,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                // =========================
                // ACHIEVEMENT GROUP GRID
                // =========================

                LayoutBuilder(
                  builder: (
                    context,
                    constraints,
                  ) {
                    final int columns;

if (constraints.maxWidth <
    360) {
  columns = 2;
} else if (
    constraints.maxWidth <
        520) {
  columns = 3;
} else {
  columns = 4;
}

                    return GridView.builder(
                      shrinkWrap: true,

                      physics:
                          const NeverScrollableScrollPhysics(),

                      itemCount:
                          groups.length,

                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            columns,

                        crossAxisSpacing:
                            10,

                        mainAxisSpacing:
                            13,

                        childAspectRatio:
    columns == 2
        ? 0.82
        : columns == 3
            ? 0.72
            : 0.80,
                      ),

                      itemBuilder: (
                        context,
                        index,
                      ) {
                        final group =
                            groups[
                                index];

                        return _AchievementGroupCard(
                          group:
                              group,

                          isPinned:
                              pinService
                                  .isPinned(
                            group.id,
                          ),

                          onTap: () {
                            _showAchievementGroup(
                              context,
                              group,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AchievementTierRow
    extends StatelessWidget {
  final _Achievement tier;
  final bool isCurrent;

  const _AchievementTierRow({
    required this.tier,
    required this.isCurrent,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final unlocked =
        tier.unlocked;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: isCurrent
              ? 0.06
              : 0.025,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              isCurrent
                  ? _achievementAccent(
                      tier.rarity,
                    ).withValues(
                      alpha: 0.35,
                    )
                  : Colors.white
                      .withValues(
                      alpha: 0.05,
                    ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child:
                unlocked
                    ? _AchievementMedal(
                        achievement:
                            tier,
                      )
                    : Container(
                        decoration:
                            const BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color:
                              Colors.white10,
                        ),
                        child:
                            Icon(
                          tier.icon,
                          color:
                              Colors.white24,
                          size: 21,
                        ),
                      ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  tier.title,
                  style:
                      TextStyle(
                    color:
                        unlocked
                            ? Colors.white
                            : Colors.white54,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  tier.description,
                  style:
                      const TextStyle(
                    color:
                        Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          if (unlocked)
            Icon(
              Icons
                  .check_circle_rounded,
              color:
                  _achievementAccent(
                tier.rarity,
              ),
              size: 20,
            )
          else
            Text(
              '${tier.current.clamp(0, tier.target)} / ${tier.target}',
              style:
                  const TextStyle(
                color:
                    Colors.white38,
                fontSize: 10,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class _AchievementGroupCard
    extends StatelessWidget {
  final _AchievementGroup group;
  final bool isPinned;
  final VoidCallback onTap;

  const _AchievementGroupCard({
    required this.group,
    required this.isPinned,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final achieved =
        group.highestUnlockedTier;

    final next =
        group.nextTier;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: Container(
          padding:
              const EdgeInsets
                  .fromLTRB(
            8,
            11,
            8,
            9,
          ),
          decoration:
              BoxDecoration(
            color:
                chipluxSurface,
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border:
                Border.all(
              color:
                  achieved != null
                      ? _achievementAccent(
                          achieved
                              .rarity,
                        ).withValues(
                          alpha: 0.28,
                        )
                      : Colors.white
                          .withValues(
                          alpha: 0.06,
                        ),
            ),
          ),
          child: Column(
            children: [
              if (achieved != null)
                _AchievementMedal(
                  achievement:
                      achieved,
                )
              else
                Container(
                  width: 62,
                  height: 62,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        Colors.white
                            .withValues(
                      alpha: 0.05,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors.white12,
                    ),
                  ),
                  child:
                      Icon(
                    group.icon,
                    color:
                        Colors.white24,
                    size: 31,
                  ),
                ),

              const SizedBox(
                height: 9,
              ),

              Text(
                group.title,
                maxLines: 1,
                overflow:
                    TextOverflow
                        .ellipsis,
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      achieved != null
                          ? Colors.white
                          : Colors.white54,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                next != null
                    ? 'Next: ${next.target}'
                    : 'Max tier',
                style:
                    const TextStyle(
                  color:
                      Colors.white38,
                  fontSize: 8.5,
                ),
              ),

              
              const Spacer(),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                child:
                    LinearProgressIndicator(
                  value:
                      group.progress,
                  minHeight: 4,
                  backgroundColor:
                      Colors.white10,
                  valueColor:
                      AlwaysStoppedAnimation<
                          Color>(
                    achieved != null
                        ? _achievementAccent(
                            achieved
                                .rarity,
                          )
                        : Colors.white30,
                  ),
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                next != null
                    ? '${group.current.clamp(0, next.target)} / ${next.target}'
                    : isPinned
                        ? 'PINNED'
                        : 'COMPLETE',
                style:
                    TextStyle(
                  color:
                      isPinned
                          ? chipluxCyan
                          : Colors.white38,
                  fontSize: 8,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _achievementAccent(
  _AchievementRarity rarity,
) {
  switch (rarity) {
    case _AchievementRarity
          .common:
      return Colors.white;

    case _AchievementRarity
          .uncommon:
      return chipluxCyan;

    case _AchievementRarity
          .rare:
      return const Color(
        0xFFFFC857,
      );

    case _AchievementRarity
          .epic:
      return const Color(
        0xFFFF5C72,
      );

    case _AchievementRarity
          .legendary:
      return chipluxPurple;
  }
}

class _AchievementMedal
    extends StatefulWidget {
  final _Achievement
      achievement;

  const _AchievementMedal({
    required this.achievement,
  });

  @override
  State<_AchievementMedal>
      createState() =>
          _AchievementMedalState();
}

class _AchievementMedalState
    extends State<
        _AchievementMedal>
    with
        SingleTickerProviderStateMixin {
  late final AnimationController
      _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 2600,
      ),
    );

    if (widget.achievement
        .unlocked &&
    widget.achievement
            .target >=
        512) {
  _controller.repeat();
}
  }

  @override
  void didUpdateWidget(
    covariant _AchievementMedal
        oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    final shouldAnimate =
    widget.achievement
            .unlocked &&
        widget.achievement
                .target >=
            512;

    if (shouldAnimate &&
        !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate &&
        _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  List<Color> _colors() {
  if (!widget.achievement
      .unlocked) {
    return [
      Colors.white24,
      Colors.white12,
    ];
  }

  switch (
      widget.achievement.target) {
    case 2:
      return const [
        Colors.white,
        Color(
          0xFFBFC9D4,
        ),
      ];

    case 8:
      return const [
        Color(
          0xFF43E8FF,
        ),
        Color(
          0xFF64BFFF,
        ),
      ];

    case 16:
      return const [
        chipluxCyan,
        chipluxViolet,
      ];

    case 32:
      return const [
        Color(
          0xFFFFF1A8,
        ),
        Color(
          0xFFFFC857,
        ),
      ];

    case 64:
      return const [
        Color(
          0xFFFFC857,
        ),
        Color(
          0xFFFF8A4C,
        ),
        Color(
          0xFFFF5C72,
        ),
      ];

    case 128:
      return const [
        Color(
          0xFFFF5C72,
        ),
        chipluxPurple,
        chipluxViolet,
      ];

    case 512:
      return const [
        chipluxCyan,
        chipluxViolet,
        chipluxPurple,
        Color(
          0xFFFFC857,
        ),
        chipluxCyan,
      ];

    case 1024:
      return const [
        chipluxCyan,
        Colors.white,
        chipluxViolet,
        chipluxPurple,
        Color(
          0xFFFF5C72,
        ),
        Color(
          0xFFFFC857,
        ),
        chipluxCyan,
      ];

    default:
      return const [
        chipluxCyan,
        chipluxViolet,
      ];
  }
}

  @override
  Widget build(
    BuildContext context,
  ) {
    final unlocked =
        widget.achievement
            .unlocked;

    return AnimatedBuilder(
      animation:
          _controller,
      builder: (
        context,
        _,
      ) {
        final bool rotating =
    widget.achievement
            .target >=
        512;

final bool finalTier =
    widget.achievement
            .target >=
        1024;

final rotation =
    rotating
        ? _controller.value *
            math.pi *
            2
        : 0.0;

final pulse =
    finalTier
        ? 1.0 +
            math.sin(
                  _controller.value *
                      math.pi *
                      2,
                ) *
                0.045
        : 1.0;

return Transform.scale(
  scale: pulse,
  child: Container(
    width: 62,
    height: 62,
    padding: const EdgeInsets.all(
      2,
    ),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        transform: GradientRotation(
          rotation,
        ),
        colors: _colors(),
      ),
      boxShadow: [
        if (unlocked)
          BoxShadow(
            color: _achievementAccent(
              widget
                  .achievement
                  .rarity,
            ).withValues(
              alpha: 0.18,
            ),
            blurRadius: 10,
          ),
      ],
    ),
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked
            ? chipluxSurfaceLight
            : const Color(
                0xFF18202A,
              ),
        border: Border.all(
          color: Colors.black
              .withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Center(
        child: unlocked
            ? ShaderMask(
                shaderCallback:
                    (bounds) {
                  return LinearGradient(
                    transform:
                        GradientRotation(
                      rotation,
                    ),
                    colors:
                        _colors(),
                  ).createShader(
                    bounds,
                  );
                },
                child: Icon(
                  widget
                      .achievement
                      .icon,
                  color:
                      Colors.white,
                  size: 31,
                ),
              )
            : Icon(
                widget
                    .achievement
                    .icon,
                color:
                    Colors.white24,
                size: 31,
              ),
      ),
    ),
  ),
); // Transform.scale
}, // builder
); // AnimatedBuilder
}
}

class MedalPinService
    extends ChangeNotifier {
  MedalPinService._();

  static final MedalPinService
      instance =
      MedalPinService._();

  static const String _key =
      'chiplux_pinned_medal_v1';

  String? _pinnedAchievementId;

  String?
      get pinnedAchievementId =>
          _pinnedAchievementId;

  bool isPinned(
    String id,
  ) {
    return _pinnedAchievementId ==
        id;
  }

  Future<void> init() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    _pinnedAchievementId =
        prefs.getString(
      _key,
    );
  }

  Future<void> pin(
    String id,
  ) async {
    _pinnedAchievementId =
        id;

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      _key,
      id,
    );

    notifyListeners();
  }

  Future<void> unpin() async {
    _pinnedAchievementId =
        null;

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.remove(
      _key,
    );

    notifyListeners();
  }
}

class ProfilePage
    extends StatefulWidget {
  final VoidCallback?
      onEpisodesWatchedTap;

  final VoidCallback?
      onMoviesWatchedTap;

  final VoidCallback?
      onEpisodesRatedTap;

  final VoidCallback?
      onTitlesRatedTap;

  const ProfilePage({
    super.key,
    this.onEpisodesWatchedTap,
    this.onMoviesWatchedTap,
    this.onEpisodesRatedTap,
    this.onTitlesRatedTap,
  });

  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}

class _ProfilePageState
    extends State<ProfilePage> {
  final library =
      LibraryService.instance;

  final profile =
      ProfileService.instance;

  final critic =
      CriticService.instance;

  final GlobalKey
      _genreRuntimeKey =
      GlobalKey();

  final GlobalKey
      _ratingDistributionKey =
      GlobalKey();

  bool _genreRuntimeExpanded =
      false;

  @override
  void initState() {
    super.initState();

    _refreshProfileInBackground();

    unawaited(
      critic.refresh(),
    );
  }

  // =====================================================
  // SCROLLING
  // =====================================================

  void _scrollToProfileSection(
    GlobalKey key,
  ) {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        final targetContext =
            key.currentContext;

        if (targetContext ==
            null) {
          return;
        }

        Scrollable.ensureVisible(
          targetContext,
          duration:
              const Duration(
            milliseconds: 450,
          ),
          curve:
              Curves.easeInOutCubic,
          alignment: 0.08,
        );
      },
    );
  }

  // =====================================================
  // BACKGROUND REFRESH
  // =====================================================

  void
      _refreshProfileInBackground() {
    unawaited(
      profile.loadProfile(),
    );

    unawaited(
      _backfillStatsInBackground(),
    );
  }

  Future<void>
      _backfillStatsInBackground()
      async {
    try {
      await library
          .backfillMissingRuntimes();

      if (!mounted) {
        return;
      }

      setState(() {});
    } catch (e) {
      debugPrint(
        'Could not refresh profile stats: $e',
      );
    }
  }

  Future<void>
      _refreshProfile() async {
    await Future.wait([
      profile.loadProfile(),
      library
          .backfillMissingRuntimes(),
      critic.refresh(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // =====================================================
  // GENRE HELPERS
  // =====================================================

  List<int> _genresForItem(
    LibraryItem item,
  ) {
    return item.genreIds
        .toSet()
        .toList();
  }

  String _genreName(
    int genreId,
  ) {
    switch (genreId) {
      case 28:
        return 'Action';

      case 12:
        return 'Adventure';

      case 16:
        return 'Animation';

      case 35:
        return 'Comedy';

      case 80:
        return 'Crime';

      case 99:
        return 'Documentary';

      case 18:
        return 'Drama';

      case 10751:
        return 'Family';

      case 14:
        return 'Fantasy';

      case 36:
        return 'History';

      case 27:
        return 'Horror';

      case 10402:
        return 'Music';

      case 9648:
        return 'Mystery';

      case 10749:
        return 'Romance';

      case 878:
        return 'Science Fiction';

      case 10770:
        return 'TV Movie';

      case 53:
        return 'Thriller';

      case 10752:
        return 'War';

      case 37:
        return 'Western';

      // TV genres
      case 10759:
        return 'Action & Adventure';

      case 10762:
        return 'Kids';

      case 10763:
        return 'News';

      case 10764:
        return 'Reality';

      case 10765:
        return 'Sci-Fi & Fantasy';

      case 10766:
        return 'Soap';

      case 10767:
        return 'Talk';

      case 10768:
        return 'War & Politics';

      default:
        return 'Other';
    }
  }

  List<_GenreRuntimeStat>
      _buildGenreRuntimeStats() {
    final items =
        library.items.toList();

    if (items.isEmpty) {
      return [];
    }

    final titleCounts =
        <int, int>{};

    final watchedMinutes =
        <int, int>{};

    for (final item in items) {
      final genres =
          _genresForItem(
        item,
      );

      if (genres.isEmpty) {
        continue;
      }

      final itemWatchedMinutes =
          library
              .watchedMinutesForItem(
        item,
      );

      for (final genreId
          in genres.toSet()) {
        titleCounts[genreId] =
            (titleCounts[
                        genreId] ??
                    0) +
                1;

        watchedMinutes[genreId] =
            (watchedMinutes[
                        genreId] ??
                    0) +
                itemWatchedMinutes;
      }
    }

    final int
        totalGenreRuntime =
        watchedMinutes.values
            .fold(
      0,
      (
        sum,
        minutes,
      ) =>
          sum + minutes,
    );

    final result =
        <_GenreRuntimeStat>[];

    for (final entry
        in titleCounts.entries) {
      final genreId =
          entry.key;

      final count =
          entry.value;

      final minutes =
          watchedMinutes[
                  genreId] ??
              0;

      final percentage =
          totalGenreRuntime > 0
              ? (minutes /
                      totalGenreRuntime) *
                  100
              : 0.0;

      result.add(
        _GenreRuntimeStat(
          genre:
              _genreName(
            genreId,
          ),
          titleCount:
              count,
          watchedMinutes:
              minutes,
          percentage:
              percentage,
        ),
      );
    }

    result.sort(
      (
        a,
        b,
      ) {
        final runtimeComparison =
            b.watchedMinutes
                .compareTo(
          a.watchedMinutes,
        );

        if (runtimeComparison !=
            0) {
          return runtimeComparison;
        }

        return b.titleCount
            .compareTo(
          a.titleCount,
        );
      },
    );

    return result;
  }

  // =====================================================
  // GENRE RUNTIME PANEL
  // =====================================================

  Widget
      _buildGenreRuntimeSection() {
    final stats =
        _buildGenreRuntimeStats();

    if (stats.isEmpty) {
      return const SizedBox
          .shrink();
    }

    final visibleStats =
        _genreRuntimeExpanded
            ? stats
            : stats
                .take(4)
                .toList();

    final canExpand =
        stats.length > 4;

    const genreColors =
        <Color>[
      chipluxCyan,
      Color(
        0xFF55C7FF,
      ),
      chipluxViolet,
      chipluxPurple,
      Color(
        0xFF6F7CFF,
      ),
      Color(
        0xFF43B8FF,
      ),
      Color(
        0xFFB56DFF,
      ),
      Color(
        0xFF5363B8,
      ),
    ];

    Color genreColor(
      int index,
    ) {
      return genreColors[
          index %
              genreColors
                  .length];
    }

    String formatRuntime(
      int totalMinutes,
    ) {
      final hours =
          totalMinutes ~/ 60;

      final minutes =
          totalMinutes % 60;

      if (hours > 0 &&
          minutes > 0) {
        return '${hours}h ${minutes}m';
      }

      if (hours > 0) {
        return '${hours}h';
      }

      return '${minutes}m';
    }

    final totalGenreWeight =
        stats.fold<double>(
      0,
      (
        sum,
        stat,
      ) =>
          sum +
          stat.percentage,
    );

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color:
            chipluxSurface,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              chipluxCyan
                  .withValues(
            alpha: 0.14,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                chipluxViolet
                    .withValues(
              alpha: 0.07,
            ),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .bar_chart_rounded,
                color:
                    chipluxCyan,
                size: 27,
              ),

              SizedBox(
                width: 10,
              ),

              Text(
                'Genre Runtime',
                style:
                    TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight
                          .bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 24,
          ),

          // LARGE SEGMENTED BAR
          ClipRRect(
            borderRadius:
                BorderRadius
                    .circular(
              30,
            ),
            child: SizedBox(
              height: 22,
              child: Row(
                children:
                    stats
                        .asMap()
                        .entries
                        .map(
                  (
                    entry,
                  ) {
                    final index =
                        entry.key;

                    final stat =
                        entry.value;

                    final normalized =
                        totalGenreWeight >
                                0
                            ? stat.percentage /
                                totalGenreWeight
                            : 0.0;

                    int flex =
                        (normalized *
                                10000)
                            .round();

                    if (flex < 1) {
                      flex = 1;
                    }

                    return Expanded(
                      flex:
                          flex,
                      child:
                          Container(
                        color:
                            genreColor(
                          index,
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          ...visibleStats
              .asMap()
              .entries
              .map(
            (
              entry,
            ) {
              final index =
                  entry.key;

              final stat =
                  entry.value;

              final color =
                  genreColor(
                index,
              );

              final isLast =
                  index ==
                      visibleStats
                              .length -
                          1;

              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 15,
                          height:
                              15,
                          decoration:
                              BoxDecoration(
                            color:
                                color,
                            shape:
                                BoxShape
                                    .circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    color.withValues(
                                  alpha:
                                      0.30,
                                ),
                                blurRadius:
                                    8,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width: 11,
                        ),

                        Expanded(
                          child: Text(
                            stat.genre,
                            maxLines:
                                1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        SizedBox(
  width: 72,
  height: 22,
  child: FittedBox(
    fit: BoxFit.scaleDown,
    alignment:
        Alignment.centerRight,
    child: Text(
      '${stat.percentage.toStringAsFixed(1)}%',
      maxLines: 1,
      style:
          const TextStyle(
        fontSize: 15,
        fontWeight:
            FontWeight.bold,
        color:
            Colors.white,
      ),
    ),
  ),
),

                        const SizedBox(
                          width: 12,
                        ),

                        SizedBox(
                          width: 78,
                          child: Text(
                            formatRuntime(
                              stat.watchedMinutes,
                            ),
                            textAlign:
                                TextAlign
                                    .right,
                            style:
                                const TextStyle(
                              fontSize:
                                  14,
                              fontWeight:
                                  FontWeight
                                      .w500,
                              color:
                                  Colors
                                      .white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness:
                          1,
                      color:
                          Colors.white
                              .withValues(
                        alpha: 0.08,
                      ),
                    ),
                ],
              );
            },
          ),

          if (canExpand) ...[
            const SizedBox(
              height: 10,
            ),

            InkWell(
              borderRadius:
                  BorderRadius
                      .circular(
                14,
              ),
              onTap: () {
                setState(() {
                  _genreRuntimeExpanded =
                      !_genreRuntimeExpanded;
                });
              },
              child: Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 11,
                  horizontal: 12,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      chipluxSurfaceLight
                          .withValues(
                    alpha: 0.55,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Text(
                      _genreRuntimeExpanded
                          ? 'Show less'
                          : 'Show all ${stats.length} genres',
                      style:
                          const TextStyle(
                        color:
                            chipluxCyan,
                        fontSize:
                            14,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    Icon(
                      _genreRuntimeExpanded
                          ? Icons
                              .keyboard_arrow_up_rounded
                          : Icons
                              .keyboard_arrow_down_rounded,
                      color:
                          chipluxCyan,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // RATING DISTRIBUTION PANEL
  // =====================================================

  Widget
      _buildRatingDistributionSection() {
    const criticGold =
        Color(
      0xFFFFC857,
    );

    const criticOrange =
        Color(
      0xFFFF8A4C,
    );

    final int distributionTotal =
    critic.ratingDistribution.values.fold(
  0,
  (sum, count) => sum + count,
);

    Color ratingColor(
      int rating,
    ) {
      final t =
    (rating - 1) / 4;

      if (t < 0.5) {
        return Color.lerp(
          criticOrange,
          criticGold,
          t * 2,
        )!;
      }

      return Color.lerp(
        criticGold,
        chipluxPurple,
        (t - 0.5) * 2,
      )!;
    }

    final activeRatings =
        <int>[];

    for (int rating = 1;
        rating <= 5;
        rating++) {
      if ((critic
                      .ratingDistribution[
                  rating] ??
              0) >
          0) {
        activeRatings.add(
          rating,
        );
      }
    }

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color:
            chipluxSurface,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              criticGold
                  .withValues(
            alpha: 0.14,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                criticOrange
                    .withValues(
              alpha: 0.06,
            ),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .star_rate_rounded,
                color:
                    criticGold,
                size: 27,
              ),

              SizedBox(
                width: 10,
              ),

              Text(
                'Rating Distribution',
                style:
                    TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight
                          .bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 22,
          ),

          // LARGE SEGMENTED BAR
          ClipRRect(
            borderRadius:
                BorderRadius
                    .circular(
              30,
            ),
            child: Container(
              height: 20,
              color:
                  Colors.white10,
              child:
                  activeRatings
                          .isEmpty
                      ? const SizedBox
                          .expand()
                      : Row(
                          children:
                              activeRatings
                                  .map(
                            (
                              rating,
                            ) {
                              final count =
                                  critic.ratingDistribution[
                                          rating] ??
                                      0;

                              return Expanded(
                                flex:
                                    count,
                                child:
                                    Container(
                                  color:
                                      ratingColor(
                                    rating,
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                        ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          for (int rating = 1;
              rating <= 5;
              rating++) ...[
            Builder(
              builder:
                  (
                context,
              ) {
                final count =
                    critic.ratingDistribution[
                            rating] ??
                        0;

                final double percentage =
    distributionTotal > 0
        ? (count.toDouble() /
                distributionTotal.toDouble()) *
            100.0
        : 0.0;

                final color =
                    ratingColor(
                  rating,
                );

                return Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .star_rounded,
                        color:
                            color,
                        size: 18,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      // More room for 10/10
                      SizedBox(
                        width: 58,
                        child: Text(
  '$rating ★',
                          style:
                              const TextStyle(
                            fontSize:
                                14,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child: Text(
                          '$count '
                          '${count == 1 ? 'rating' : 'ratings'}',
                          style:
                              const TextStyle(
                            color:
                                Colors
                                    .white60,
                            fontSize:
                                13,
                          ),
                        ),
                      ),

                      SizedBox(
  width: 64,
  height: 20,
  child: FittedBox(
    fit: BoxFit.scaleDown,
    alignment:
        Alignment.centerRight,
    child: Text(
      '${percentage.toStringAsFixed(1)}%',
      maxLines: 1,
      style:
          const TextStyle(
        fontSize: 13,
        fontWeight:
            FontWeight.bold,
      ),
    ),
  ),
),
                    ],
                  ),
                );
              },
            ),

            if (rating != 5)
              Divider(
                height: 1,
                color:
                    Colors.white
                        .withValues(
                  alpha: 0.06,
                ),
              ),
          ],
        ],
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child:
          AnimatedBuilder(
        animation:
            Listenable.merge([
          library,
          profile,
          critic,
          MedalPinService.instance,
        ]),
        builder:
            (
          context,
          _,
        ) {
          final shownName =
              profile.displayName
                      .isNotEmpty
                  ? profile
                      .displayName
                  : 'Chiplux User';

          final initial =
              shownName.isNotEmpty
                  ? shownName[0]
                      .toUpperCase()
                  : 'C';

                  final movieGroup =
    _movieAchievementGroupFor(
  library.moviesWatchedCount,
);

final pinnedId =
    MedalPinService.instance
        .pinnedAchievementId;

final _Achievement?
    pinnedAchievement =
    pinnedId ==
            movieGroup.id
        ? movieGroup
            .highestUnlockedTier
        : null;

          return RefreshIndicator(
            color:
                chipluxCyan,
            backgroundColor:
                chipluxSurface,
            onRefresh:
                _refreshProfile,
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              // Keeps lower profile panels
              // mounted for ensureVisible().
              scrollCacheExtent:
    const ScrollCacheExtent.pixels(
  3000,
),

              padding:
                  const EdgeInsets
                      .fromLTRB(
                20,
                20,
                20,
                30,
              ),
              children: [
                // PROFILE HEADER
                Stack(
  clipBehavior:
      Clip.none,
  children: [
    // ListView has 20px top and side
    // padding.
    //
    // Extending by -20 makes the banner
    // reach the actual screen edges.
    //
    // 137px means its bottom lands
    // exactly around the vertical middle
    // of the existing 88px avatar.
    Positioned(
      left: -20,
      right: -20,
      top: -20,
      height: 190,
      child:
          _ProfileBanner(
        imageUrl:
            profile.bannerUrl,
      ),
    ),

    Column(
      children: [
        // PROFILE TITLE + MENU
        Row(
  children: [
    // =========================
    // ACHIEVEMENTS
    // =========================

    Material(
  color:
      Colors.transparent,
  child: InkWell(
    borderRadius:
        BorderRadius.circular(
      16,
    ),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const AchievementsPage(),
        ),
      );
    },
    child: Container(
      width: 43,
      height: 43,
      decoration:
          BoxDecoration(
        color:
            chipluxSurface.withValues(
          alpha: 0.45,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              chipluxViolet.withValues(
            alpha: 0.22,
          ),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                chipluxCyan.withValues(
              alpha: 0.06,
            ),
            blurRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback:
              (bounds) {
            return const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                chipluxCyan,
                chipluxViolet,
                chipluxPurple,
              ],
            ).createShader(
              bounds,
            );
          },
          child:
              const Icon(
            Icons
                .workspace_premium_rounded,
            color:
                Colors.white,
            size: 26,
          ),
        ),
      ),
    ),
    ),
),

const SizedBox(
  width: 8,
),

if (Supabase.instance.client
        .auth.currentUser !=
    null)
  _FollowerCountBadge(
    userId:
        Supabase.instance.client
            .auth.currentUser!
            .id,
  ),

const Spacer(),

    // =========================
    // PROFILE MENU
    // =========================

    IconButton(
      tooltip:
          'Edit Profile',
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const EditProfilePage(),
          ),
        );

        if (!mounted) {
          return;
        }

        await profile
            .loadProfile();
      },
      icon:
          const Icon(
        Icons.menu_rounded,
        size: 29,
      ),
      color:
          Colors.white,
    ),
  ],
),

        const SizedBox(
          height: 25,
        ),

        // AVATAR - same 88 x 88 position
        // and size as before.
        if (profile
            .isLoading)
          const Center(
            child:
                CircularProgressIndicator(),
          )
        else
          Center(
            child: Column(
              children: [
                Container(
  width: 94,
  height: 94,
  padding:
      const EdgeInsets.all(
    3,
  ),
  decoration:
      BoxDecoration(
    shape:
        BoxShape.circle,

    // White profile frame.
    border:
        Border.all(
      color:
          Colors.white,
      width: 2,
    ),

    color:
        chipluxBackground,

    boxShadow: [
      BoxShadow(
        color:
            Colors.white
                .withValues(
          alpha: 0.08,
        ),
        blurRadius: 7,
      ),

      BoxShadow(
        color:
            chipluxViolet
                .withValues(
          alpha: 0.12,
        ),
        blurRadius: 20,
      ),
    ],
  ),
  child: Container(
    decoration:
        BoxDecoration(
      shape:
          BoxShape.circle,

      gradient:
          profile.avatarUrl ==
                      null ||
                  profile
                      .avatarUrl!
                      .isEmpty
              ? const LinearGradient(
                  begin:
                      Alignment.topLeft,
                  end:
                      Alignment.bottomRight,
                  colors: [
                    chipluxCyan,
                    chipluxViolet,
                    chipluxPurple,
                  ],
                )
              : null,

      image:
          profile.avatarUrl !=
                      null &&
                  profile
                      .avatarUrl!
                      .isNotEmpty
              ? DecorationImage(
                  image:
                      NetworkImage(
                    profile
                        .avatarUrl!,
                  ),
                  fit:
                      BoxFit.cover,
                )
              : null,
    ),
    child:
        profile.avatarUrl ==
                    null ||
                profile
                    .avatarUrl!
                    .isEmpty
            ? Center(
                child:
                    Text(
                  initial,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 38,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              )
            : null,
  ),
),

                const SizedBox(
                  height: 9,
                ),

                Stack(
  clipBehavior:
      Clip.none,
  alignment:
      Alignment.center,
  children: [
    Container(
      padding:
          const EdgeInsets.all(
        1.2,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          30,
        ),
        color:
            Colors.white.withValues(
          alpha: 0.18,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.18,
            ),
            blurRadius: 8,
          ),
        ],
      ),
      child: Container(
        padding:
            EdgeInsets.fromLTRB(
          pinnedAchievement !=
                  null
              ? 34
              : 20,
          8,
          20,
          8,
        ),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            29,
          ),
          color:
              chipluxSurface
                  .withValues(
            alpha: 0.94,
          ),
        ),
        child:
            Text(
          shownName,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            color:
                Colors.white,
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
            letterSpacing:
                0.3,
          ),
        ),
      ),
    ),

    if (pinnedAchievement !=
        null)
      Positioned(
        left: -12,
        top: 6,
        child:
            _PinnedAchievementBadge(
          achievement:
              pinnedAchievement,
        ),
      ),
  ],
),
              ],
            ),
          ),
      ],
    ),
  ],
),

const SizedBox(
  height: 32,
),

                // =========================
                // RUNTIME LEVEL
                // =========================

                _LevelCard(
                  totalMinutes:
                      library
                          .totalWatchedMinutes,
                  title:
                      library
                          .viewerTitle,
                  onTap: () {
                    _scrollToProfileSection(
                      _genreRuntimeKey,
                    );
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // WATCHED STATS
                Column(
  children: [
    _WatchStatCard(
      value:
          library
              .watchedEpisodeCount,

      label:
          'Episodes Watched',

      icon:
          Icons
              .playlist_add_check_rounded,

      onTap:
          widget
              .onEpisodesWatchedTap,
    ),

    const SizedBox(
      height:
          7,
    ),

    _WatchStatCard(
      value:
          library
              .moviesWatchedCount,

      label:
          'Movies Watched',

      icon:
          Icons
              .movie_outlined,

      onTap:
          widget
              .onMoviesWatchedTap,
    ),
  ],
),

                const SizedBox(
                  height: 14,
                ),

                // =========================
                // CRITIC LEVEL
                // =========================

                _CriticReputationCard(
                  level:
                      critic.level,
                  title:
                      critic.title,
                  xp:
                      critic
                          .xpInLevel,
                  requiredXp:
                      critic
                          .requiredXp,
                  totalRatings:
                      critic
                          .totalRatings,
                  titleCoverage:
    critic.titleRatingCoverage,

episodeCoverage:
    critic.episodeRatingCoverage,

averageStars:
    critic.averageStars,
                  onTap: () {
                    _scrollToProfileSection(
                      _ratingDistributionKey,
                    );
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // RATED STATS
                Column(
  children: [
    _RatingStatCard(
      value:
          critic
              .episodeRatingCount,

      label:
          'Episodes Rated',

      icon:
          Icons.tv_outlined,

      onTap:
          widget
              .onEpisodesRatedTap,
    ),

    const SizedBox(
      height:
          7,
    ),

    _RatingStatCard(
      value:
          critic.movieRatingCount +
              critic.tvRatingCount,

      label:
          'Titles Rated',

      icon:
          Icons
              .movie_filter_outlined,

      onTap:
          widget
              .onTitlesRatedTap,
    ),
  ],
),

                const SizedBox(
                  height: 24,
                ),

                // =========================
                // GENRE RUNTIME FIRST
                // =========================

                KeyedSubtree(
                  key:
                      _genreRuntimeKey,
                  child:
                      _buildGenreRuntimeSection(),
                ),

                const SizedBox(
                  height: 24,
                ),

                // =========================
                // RATING DISTRIBUTION SECOND
                // =========================

                KeyedSubtree(
                  key:
                      _ratingDistributionKey,
                  child:
                      _buildRatingDistributionSection(),
                ),

                const SizedBox(
                  height: 30,
                ),

                // SIGN OUT
                SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () async {
      final library =
          LibraryService.instance;

      await library
          .waitForCloudSync();

      await AuthService
          .instance
          .signOut();

      await library
          .clearLocalData();

      CriticService.instance
          .clear();

      ProfileService.instance
          .clear();
    },

    icon: const Icon(
      Icons.logout,
    ),

    label: const Text(
      'Sign Out',
    ),

    style:
        OutlinedButton.styleFrom(
      foregroundColor:
          Colors.redAccent,
      side:
          const BorderSide(
        color:
            Colors.redAccent,
        width: 1.4,
      ),
    ),
  ),
),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FollowerCountBadge
    extends StatefulWidget {
  final String userId;

  const _FollowerCountBadge({
    required this.userId,
  });

  @override
  State<_FollowerCountBadge>
      createState() =>
          _FollowerCountBadgeState();
}

class _FollowerCountBadgeState
    extends State<_FollowerCountBadge> {
  int followerCount = 0;
  bool loading = true;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();

    _loadFollowerCount();
    _startRealtime();
  }

  Future<void>
      _loadFollowerCount() async {
    try {
      final rows =
          await Supabase
              .instance
              .client
              .from('follows')
              .select(
                'follower_id',
              )
              .eq(
                'following_id',
                widget.userId,
              );

      if (!mounted) {
        return;
      }

      setState(() {
        followerCount =
            rows.length;

        loading = false;
      });
    } catch (e) {
      debugPrint(
        'Could not load follower count: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });
    }
  }

  void _startRealtime() {
    final client =
        Supabase.instance.client;

    _channel =
        client.channel(
      'followers_${widget.userId}_$hashCode',
    );

    _channel!
        .onPostgresChanges(
      event:
          PostgresChangeEvent.all,
      schema:
          'public',
      table:
          'follows',
      callback: (payload) {
        if (!mounted) {
          return;
        }

        unawaited(
          _loadFollowerCount(),
        );
      },
    ).subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      unawaited(
        _channel!.unsubscribe(),
      );
    }

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 43,
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 12,
      ),
      decoration:
          BoxDecoration(
        color:
            chipluxSurface
                .withValues(
          alpha: 0.45,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              chipluxCyan
                  .withValues(
            alpha: 0.22,
          ),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const Icon(
            Icons
                .people_alt_rounded,
            color:
                chipluxCyan,
            size: 22,
          ),

          const SizedBox(
            width: 6,
          ),

          if (loading)
            const SizedBox(
              width: 13,
              height: 13,
              child:
                  CircularProgressIndicator(
                strokeWidth: 1.5,
              ),
            )
          else
            Text(
              '$followerCount',
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 14,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class _PinnedAchievementBadge
    extends StatefulWidget {
  final _Achievement
      achievement;

  const _PinnedAchievementBadge({
    required this.achievement,
  });

  @override
  State<_PinnedAchievementBadge>
      createState() =>
          _PinnedAchievementBadgeState();
}

class _PinnedAchievementBadgeState
    extends State<
        _PinnedAchievementBadge>
    with
        SingleTickerProviderStateMixin {
  late final AnimationController
      _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 2600,
      ),
    );

    if (widget.achievement
            .rarity ==
        _AchievementRarity
            .legendary) {
      _controller.repeat();
    }
  }

  List<Color> _colors() {
  switch (
      widget.achievement.target) {
    case 2:
      return const [
        Colors.white,
        Color(
          0xFFBFC9D4,
        ),
      ];

    case 8:
      return const [
        Color(
          0xFF43E8FF,
        ),
        Color(
          0xFF64BFFF,
        ),
      ];

    case 16:
      return const [
        chipluxCyan,
        chipluxViolet,
      ];

    case 32:
      return const [
        Color(
          0xFFFFF1A8,
        ),
        Color(
          0xFFFFC857,
        ),
      ];

    case 64:
      return const [
        Color(
          0xFFFFC857,
        ),
        Color(
          0xFFFF8A4C,
        ),
        Color(
          0xFFFF5C72,
        ),
      ];

    case 128:
      return const [
        Color(
          0xFFFF5C72,
        ),
        chipluxPurple,
        chipluxViolet,
      ];

    case 512:
      return const [
        chipluxCyan,
        chipluxViolet,
        chipluxPurple,
        Color(
          0xFFFFC857,
        ),
        chipluxCyan,
      ];

    case 1024:
      return const [
        chipluxCyan,
        Colors.white,
        chipluxViolet,
        chipluxPurple,
        Color(
          0xFFFF5C72,
        ),
        Color(
          0xFFFFC857,
        ),
        chipluxCyan,
      ];

    default:
      return const [
        chipluxCyan,
        chipluxViolet,
      ];
  }
}

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation:
          _controller,
      builder: (
        context,
        _,
      ) {
        final rotation =
            widget.achievement
                        .rarity ==
                    _AchievementRarity
                        .legendary
                ? _controller.value *
                    math.pi *
                    2
                : 0.0;

        final colors =
            _colors();

        return Tooltip(
          message:
              widget.achievement.title,
          child: Container(
            width: 29,
            height: 29,
            padding:
                const EdgeInsets.all(
              1.5,
            ),
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              gradient:
                  LinearGradient(
                transform:
                    GradientRotation(
                  rotation,
                ),
                colors:
                    colors,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      _achievementAccent(
                    widget
                        .achievement
                        .rarity,
                  ).withValues(
                    alpha: 0.20,
                  ),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Container(
              decoration:
                  const BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    chipluxSurface,
              ),
              child: ShaderMask(
                shaderCallback:
                    (bounds) {
                  return LinearGradient(
                    transform:
                        GradientRotation(
                      rotation,
                    ),
                    colors:
                        colors,
                  ).createShader(
                    bounds,
                  );
                },
                child:
                    Icon(
                  widget
                      .achievement
                      .icon,
                  color:
                      Colors.white,
                  size: 17,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LevelHexBadge
    extends StatelessWidget {
  final int level;
  final List<Color> colors;

  const _LevelHexBadge({
    required this.level,
    required this.colors,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 70,
      height: 76,
      child: Stack(
        alignment:
            Alignment.center,
        children: [
          // =================================
          // OUTER GLOW
          // =================================

          Container(
            width: 54,
            height: 54,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      colors.first
                          .withValues(
                    alpha: 0.25,
                  ),
                  blurRadius:
                      20,
                  spreadRadius:
                      2,
                ),
              ],
            ),
          ),

          // =================================
          // HEXAGON
          // =================================

          ClipPath(
            clipper:
                _HexagonClipper(),
            child:
                Container(
              width: 66,
              height: 74,
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment
                          .topLeft,
                  end:
                      Alignment
                          .bottomRight,
                  colors:
                      colors,
                ),
              ),

              padding:
                  const EdgeInsets
                      .all(
                2,
              ),

              child:
                  ClipPath(
                clipper:
                    _HexagonClipper(),

                child:
                    Container(
                  decoration:
                      BoxDecoration(
                    color:
                        chipluxSurface,

                    gradient:
                        LinearGradient(
                      begin:
                          Alignment
                              .topLeft,
                      end:
                          Alignment
                              .bottomRight,
                      colors: [
                        colors.first
                            .withValues(
                          alpha:
                              0.10,
                        ),

                        chipluxSurface,

                        colors.last
                            .withValues(
                          alpha:
                              0.08,
                        ),
                      ],
                    ),
                  ),

                  child:
                      Stack(
                    alignment:
                        Alignment
                            .center,

                    children: [
                      // =================================
                      // CENTER GLOW
                      // =================================

                      Container(
                        width:
                            48,
                        height:
                            48,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape
                                  .circle,
                          gradient:
                              RadialGradient(
                            colors: [
                              colors
                                  .first
                                  .withValues(
                                alpha:
                                    0.16,
                              ),
                              Colors
                                  .transparent,
                            ],
                          ),
                        ),
                      ),

                      // =================================
                      // SUBTLE DIAGONAL DETAIL
                      // =================================

                      Positioned(
                        left:
                            -12,
                        top:
                            22,
                        child:
                            Transform.rotate(
                          angle:
                              -0.45,
                          child:
                              Container(
                            width:
                                95,
                            height:
                                1,
                            color:
                                Colors
                                    .white
                                    .withValues(
                              alpha:
                                  0.055,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left:
                            -15,
                        top:
                            38,
                        child:
                            Transform.rotate(
                          angle:
                              -0.45,
                          child:
                              Container(
                            width:
                                95,
                            height:
                                1,
                            color:
                                Colors
                                    .white
                                    .withValues(
                              alpha:
                                  0.035,
                            ),
                          ),
                        ),
                      ),

                      // =================================
                      // LEVEL
                      // =================================

                      Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          const Text(
                            'LVL',
                            style:
                                TextStyle(
                              color:
                                  Colors
                                      .white54,
                              fontSize:
                                  8,
                              fontWeight:
                                  FontWeight
                                      .w800,
                              letterSpacing:
                                  1.1,
                            ),
                          ),

                          const SizedBox(
                            height:
                                1,
                          ),

                          ShaderMask(
                            shaderCallback:
                                (
                              bounds,
                            ) {
                              return LinearGradient(
                                colors:
                                    colors,
                              ).createShader(
                                bounds,
                              );
                            },

                            child:
                                Text(
                              '$level',

                              style:
                                  const TextStyle(
                                color:
                                    Colors
                                        .white,

                                fontSize:
                                    24,

                                height:
                                    1,

                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HexagonClipper
    extends CustomClipper<Path> {
  @override
  Path getClip(
    Size size,
  ) {
    return Path()
      ..moveTo(
        size.width * 0.5,
        0,
      )
      ..lineTo(
        size.width,
        size.height * 0.25,
      )
      ..lineTo(
        size.width,
        size.height * 0.75,
      )
      ..lineTo(
        size.width * 0.5,
        size.height,
      )
      ..lineTo(
        0,
        size.height * 0.75,
      )
      ..lineTo(
        0,
        size.height * 0.25,
      )
      ..close();
  }

  @override
  bool shouldReclip(
    covariant
        CustomClipper<Path>
        oldClipper,
  ) {
    return false;
  }
}

class _CriticReputationCard
    extends StatelessWidget {
  final int level;
  final String title;
  final VoidCallback? onTap;

  final int xp;
  final int requiredXp;

  final int totalRatings;

  final double titleCoverage;
  final double episodeCoverage;
  final double averageStars;

  const _CriticReputationCard({
    required this.level,
    required this.title,
    required this.xp,
    required this.requiredXp,
    required this.totalRatings,
    required this.titleCoverage,
    required this.episodeCoverage,
    required this.averageStars,
    this.onTap,
  });

  static const Color criticGold =
      Color(
    0xFFFFC857,
  );

  static const Color criticOrange =
      Color(
    0xFFFF8A4C,
  );

  @override
  Widget build(
    BuildContext context,
  ) {
    final progress =
        requiredXp <= 0
            ? 0.0
            : (xp /
                    requiredXp)
                .clamp(
                  0.0,
                  1.0,
                );

    final xpLeft =
        (requiredXp - xp)
            .clamp(
              0,
              requiredXp,
            );

    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap:
          onTap,

      child:
          Container(
        padding:
            const EdgeInsets.all(
          1.2,
        ),

        decoration:
            BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              criticGold,
              criticOrange,
              chipluxPurple,
            ],
          ),

          borderRadius:
              BorderRadius.circular(
            22,
          ),
        ),

        child:
            Container(
          width:
              double.infinity,

          padding:
              const EdgeInsets
                  .fromLTRB(
            17,
            20,
            17,
            17,
          ),

          decoration:
              BoxDecoration(
            color:
                chipluxSurface,

            borderRadius:
                BorderRadius.circular(
              21,
            ),
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .center,

                children: [
                  const SizedBox(
                    width:
                        2,
                  ),

                  _LevelHexBadge(
                    level:
                        level,
                    colors:
                        const [
                      criticGold,
                      criticOrange,
                      chipluxPurple,
                    ],
                  ),

                  const SizedBox(
                    width:
                        16,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        const Text(
                          'CRITIC LEVEL',
                          style:
                              TextStyle(
                            color:
                                Colors
                                    .white38,
                            fontSize:
                                10,
                            fontWeight:
                                FontWeight
                                    .w700,
                            letterSpacing:
                                1.3,
                          ),
                        ),

                        const SizedBox(
                          height:
                              3,
                        ),

                        Text(
                          title
                              .toUpperCase(),
                          maxLines:
                              1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color:
                                criticGold,
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight
                                    .w900,
                            letterSpacing:
                                0.7,
                          ),
                        ),

                        const SizedBox(
                          height:
                              11,
                        ),

                        _CriticProgressBar(
                          progress:
                              progress,
                        ),

                        const SizedBox(
                          height:
                              7,
                        ),

                        Row(
                          children: [
                            Text(
                              '$xp / $requiredXp XP',
                              style:
                                  const TextStyle(
                                color:
                                    Colors
                                        .white54,
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),

                            const Spacer(),

                            Text(
                              '$xpLeft XP left',
                              style:
                                  const TextStyle(
                                color:
                                    Colors
                                        .white70,
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    17,
              ),

              Container(
                height:
                    1,
                color:
                    Colors.white
                        .withValues(
                  alpha:
                      0.06,
                ),
              ),

              const SizedBox(
                height:
                    14,
              ),

              // STATS
              Row(
                children: [
                  Expanded(
                    child:
                        _CriticStat(
                      value:
                          '${titleCoverage.toStringAsFixed(1)}%',
                      label:
                          'Titles Rated',
                    ),
                  ),

                  Expanded(
                    child:
                        _CriticStat(
                      value:
                          '${episodeCoverage.toStringAsFixed(1)}%',
                      label:
                          'Episodes Rated',
                    ),
                  ),

                  Expanded(
                    child:
                        _CriticStat(
                      value:
                          averageStars >
                                  0
                              ? '★ ${averageStars.toStringAsFixed(1)}'
                              : '★ --',
                      label:
                          'Average',
                      valueColor:
                          criticGold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CriticProgressBar
    extends StatefulWidget {
  final double progress;

  const _CriticProgressBar({
    required this.progress,
  });

  @override
  State<_CriticProgressBar>
      createState() =>
          _CriticProgressBarState();
}

class _CriticProgressBarState
    extends State<
        _CriticProgressBar>
    with TickerProviderStateMixin {
  static const criticGold =
      Color(
    0xFFFFC857,
  );

  static const criticOrange =
      Color(
    0xFFFF8A4C,
  );

  late final AnimationController
      _progressController;

  late final AnimationController
      _flowController;

  late Animation<double>
      _progressAnimation;

  @override
  void initState() {
    super.initState();

    _progressController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 900,
      ),
    );

    _progressAnimation =
        Tween<double>(
      begin:
          0,
      end:
          widget.progress,
    ).animate(
      CurvedAnimation(
        parent:
            _progressController,
        curve:
            Curves.easeOutCubic,
      ),
    );

    _flowController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 2200,
      ),
    )..repeat();

    _progressController
        .forward();
  }

  @override
  void didUpdateWidget(
    covariant
        _CriticProgressBar
        oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.progress !=
        widget.progress) {
      final oldProgress =
          _progressAnimation
              .value;

      _progressAnimation =
          Tween<double>(
        begin:
            oldProgress,
        end:
            widget.progress,
      ).animate(
        CurvedAnimation(
          parent:
              _progressController,
          curve:
              Curves.easeOutCubic,
        ),
      );

      _progressController
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height:
          8,

      decoration:
          BoxDecoration(
        color:
            Colors.white10,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        boxShadow: [
          BoxShadow(
            color:
                criticGold
                    .withValues(
              alpha:
                  0.15,
            ),

            blurRadius:
                7,
          ),
        ],
      ),

      clipBehavior:
          Clip.antiAlias,

      child:
          AnimatedBuilder(
        animation:
            Listenable.merge(
          [
            _progressAnimation,
            _flowController,
          ],
        ),

        builder:
            (
          context,
          _,
        ) {
          final flow =
              _flowController
                  .value;

          return Align(
            alignment:
                Alignment.centerLeft,

            child:
                FractionallySizedBox(
              widthFactor:
                  _progressAnimation
                      .value
                      .clamp(
                0.0,
                1.0,
              ),

              heightFactor:
                  1,

              child:
                  Container(
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment(
                      -1.8 +
                          flow *
                              3.6,
                      0,
                    ),

                    end:
                        Alignment(
                      -0.2 +
                          flow *
                              3.6,
                      0,
                    ),

                    colors:
                        const [
                      criticGold,
                      Colors.white,
                      criticOrange,
                      chipluxPurple,
                    ],

                    stops:
                        const [
                      0,
                      0.35,
                      0.65,
                      1,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _progressController
        .dispose();

    _flowController
        .dispose();

    super.dispose();
  }
}

class _CriticStat
    extends StatelessWidget {
  final String value;
  final String label;

  final Color? valueColor;

  const _CriticStat({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          style:
              TextStyle(
            color:
                valueColor ??
                    Colors.white,
            fontSize: 16,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          label,
          style:
              const TextStyle(
            color:
                Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _LevelCard
    extends StatefulWidget {
  final int totalMinutes;
  final String title;
  final VoidCallback? onTap;

  const _LevelCard({
    required this.totalMinutes,
    required this.title,
    this.onTap,
  });

  @override
  State<_LevelCard>
      createState() =>
          _LevelCardState();
}

class _LevelCardState
    extends State<_LevelCard>
    with TickerProviderStateMixin {
  late final AnimationController
      _controller;

  late final AnimationController
      _flowController;

  late Animation<double>
      _progressAnimation;

  int level = 1;
  int minutesInLevel = 0;
  int requiredMinutes = 20;
  int minutesLeft = 20;

  double targetProgress = 0;

  @override
  void initState() {
    super.initState();

    _calculateLevel();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 900,
      ),
    );

    _progressAnimation =
        Tween<double>(
      begin: 0,
      end: targetProgress,
    ).animate(
      CurvedAnimation(
        parent:
            _controller,
        curve:
            Curves.easeOutCubic,
      ),
    );

    _controller.forward();

    _flowController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 2200,
      ),
    )..repeat();
  }

  @override
  void didUpdateWidget(
    covariant _LevelCard oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.totalMinutes !=
        widget.totalMinutes) {
      final oldProgress =
          targetProgress;

      _calculateLevel();

      _progressAnimation =
          Tween<double>(
        begin:
            oldProgress,
        end:
            targetProgress,
      ).animate(
        CurvedAnimation(
          parent:
              _controller,
          curve:
              Curves.easeOutCubic,
        ),
      );

      _controller
        ..reset()
        ..forward();
    }
  }

  void _calculateLevel() {
    level = 1;

    minutesInLevel =
        widget.totalMinutes;

    while (minutesInLevel >=
        level * 20) {
      minutesInLevel -=
          level * 20;

      level++;
    }

    requiredMinutes =
        level * 20;

    minutesLeft =
        requiredMinutes -
            minutesInLevel;

    targetProgress =
        requiredMinutes == 0
            ? 0
            : minutesInLevel /
                requiredMinutes;
  }

  String _formatTimeLeft(
    int totalMinutes,
  ) {
    if (totalMinutes < 60) {
      return '$totalMinutes '
          'minute${totalMinutes == 1 ? '' : 's'}';
    }

    final totalHours =
        totalMinutes ~/ 60;

    final remainingMinutes =
        totalMinutes % 60;

    if (totalHours < 24) {
      if (remainingMinutes ==
          0) {
        return '${totalHours}h';
      }

      return '${totalHours}h '
          '${remainingMinutes}m';
    }

    final totalDays =
        totalHours ~/ 24;

    final remainingHours =
        totalHours % 24;

    if (totalDays < 30) {
      if (remainingHours == 0) {
        return '${totalDays}d';
      }

      return '${totalDays}d '
          '${remainingHours}h';
    }

    final totalMonths =
        totalDays ~/ 30;

    final remainingDays =
        totalDays % 30;

    if (totalMonths < 12) {
      if (remainingDays == 0) {
        return '$totalMonths '
            'month${totalMonths == 1 ? '' : 's'}';
      }

      return '$totalMonths '
          'month${totalMonths == 1 ? '' : 's'} '
          '${remainingDays}d';
    }

    final years =
        totalMonths ~/ 12;

    final remainingMonths =
        totalMonths % 12;

    if (remainingMonths == 0) {
      return '$years '
          'year${years == 1 ? '' : 's'}';
    }

    return '$years '
        'year${years == 1 ? '' : 's'} '
        '$remainingMonths '
        'month${remainingMonths == 1 ? '' : 's'}';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,

      onTap:
          widget.onTap,

      child:
          Container(
        padding:
            const EdgeInsets.all(
          1.2,
        ),

        decoration:
            BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              chipluxCyan,
              chipluxViolet,
              chipluxPurple,
            ],
          ),

          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),

        child:
            Container(
          width:
              double.infinity,

          padding:
              const EdgeInsets
                  .fromLTRB(
            14,
            14,
            14,
            14,
          ),

          decoration:
              BoxDecoration(
            color:
                chipluxSurface,

            borderRadius:
                BorderRadius.circular(
              19,
            ),
          ),

          child:
              Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .center,

            children: [
              // =============================
              // LEVEL
              // =============================

              _LevelHexBadge(
                level:
                    level,

                colors:
                    const [
                  chipluxCyan,
                  chipluxViolet,
                  chipluxPurple,
                ],
              ),

              const SizedBox(
                width:
                    11,
              ),

              // =============================
              // CONTENT
              // =============================

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    const Text(
                      'RUNTIME LEVEL',

                      style:
                          TextStyle(
                        color:
                            Colors
                                .white38,

                        fontSize:
                            9,

                        fontWeight:
                            FontWeight
                                .w700,

                        letterSpacing:
                            1.2,
                      ),
                    ),

                    const SizedBox(
                      height:
                          1,
                    ),

                    Text(
                      widget.title
                          .toUpperCase(),

                      maxLines:
                          1,

                      overflow:
                          TextOverflow
                              .ellipsis,

                      style:
                          const TextStyle(
                        color:
                            chipluxCyan,

                        fontSize:
                            16,

                        fontWeight:
                            FontWeight
                                .w900,

                        letterSpacing:
                            0.6,
                      ),
                    ),

                    const SizedBox(
                      height:
                          7,
                    ),

                    // =============================
                    // PROGRESS
                    // =============================

                    Container(
                      height:
                          8,

                      decoration:
                          BoxDecoration(
                        color:
                            Colors
                                .white10,

                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color:
                                chipluxCyan
                                    .withValues(
                              alpha:
                                  0.13,
                            ),

                            blurRadius:
                                7,
                          ),
                        ],
                      ),

                      clipBehavior:
                          Clip.antiAlias,

                      child:
                          AnimatedBuilder(
                        animation:
                            Listenable
                                .merge(
                          [
                            _progressAnimation,
                            _flowController,
                          ],
                        ),

                        builder:
                            (
                          context,
                          _,
                        ) {
                          final flow =
                              _flowController
                                  .value;

                          return Align(
                            alignment:
                                Alignment
                                    .centerLeft,

                            child:
                                FractionallySizedBox(
                              widthFactor:
                                  _progressAnimation
                                      .value
                                      .clamp(
                                0.0,
                                1.0,
                              ),

                              heightFactor:
                                  1,

                              child:
                                  Container(
                                decoration:
                                    BoxDecoration(
                                  gradient:
                                      LinearGradient(
                                    begin:
                                        Alignment(
                                      -1.8 +
                                          flow *
                                              3.6,
                                      0,
                                    ),

                                    end:
                                        Alignment(
                                      -0.2 +
                                          flow *
                                              3.6,
                                      0,
                                    ),

                                    colors:
                                        const [
                                      chipluxCyan,
                                      Colors
                                          .white,
                                      chipluxViolet,
                                      chipluxPurple,
                                    ],

                                    stops:
                                        const [
                                      0,
                                      0.35,
                                      0.65,
                                      1,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      height:
                          6,
                    ),

                    // =============================
                    // PROGRESS TEXT
                    // =============================

                    Row(
                      children: [
                        Text(
                          '$minutesInLevel / '
                          '$requiredMinutes min',

                          style:
                              const TextStyle(
                            color:
                                Colors
                                    .white54,

                            fontSize:
                                10,

                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          _formatTimeLeft(
                            minutesLeft,
                          ),

                          style:
                              const TextStyle(
                            color:
                                Colors
                                    .white70,

                            fontSize:
                                10,

                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          2,
                    ),

                    Text(
                      'to Level '
                      '${level + 1}',

                      style:
                          const TextStyle(
                        color:
                            Colors
                                .white38,

                        fontSize:
                            9,

                        fontWeight:
                            FontWeight
                                .w500,
                      ),
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

  @override
  void dispose() {
    _controller.dispose();
    _flowController.dispose();

    super.dispose();
  }
}


class _WatchStatCard
    extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _WatchStatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final cleanLabel =
        label.replaceAll(
      '\n',
      ' ',
    );

    return Material(
      color:
          Colors.transparent,

      child:
          InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          15,
        ),

        child:
            Container(
          height:
              58,

          padding:
              const EdgeInsets
                  .symmetric(
            horizontal:
                12,
            vertical:
                8,
          ),

          decoration:
              BoxDecoration(
            color:
                chipluxSurface,

            borderRadius:
                BorderRadius.circular(
              15,
            ),

            border:
                Border.all(
              color:
                  Colors.white
                      .withValues(
                alpha:
                    0.055,
              ),
            ),
          ),

          child:
              Row(
            children: [
              // =========================
              // ICON
              // =========================

              Container(
                width:
                    38,
                height:
                    38,

                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(
                    11,
                  ),

                  color:
                      chipluxCyan
                          .withValues(
                    alpha:
                        0.07,
                  ),

                  border:
                      Border.all(
                    color:
                        chipluxCyan
                            .withValues(
                      alpha:
                          0.13,
                    ),
                  ),
                ),

                child:
                    Center(
                  child:
                      ShaderMask(
                    shaderCallback:
                        (
                      bounds,
                    ) {
                      return const LinearGradient(
                        colors: [
                          chipluxCyan,
                          chipluxViolet,
                          chipluxPurple,
                        ],
                      ).createShader(
                        bounds,
                      );
                    },

                    child:
                        Icon(
                      icon,
                      color:
                          Colors.white,
                      size:
                          20,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              // =========================
              // LABEL
              // =========================

              Expanded(
                child:
                    Text(
                  cleanLabel,

                  maxLines:
                      1,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors
                            .white70,

                    fontSize:
                        13,

                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
              ),

              // =========================
              // VALUE
              // =========================

              Text(
                '$value',

                style:
                    const TextStyle(
                  color:
                      Colors.white,

                  fontSize:
                      21,

                  fontWeight:
                      FontWeight
                          .w800,
                ),
              ),

              // =========================
              // TAP INDICATOR
              // =========================

              if (onTap != null) ...[
                const SizedBox(
                  width:
                      7,
                ),

                const Icon(
                  Icons
                      .chevron_right_rounded,

                  color:
                      Colors.white24,

                  size:
                      19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingStatCard
    extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _RatingStatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  static const Color
      criticGold =
      Color(
    0xFFFFC857,
  );

  static const Color
      criticOrange =
      Color(
    0xFFFF8A4C,
  );

  @override
  Widget build(
    BuildContext context,
  ) {
    final cleanLabel =
        label.replaceAll(
      '\n',
      ' ',
    );

    return Material(
      color:
          Colors.transparent,

      child:
          InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          15,
        ),

        child:
            Container(
          height:
              58,

          padding:
              const EdgeInsets
                  .symmetric(
            horizontal:
                12,
            vertical:
                8,
          ),

          decoration:
              BoxDecoration(
            color:
                chipluxSurface,

            borderRadius:
                BorderRadius.circular(
              15,
            ),

            border:
                Border.all(
              color:
                  criticGold
                      .withValues(
                alpha:
                    0.10,
              ),
            ),
          ),

          child:
              Row(
            children: [
              // =========================
              // ICON
              // =========================

              Container(
                width:
                    38,
                height:
                    38,

                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(
                    11,
                  ),

                  color:
                      criticGold
                          .withValues(
                    alpha:
                        0.065,
                  ),

                  border:
                      Border.all(
                    color:
                        criticGold
                            .withValues(
                      alpha:
                          0.14,
                    ),
                  ),
                ),

                child:
                    Center(
                  child:
                      ShaderMask(
                    shaderCallback:
                        (
                      bounds,
                    ) {
                      return const LinearGradient(
                        colors: [
                          criticGold,
                          criticOrange,
                          chipluxPurple,
                        ],
                      ).createShader(
                        bounds,
                      );
                    },

                    child:
                        Icon(
                      icon,
                      color:
                          Colors.white,
                      size:
                          20,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              // =========================
              // LABEL
              // =========================

              Expanded(
                child:
                    Text(
                  cleanLabel,

                  maxLines:
                      1,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors
                            .white70,

                    fontSize:
                        13,

                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
              ),

              // =========================
              // VALUE
              // =========================

              Text(
                '$value',

                style:
                    const TextStyle(
                  color:
                      criticGold,

                  fontSize:
                      21,

                  fontWeight:
                      FontWeight
                          .w800,
                ),
              ),

              if (onTap != null) ...[
                const SizedBox(
                  width:
                      7,
                ),

                const Icon(
                  Icons
                      .chevron_right_rounded,

                  color:
                      Colors.white24,

                  size:
                      19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() =>
      _EditProfilePageState();
}

class _EditProfilePageState
    extends State<EditProfilePage> {
  final profile = ProfileService.instance;
  final avatarService = AvatarService.instance;

  late final TextEditingController
      displayNameController;

  bool saving = false;
  bool uploadingAvatar = false;

  String? errorMessage;

  Uint8List? selectedAvatarBytes;
  String? selectedAvatarExtension;

  Future<void>
    changeBanner() async {
  await _showProfileBannerPicker(
    context,
  );

  if (!mounted) {
    return;
  }

  setState(() {});
}

  @override
  void initState() {
    super.initState();

    displayNameController =
        TextEditingController(
      text: profile.displayName,
    );
  }

  Future<void> pickAvatar() async {
    try {
      final picker = ImagePicker();

      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (image == null) {
        return;
      }

      final bytes =
          await image.readAsBytes();

      final name =
          image.name.toLowerCase();

      String extension = 'jpg';

      if (name.endsWith('.png')) {
        extension = 'png';
      } else if (name.endsWith('.webp')) {
        extension = 'webp';
      } else if (name.endsWith('.jpeg')) {
        extension = 'jpeg';
      }

      setState(() {
        selectedAvatarBytes = bytes;
        selectedAvatarExtension =
            extension;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        errorMessage =
            'Could not select image: $e';
      });
    }
  }

  Future<void> saveProfile() async {
    final displayName =
        displayNameController.text.trim();

    

    if (displayName.isEmpty) {
      setState(() {
        errorMessage =
            'Display name cannot be empty.';
      });

      return;
    }

    setState(() {
      saving = true;
      errorMessage = null;
    });

    try {
      if (selectedAvatarBytes != null &&
          selectedAvatarExtension != null) {
        setState(() {
          uploadingAvatar = true;
        });

        final avatarUrl =
            await avatarService.uploadAvatar(
          bytes: selectedAvatarBytes!,
          extension:
              selectedAvatarExtension!,
        );

        profile.avatarUrl = avatarUrl;

        setState(() {
          uploadingAvatar = false;
        });
      }

      await profile.updateProfile(
  displayName: displayName,
  username: profile.username,
);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          uploadingAvatar = false;

          if (e
              .toString()
              .contains(
                'profiles_username_unique',
              )) {
            errorMessage =
                'That username is already taken.';
          } else {
            errorMessage =
                'Could not save profile: $e';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Widget buildAvatar() {
    ImageProvider? imageProvider;

    if (selectedAvatarBytes != null) {
      imageProvider =
          MemoryImage(
        selectedAvatarBytes!,
      );
    } else if (profile.avatarUrl != null &&
        profile.avatarUrl!.isNotEmpty) {
      imageProvider =
          NetworkImage(
        profile.avatarUrl!,
      );
    }

    final initial =
        profile.displayName.isNotEmpty
            ? profile.displayName[0]
                .toUpperCase()
            : 'C';

    return GestureDetector(
      onTap: pickAvatar,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  imageProvider == null
                      ? const LinearGradient(
                          colors: [
                            chipluxCyan,
                            chipluxViolet,
                            chipluxPurple,
                          ],
                        )
                      : null,
              image: imageProvider != null
                  ? DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageProvider == null
                ? Center(
                    child: Text(
                      initial,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 34,
              height: 34,
              decoration:
                  const BoxDecoration(
                shape: BoxShape.circle,
                color: chipluxCyan,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.black,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    displayNameController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),

            Center(
              child: Column(
                children: [
                  buildAvatar(),

                  const SizedBox(
                      height: 10),

                  const Text(
                    'Tap to change profile picture',
                    style: TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const SizedBox(
  height: 28,
),

const Align(
  alignment:
      Alignment.centerLeft,
  child: Text(
    'Profile Banner',
    style:
        TextStyle(
      fontSize: 17,
      fontWeight:
          FontWeight.bold,
    ),
  ),
),

const SizedBox(
  height: 10,
),

InkWell(
  onTap:
      changeBanner,
  borderRadius:
      BorderRadius.circular(
    16,
  ),
  child: ClipRRect(
    borderRadius:
        BorderRadius.circular(
      16,
    ),
    child: SizedBox(
      width:
          double.infinity,
      height: 135,
      child: Stack(
        fit:
            StackFit.expand,
        children: [
          if (profile.bannerUrl !=
              null)
            Image.network(
              profile.bannerUrl!,
              fit:
                  BoxFit.cover,
            )
          else
            Container(
              decoration:
                  const BoxDecoration(
                gradient:
                    LinearGradient(
                  colors: [
                    chipluxCyan,
                    chipluxViolet,
                    chipluxPurple,
                  ],
                ),
              ),
            ),

          Container(
            color:
                Colors.black
                    .withValues(
              alpha: 0.30,
            ),
          ),

          const Center(
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  Icons
                      .panorama_outlined,
                  color:
                      Colors.white,
                ),

                SizedBox(
                  width: 8,
                ),

                Text(
                  'Tap to change banner',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
),

const SizedBox(
  height: 30,
),


            const SizedBox(height: 10),

            const SizedBox(
  height: 30,
),

TextField(
  controller:
      displayNameController,

  maxLength:
      40,

  decoration:
      const InputDecoration(
    labelText:
        'Display Name',

    prefixIcon:
        Icon(
      Icons.person_outline,
    ),
  ),
),

const SizedBox(
  height: 10,
),

if (errorMessage != null) ...[
  const SizedBox(
    height: 10,
  ),

  Text(
    errorMessage!,
    style:
        const TextStyle(
      color:
          Colors.redAccent,
    ),
  ),
],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed:
                    saving
                        ? null
                        : saveProfile,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save_outlined,
                      ),
                label: Text(
                  uploadingAvatar
                      ? 'Uploading Avatar...'
                      : saving
                          ? 'Saving...'
                          : 'Save Profile',
                ),
              ),           
            ),        
          ],
        ),
      ),
    );
  }
}

class _EpisodeRatingCard
    extends StatefulWidget {
  final int showId;
  final int seasonNumber;
  final int episodeNumber;

  const _EpisodeRatingCard({
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
  });

  @override
  State<_EpisodeRatingCard>
      createState() =>
          _EpisodeRatingCardState();
}

class _EpisodeRatingCardState
    extends State<
        _EpisodeRatingCard> {
  final critic =
      CriticService.instance;

  int? rating;
int _episodeRatingPulse = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();

    _load();
  }



  Future<void> _load() async {
    final cached =
        critic.getEpisodeRating(
      widget.showId,
      widget.seasonNumber,
      widget.episodeNumber,
    );

    if (cached != null) {
      rating = cached;
      loading = false;

      return;
    }

    try {
      final result =
          await critic
              .loadEpisodeRating(
        widget.showId,
        widget.seasonNumber,
        widget.episodeNumber,
      );

      if (!mounted) return;

      setState(() {
        rating = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  void _setRating(
  double x,
  double width,
) {
  if (width <= 0) {
    return;
  }

  int stars =
      ((x / width) * 5)
          .ceil();

  stars =
      stars.clamp(
    1,
    5,
  ).toInt();

  final int oldStars =
      ((rating ?? 0) / 2)
          .round();

  setState(() {
    if (stars != oldStars) {
      _episodeRatingPulse++;
    }

    rating =
        stars * 2;
  });
}

  Future<void> _save() async {
  final currentRating =
      rating;

  if (currentRating == null) {
    return;
  }

  final int stars =
      ((currentRating / 2)
              .round()
              .clamp(
                1,
                5,
              ))
          .toInt();

  final show =
      LibraryService.instance
          .getItem(
    widget.showId,
    'tv',
  );

  final String showTitle =
      show?.title ??
          'Unknown TV Show';

  try {
    await critic
        .saveEpisodeRating(
      showId:
          widget.showId,
      seasonNumber:
          widget.seasonNumber,
      episodeNumber:
          widget.episodeNumber,
      rating:
          currentRating,
    );

    // Keep only the newest rating
    // activity for this episode.
    try {
      await CommunityService.instance
          .deleteActivity(
        activityType:
            'rated',
        mediaType:
            'tv',
        tmdbId:
            widget.showId,
        seasonNumber:
            widget.seasonNumber,
        episodeNumber:
            widget.episodeNumber,
      );

      await CommunityService.instance
          .tryCreateActivity(
        activityType:
            'rated',
        mediaType:
            'tv',
        tmdbId:
            widget.showId,
        mediaTitle:
            showTitle,
        seasonNumber:
            widget.seasonNumber,
        episodeNumber:
            widget.episodeNumber,
        ratingStars:
            stars,
      );
    } catch (e) {
      debugPrint(
        'Could not update episode rating activity: $e',
      );
    }
  } catch (e) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          'Could not save rating: $e',
        ),
      ),
    );
  }
}

  Future<void> _removeRating() async {
  final oldRating =
      rating;

  if (oldRating == null) {
    return;
  }

  // Empty the stars immediately.
  setState(() {
    rating = null;
  });

  try {
    await critic
        .removeEpisodeRating(
      showId:
          widget.showId,
      seasonNumber:
          widget.seasonNumber,
      episodeNumber:
          widget.episodeNumber,
    );
    try {
  await CommunityService.instance
      .deleteActivity(
    activityType:
        'rated',
    mediaType:
        'tv',
    tmdbId:
        widget.showId,
    seasonNumber:
        widget.seasonNumber,
    episodeNumber:
        widget.episodeNumber,
  );
} catch (e) {
  debugPrint(
    'Could not remove episode rating activity: $e',
  );
}
  } catch (e) {
    if (!mounted) {
      return;
    }

    // Restore rating if
    // deleting failed.
    setState(() {
      rating =
          oldRating;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          'Could not remove rating: $e',
        ),
      ),
    );
  }
}

  @override
  Widget build(
    BuildContext context,
  ) {
    if (loading) {
      return const SizedBox(
        height: 80,
        child: Center(
          child:
              CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            chipluxSurface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          const Text(
            'Your Episode Rating',
            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

         Row(
  children: [
    Expanded(
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final current =
              rating ?? 0;

          final int currentStars =
              (current / 2)
                  .round();

          return GestureDetector(
            behavior:
                HitTestBehavior
                    .opaque,

            onTapDown:
                (details) {
              _setRating(
                details
                    .localPosition
                    .dx,
                constraints
                    .maxWidth,
              );
            },

            onTapUp: (_) {
              unawaited(
                _save(),
              );
            },

            onHorizontalDragStart:
                (details) {
              _setRating(
                details
                    .localPosition
                    .dx,
                constraints
                    .maxWidth,
              );
            },

            onHorizontalDragUpdate:
                (details) {
              _setRating(
                details
                    .localPosition
                    .dx,
                constraints
                    .maxWidth,
              );
            },

            onHorizontalDragEnd:
                (_) {
              unawaited(
                _save(),
              );
            },

            child: SizedBox(
              height: 48,
              child: Row(
                children:
                    List.generate(
                  5,
                  (index) {
                    final int
                        starNumber =
                        index + 1;

                    return Expanded(
                      child: Center(
                        child:
                            _RatingEffectStar(
                          filled:
                              currentStars >=
                                  starNumber,
                          pulseToken:
                              _episodeRatingPulse,
                          size: 36,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ),

    if (rating != null) ...[
      const SizedBox(
        width: 5,
      ),

      IconButton(
        tooltip:
            'Remove rating',
        onPressed: () {
          unawaited(
            _removeRating(),
          );
        },
        icon:
            const Icon(
          Icons
              .delete_outline_rounded,
          color:
              Colors.redAccent,
          size: 23,
        ),
      ),
    ],
  ],
),

          if (rating != null)
            Center(
              child: Text(
                '${(rating! / 2).round()} / 5',
                style:
                    const TextStyle(
                  color:
                      Color(
                    0xFFFFC857,
                  ),
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class MediaDetailsPage
    extends StatefulWidget {
  final int id;
  final String mediaType;

  const MediaDetailsPage({
    super.key,
    required this.id,
    required this.mediaType,
  });

  @override
  State<MediaDetailsPage>
      createState() =>
          _MediaDetailsPageState();
}

class _MediaDetailsPageState
    extends State<MediaDetailsPage> {

      final MediaUserDataService mediaUserDataService =
    MediaUserDataService.instance;

MediaUserData mediaUserData =
    MediaUserData.empty();

final TextEditingController reviewController =
    TextEditingController();

bool mediaUserDataLoading = true;
bool mediaUserDataSaving = false;

  final TmdbService tmdbService =
      TmdbService();

  final LibraryService library =
      LibraryService.instance;

  Map<String, dynamic>? details;

  Map<String, dynamic>?
    featuredPerson;

String? featuredPersonRole;

List<Map<String, dynamic>>
    cast = [];

  bool isLoading = true;
  bool _overviewExpanded = false;
  final GlobalKey _overviewEndKey =
    GlobalKey();
  int _mediaRatingPulse = 0;

  String? errorMessage;

  final Map<int, List<dynamic>>
      loadedEpisodes = {};

  final Set<int> loadingSeasons = {};
  final Set<int> expandedSeasons = {};

  @override
void initState() {
  super.initState();

  loadDetails();
  loadMediaUserData();
}

Future<void>
    _loadFeaturedPerson(
  Map<String, dynamic>
      mediaDetails,
) async {
  try {
    Map<String, dynamic>?
        foundPerson;

    String? foundRole;

    final credits =
        await tmdbService
            .getCredits(
      widget.id,
      widget.mediaType,
    );

    final List<dynamic> crew =
        credits['crew'] ?? [];

        final List<dynamic> rawCast =
    credits['cast'] ?? [];

final loadedCast =
    <Map<String, dynamic>>[];

for (final raw in rawCast) {
  if (raw is! Map) {
    continue;
  }

  loadedCast.add(
    Map<String, dynamic>.from(
      raw,
    ),
  );
}

// TMDB billing order.
loadedCast.sort(
  (a, b) {
    final aOrder =
        a['order'] is num
            ? (a['order'] as num)
                .toInt()
            : 9999;

    final bOrder =
        b['order'] is num
            ? (b['order'] as num)
                .toInt()
            : 9999;

    return aOrder.compareTo(
      bOrder,
    );
  },
);

    Map<String, dynamic>?
        findCrewMember(
      bool Function(
        String job,
      ) matches,
    ) {
      for (final raw
          in crew) {
        if (raw is! Map) {
          continue;
        }

        final person =
            Map<String, dynamic>.from(
          raw,
        );

        final job =
            (person['job'] ??
                    '')
                .toString();

        if (matches(job)) {
          return person;
        }
      }

      return null;
    }

    // =================================
    // MOVIE -> DIRECTOR
    // =================================

    if (widget.mediaType ==
        'movie') {
      foundPerson =
          findCrewMember(
        (job) =>
            job == 'Director',
      );

      if (foundPerson !=
          null) {
        foundRole =
            'Director';
      }
    }

    // =================================
    // TV -> PRODUCER
    // =================================

    if (widget.mediaType ==
        'tv') {
      // Prefer Executive Producer.
      foundPerson =
          findCrewMember(
        (job) =>
            job ==
            'Executive Producer',
      );

      if (foundPerson !=
          null) {
        foundRole =
            'Executive Producer';
      }

      // Then normal Producer.
      foundPerson ??=
          findCrewMember(
        (job) =>
            job == 'Producer',
      );

      if (foundPerson !=
              null &&
          foundRole == null) {
        foundRole =
            'Producer';
      }

      // If TMDB doesn't provide a
      // producer, use the show's creator.
      if (foundPerson ==
          null) {
        final List<dynamic>
            creators =
            mediaDetails[
                    'created_by'] ??
                [];

        if (creators
            .isNotEmpty) {
          final first =
              creators.first;

          if (first is Map) {
            foundPerson =
                Map<String,
                        dynamic>.from(
              first,
            );

            foundRole =
                'Creator';
          }
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
  featuredPerson =
      foundPerson;

  featuredPersonRole =
      foundRole;

  cast =
      loadedCast;
});
  } catch (e) {
    debugPrint(
      'Could not load director/producer: $e',
    );
  }
}

Future<void>
    _scrollToOverviewEnd() async {
  // Wait for AnimatedSize
  // to finish expanding.
  await Future.delayed(
    const Duration(
      milliseconds: 300,
    ),
  );

  if (!mounted) {
    return;
  }

  final targetContext =
    _overviewEndKey
        .currentContext;

if (targetContext == null ||
    !targetContext.mounted) {
  return;
}

await Scrollable.ensureVisible(
  targetContext,
    duration:
        const Duration(
      milliseconds: 350,
    ),
    curve:
        Curves.easeInOutCubic,
    alignment: 0.85,
  );
}

Future<void> loadMediaUserData() async {
  try {
    final result =
        await mediaUserDataService.load(
      widget.id,
      widget.mediaType,
    );

    if (!mounted) return;

    setState(() {
      mediaUserData = result;
      reviewController.text =
          result.review;

      mediaUserDataLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      mediaUserDataLoading = false;
    });
  }
}

Future<void> toggleFavorite() async {
  final newValue =
      !mediaUserData.isFavorite;

  final String mediaTitle =
      (
        details?['title'] ??
        details?['name'] ??
        library
            .getItem(
              widget.id,
              widget.mediaType,
            )
            ?.title ??
        'Unknown'
      ).toString();

  setState(() {
    mediaUserData =
        MediaUserData(
      isFavorite:
          newValue,
      rating:
          mediaUserData.rating,
      review:
          mediaUserData.review,
    );
  });

  try {
    await mediaUserDataService.save(
      tmdbId:
          widget.id,
      mediaType:
          widget.mediaType,
      isFavorite:
          newValue,
      rating:
          mediaUserData.rating,
      review:
          reviewController.text,
    );

    // =====================================
    // COMMUNITY FAVORITE ACTIVITY
    // =====================================

    try {
      // Remove any old favorite event
      // for this title first.
      await CommunityService.instance
          .deleteActivity(
        activityType:
            'favorite',
        mediaType:
            widget.mediaType,
        tmdbId:
            widget.id,
        titleLevelOnly:
            true,
      );

      if (newValue) {
        await CommunityService.instance
            .tryCreateActivity(
          activityType:
              'favorite',
          mediaType:
              widget.mediaType,
          tmdbId:
              widget.id,
          mediaTitle:
              mediaTitle,
        );
      }
    } catch (e) {
      debugPrint(
        'Could not update favorite activity: $e',
      );
    }

    if (newValue &&
        mounted) {
      showFavoriteBurst(
        context,
      );
    }
  } catch (e) {
    if (!mounted) {
      return;
    }

    // Restore previous state if
    // saving the favorite failed.
    setState(() {
      mediaUserData =
          MediaUserData(
        isFavorite:
            !newValue,
        rating:
            mediaUserData.rating,
        review:
            mediaUserData.review,
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          'Could not update favorite: $e',
        ),
      ),
    );
  }
}

Future<void>
    _removeMediaRating() async {
  final oldRating =
      mediaUserData.rating;

  if (oldRating == null) {
    return;
  }

  // Clear it visually first.
  setState(() {
    mediaUserData =
        MediaUserData(
      isFavorite:
          mediaUserData.isFavorite,
      rating: null,
      review:
          mediaUserData.review,
    );
  });

  try {
    await mediaUserDataService
        .save(
      tmdbId:
          widget.id,
      mediaType:
          widget.mediaType,
      isFavorite:
          mediaUserData.isFavorite,

      // NULL = no rating.
      rating: null,

      review:
          reviewController.text,
    );

    // Updates XP, rating counts,
    // Rated state, sorting, etc.
    await CriticService.instance
        .refresh();
        try {
  await CommunityService.instance
    .deleteActivity(
  activityType: 'rated',
  mediaType: widget.mediaType,
  tmdbId: widget.id,
  titleLevelOnly: true,
);
} catch (e) {
  debugPrint(
    'Could not remove rating activity: $e',
  );
}
  } catch (e) {
    if (!mounted) {
      return;
    }

    // Restore rating if saving
    // failed.
    setState(() {
      mediaUserData =
          MediaUserData(
        isFavorite:
            mediaUserData
                .isFavorite,
        rating:
            oldRating,
        review:
            mediaUserData
                .review,
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          'Could not remove rating: $e',
        ),
      ),
    );
  }
}

Future<void> saveMediaUserData() async {
  setState(() {
    mediaUserDataSaving = true;
  });

  try {
    await mediaUserDataService.save(
      tmdbId: widget.id,
      mediaType: widget.mediaType,
      isFavorite:
          mediaUserData.isFavorite,
      rating: mediaUserData.rating,
      review: reviewController.text,
    );

    if (!mounted) return;

    setState(() {
      mediaUserData = MediaUserData(
        isFavorite:
            mediaUserData.isFavorite,
        rating: mediaUserData.rating,
        review:
            reviewController.text.trim(),
      );
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Your rating and notes were saved.',
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          'Could not save: $e',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        mediaUserDataSaving = false;
      });
    }
  }
}

  Future<void> loadDetails() async {
    try {
      final result =
          await tmdbService.getDetails(
        widget.id,
        widget.mediaType,
      );

      if (!mounted) return;

      setState(() {
  details = result;
  isLoading = false;
});

unawaited(
  _loadFeaturedPerson(
    result,
  ),
);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage =
            'Could not load details.';
        isLoading = false;
      });
    }
  }

  Future<void> loadSeason(
    int seasonNumber,
  ) async {
    if (loadedEpisodes
        .containsKey(seasonNumber)) {
      return;
    }

    setState(() {
      loadingSeasons.add(
        seasonNumber,
      );
    });

    try {
      final episodes =
          await tmdbService
              .getSeasonEpisodes(
        widget.id,
        seasonNumber,
      );

      if (!mounted) return;

      setState(() {
        loadedEpisodes[
            seasonNumber] = episodes;

        loadingSeasons.remove(
          seasonNumber,
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingSeasons.remove(
          seasonNumber,
        );
      });
    }
  }

  Widget _buildPersonalMediaSection() {
  if (mediaUserDataLoading) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      ),
    );
  }

  final libraryItem =
    library.getItem(
  widget.id,
  widget.mediaType,
);

final bool canRateOrFavorite =
    libraryItem?.status ==
            'watching' ||
        libraryItem?.status ==
            'completed';

  void setRatingFromPosition(
  double x,
  double width,
) {
  if (width <= 0) {
    return;
  }

  int stars =
      ((x / width) * 5).ceil();

  stars =
      stars.clamp(
    1,
    5,
  ).toInt();

  final int oldStars =
      ((mediaUserData.rating ??
                  0) /
              2)
          .round();

  final int rating =
      stars * 2;

  setState(() {
    // Only trigger another animation
    // when the finger crosses into
    // another star.
    if (stars != oldStars) {
      _mediaRatingPulse++;
    }

    mediaUserData =
        MediaUserData(
      isFavorite:
          mediaUserData.isFavorite,
      rating:
          rating,
      review:
          mediaUserData.review,
    );
  });
}

Future<void> saveRatingNow() async {
  final rating =
      mediaUserData.rating;

  if (rating == null) {
    return;
  }

  final int stars =
      (rating / 2)
          .round()
          .clamp(
            1,
            5,
          );

  final String mediaTitle =
      (
        details?['title'] ??
        details?['name'] ??
        library
            .getItem(
              widget.id,
              widget.mediaType,
            )
            ?.title ??
        'Unknown'
      ).toString();

  try {
    await mediaUserDataService.save(
      tmdbId:
          widget.id,
      mediaType:
          widget.mediaType,
      isFavorite:
          mediaUserData.isFavorite,
      rating:
          rating,
      review:
          mediaUserData.review,
    );

    await CriticService.instance
        .refresh();

    // Keep only the newest rating
    // activity for this title.
    try {
      await CommunityService.instance
    .deleteActivity(
  activityType: 'rated',
  mediaType: widget.mediaType,
  tmdbId: widget.id,
  titleLevelOnly: true,
);

      await CommunityService.instance
          .tryCreateActivity(
        activityType:
            'rated',
        mediaType:
            widget.mediaType,
        tmdbId:
            widget.id,
        mediaTitle:
            mediaTitle,
        ratingStars:
            stars,
      );
    } catch (e) {
      debugPrint(
        'Could not update rating activity: $e',
      );
    }
  } catch (e) {
    debugPrint(
      'Could not save rating: $e',
    );
  }
}

  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: chipluxSurface,
      borderRadius:
          BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // FAVORITES
        Row(
          children: [
            const Expanded(
              child: Text(
                'Add to Favorites',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            IconButton(
              tooltip: mediaUserData
                      .isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              onPressed:
    canRateOrFavorite ||
            mediaUserData.isFavorite
        ? toggleFavorite
        : null,
              icon: TweenAnimationBuilder<
    double>(
  key: ValueKey(
    mediaUserData
        .isFavorite,
  ),
  tween:
      Tween(
    begin: 0.65,
    end: 1.0,
  ),
  duration:
      const Duration(
    milliseconds: 350,
  ),
  curve:
      Curves.elasticOut,
  builder: (
    context,
    scale,
    child,
  ) {
    return Transform.scale(
      scale:
          scale,
      child:
          child,
    );
  },
  child: Icon(
    mediaUserData.isFavorite
        ? Icons.favorite
        : Icons.favorite_border,
    color:
    mediaUserData.isFavorite
        ? Colors.pinkAccent
        : canRateOrFavorite
            ? Colors.white54
            : Colors.white24,
    size: 29,
  ),
),
            ),
          ],
        ),

        const SizedBox(height: 18),

        const Text(
          'Your Rating',
          style: TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),

        if (!canRateOrFavorite) ...[
  const SizedBox(
    height: 5,
  ),

  Text(
    widget.mediaType == 'movie'
        ? 'Mark this movie as Watched to rate or favorite it.'
        : 'Start Watching or complete this show to rate or favorite it.',
    style:
        const TextStyle(
      color:
          Colors.white38,
      fontSize: 11,
    ),
  ),
],

        const SizedBox(height: 10),

        // 5 STAR RATING + REMOVE BUTTON
Row(
  children: [
    Expanded(
      child: LayoutBuilder(
        builder:
            (context, constraints) {
          final currentRating =
              mediaUserData.rating ??
                  0;

          final int currentStars =
              (currentRating / 2)
                  .round();

          return GestureDetector(
            behavior:
                HitTestBehavior.opaque,

            onTapDown:
    canRateOrFavorite
        ? (details) {
            setRatingFromPosition(
              details
                  .localPosition.dx,
              constraints.maxWidth,
            );
          }
        : null,

            onTapUp:
    canRateOrFavorite
        ? (_) async {
            await saveRatingNow();
          }
        : null,

            onHorizontalDragStart:
    canRateOrFavorite
        ? (details) {
              setRatingFromPosition(
                details
                    .localPosition
                    .dx,
                constraints
                    .maxWidth,
              );
                      }
        : null,
            

            onHorizontalDragUpdate:
      canRateOrFavorite
          ? (details) {
              setRatingFromPosition(
                details
                    .localPosition.dx,
                constraints
                    .maxWidth,
              );
            }
          : null,

           onHorizontalDragEnd:
      canRateOrFavorite
          ? (_) async {
              await saveRatingNow();
            }
          : null,

            child: SizedBox(
              height: 52,
              child: Row(
                children:
                    List.generate(
                  5,
                  (index) {
                    final int
                        starNumber =
                        index + 1;

                    return Expanded(
                      child: Center(
                        child:
                            _RatingEffectStar(
  filled:
      currentStars >=
          starNumber,
  pulseToken:
      _mediaRatingPulse,
  size: 38,
  enabled:
      canRateOrFavorite,
),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ),

    if (mediaUserData.rating !=
        null) ...[
      const SizedBox(
        width: 4,
      ),

      IconButton(
        tooltip:
            'Remove rating',
        onPressed: () {
          unawaited(
            _removeMediaRating(),
          );
        },
        icon:
            const Icon(
          Icons
              .delete_outline_rounded,
          color:
              Colors.redAccent,
          size: 23,
        ),
      ),
    ],
  ],
),

        if (mediaUserData.rating !=
            null) ...[
          const SizedBox(height: 4),

          Center(
  child: Text(
    '${(mediaUserData.rating! / 2).round()} / 5',
    style: const TextStyle(
      color: chipluxCyan,
      fontWeight:
          FontWeight.bold,
    ),
  ),
),
        ],
      ],
    ),
  );
}

@override
void dispose() {
  reviewController.dispose();
  super.dispose();
}

  @override
  Widget build(
    BuildContext context,
  ) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null ||
        details == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            errorMessage ??
                'Something went wrong',
          ),
        ),
      );
    }

    final data = details!;

    final title =
        data['title'] ??
        data['name'] ??
        'Unknown';

    final overview =
        data['overview'] ??
        'No description available.';

    final posterPath =
        data['poster_path'];

    final backdropPath =
        data['backdrop_path'];

    final posterUrl =
        posterPath != null
            ? 'https://image.tmdb.org/t/p/w500$posterPath'
            : null;

    final backdropUrl =
        backdropPath != null
            ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
            : null;

    final double rating =
        (data['vote_average'] ?? 0)
            .toDouble();

    final date =
        data['release_date'] ??
        data['first_air_date'] ??
        '';

    final year =
        date.toString().length >= 4
            ? date
                .toString()
                .substring(0, 4)
            : '';

          final String tagline =
    (data['tagline'] ?? '')
        .toString()
        .trim();  

    final List<dynamic> genres =
        data['genres'] ?? [];

        final List<int> genreIds =
    genres
        .map<int?>(
          (genre) {
            final id =
                genre['id'];

            return id is num
                ? id.toInt()
                : null;
          },
        )
        .whereType<int>()
        .toList();

    final List<dynamic> seasons =
    List<dynamic>.from(
  data['seasons'] ?? [],
);

seasons.sort((a, b) {
  final int aNumber =
      a['season_number'] is num
          ? (a['season_number'] as num)
              .toInt()
          : 0;

  final int bNumber =
      b['season_number'] is num
          ? (b['season_number'] as num)
              .toInt()
          : 0;

  // Season 0 = Specials.
  // Always place it last.
  if (aNumber == 0 &&
      bNumber != 0) {
    return 1;
  }

  if (bNumber == 0 &&
      aNumber != 0) {
    return -1;
  }

  return aNumber.compareTo(
    bNumber,
  );
});

    final int totalEpisodes =
        data['number_of_episodes'] ??
            0;

            final int runtimeMinutes =
    widget.mediaType == 'movie' &&
            data['runtime'] is num
        ? (data['runtime'] as num)
            .toInt()
        : 0;

        final String rawShowStatus =
    widget.mediaType == 'tv'
        ? (data['status'] ?? '')
            .toString()
        : '';

String showStatus = rawShowStatus;

Color showStatusColor =
    Colors.white60;

if (widget.mediaType == 'tv') {
  switch (rawShowStatus
      .toLowerCase()) {
    case 'ended':
      showStatus = 'Ended';
      showStatusColor =
          const Color(
        0xFF66E6A8,
      );
      break;

    case 'canceled':
    case 'cancelled':
      showStatus = 'Canceled';
      showStatusColor =
          const Color(
        0xFFFF6B6B,
      );
      break;

    case 'returning series':
    case 'in production':
    case 'planned':
      showStatus = 'Ongoing';
      showStatusColor =
          chipluxCyan;
      break;

    default:
      showStatus =
          rawShowStatus.isEmpty
              ? 'Unknown'
              : rawShowStatus;
      showStatusColor =
          Colors.white60;
  }
}

final int seasonCount =
    widget.mediaType == 'tv' &&
            data[
                'number_of_seasons'] is
                num
        ? (data['number_of_seasons']
                as num)
            .toInt()
        : 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor:
                chipluxBackground,
            flexibleSpace:
                FlexibleSpaceBar(
              background:
                  backdropUrl != null
                      ? Stack(
                          fit: StackFit
                              .expand,
                          children: [
                            Image.network(
                              backdropUrl,
                              fit:
                                  BoxFit.cover,
                            ),
                            const DecoratedBox(
                              decoration:
                                  BoxDecoration(
                                gradient:
                                    LinearGradient(
                                  begin:
                                      Alignment
                                          .topCenter,
                                  end:
                                      Alignment
                                          .bottomCenter,
                                  colors: [
                                    Colors
                                        .transparent,
                                    chipluxBackground,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color:
                              chipluxSurface,
                        ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                      20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                                    15),
                        child:
                            posterUrl != null
                                ? Image
                                    .network(
                                    posterUrl,
                                    width:
                                        125,
                                    height:
                                        188,
                                    fit: BoxFit
                                        .cover,
                                  )
                                : Container(
                                    width:
                                        125,
                                    height:
                                        188,
                                    color:
                                        chipluxSurface,
                                  ),
                      ),

                      const SizedBox(
                          width: 18),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              title,
                              style:
                                  const TextStyle(
                                fontSize:
                                    26,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                                height: 8),

                            Text(
  '$year  •  ${widget.mediaType == 'tv' ? 'TV Show' : 'Movie'}',
  style:
      const TextStyle(
    color:
        Colors.white60,
  ),
),

if (widget.mediaType == 'movie' &&
    tagline.isNotEmpty) ...[
  const SizedBox(height: 8),

  Text(
    '"$tagline"',
    maxLines: 2,
    overflow:
        TextOverflow.ellipsis,
    style: const TextStyle(
      color: Colors.white70,
      fontSize: 13,
      fontStyle:
          FontStyle.italic,
      height: 1.35,
    ),
  ),
],

if (widget.mediaType ==
    'tv') ...[
  const SizedBox(
      height: 7),

  Wrap(
    spacing: 8,
    runSpacing: 5,
    crossAxisAlignment:
        WrapCrossAlignment.center,
    children: [
      Text(
        showStatus,
        style: TextStyle(
          color:
              showStatusColor,
          fontSize: 14,
          fontWeight:
              FontWeight.w700,
        ),
      ),

      const Text(
        '•',
        style: TextStyle(
          color:
              Colors.white38,
          fontSize: 14,
        ),
      ),

      Text(
        '$seasonCount '
        '${seasonCount == 1 ? 'Season' : 'Seasons'}',
        style:
            const TextStyle(
          color:
              Colors.white60,
          fontSize: 14,
          fontWeight:
              FontWeight.w500,
        ),
      ),
    ],
  ),
],

const SizedBox(
    height: 12),

                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color:
                                      Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(
                                    width: 5),
                                Text(
                                  '${rating.toStringAsFixed(1)} / 10',
                                ),
                              ],
                            ),

                            const SizedBox(
                                height: 14),

                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children:
                                  genres.map(
                                (genre) {
                                  return Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal:
                                          9,
                                      vertical:
                                          5,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          chipluxSurface,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  20),
                                    ),
                                    child:
                                        Text(
                                      genre[
                                              'name'] ??
                                          '',
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            11,
                                      ),
                                    ),
                                  );
                                },
                              ).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 24),

                  AnimatedBuilder(
  animation: library,
  builder: (context, _) {
    final item =
        library.getItem(
      widget.id,
      widget.mediaType,
    );

    Future<void> setStatus(
  String status,
) async {
  // Was this title already
  // completed/watched before
  // this button press?
  final bool wasAlreadyCompleted =
      item?.status ==
          'completed';

          final int previousMovieCount =
    library.moviesWatchedCount;

  final newItem =
      LibraryItem(
    id: widget.id,
    mediaType:
        widget.mediaType,
    title:
        title,
    posterPath:
        posterPath,
    year:
        year,
    status:
        status,
    totalEpisodes:
        totalEpisodes,
    runtimeMinutes:
        runtimeMinutes,
    genreIds:
        genreIds,
    addedAt:
        item?.addedAt ??
            DateTime.now()
                .millisecondsSinceEpoch,
  );

  // First actually save the status.
  await library
    .addOrUpdate(
  newItem,
);

if (!context.mounted) {
  return;
}

if (status == 'completed' &&
    !wasAlreadyCompleted) {
  showCompletionBurst(
    context,
  );

  if (widget.mediaType ==
      'movie') {
    await _checkMovieAchievementUnlock(
      context,
      previousCount:
          previousMovieCount,
      currentCount:
          library.moviesWatchedCount,
    );
  }
}
}

    Widget statusButton({
      required String status,
      required String label,
      required IconData icon,
      required Color color,
    }) {
      final selected =
          item?.status ==
              status;

      return Expanded(
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          onTap: () {
            unawaited(
              setStatus(
                status,
              ),
            );
          },
          child: AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            height: 64,
            decoration:
                BoxDecoration(
              color:
                  selected
                      ? color.withValues(
                          alpha: 0.20,
                        )
                      : chipluxSurface,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border:
                  Border.all(
                color:
                    selected
                        ? color
                        : Colors.white
                            .withValues(
                            alpha:
                                0.08,
                          ),
                width:
                    selected
                        ? 1.4
                        : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      selected
                          ? color
                          : Colors
                              .white60,
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    fontSize: 10,
                    fontWeight:
                        selected
                            ? FontWeight
                                .bold
                            : FontWeight
                                .w600,
                    color:
                        selected
                            ? color
                            : Colors
                                .white60,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget removeButton() {
      return SizedBox(
        width: 52,
        height: 64,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          onTap: () {
            unawaited(
              library.remove(
                widget.id,
                widget.mediaType,
              ),
            );
          },
          child: Container(
            decoration:
                BoxDecoration(
              color:
                  chipluxSurface,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border:
                  Border.all(
                color:
                    Colors.redAccent
                        .withValues(
                      alpha:
                          0.55,
                    ),
              ),
            ),
            child:
                const Center(
              child: Icon(
                Icons
                    .delete_outline_rounded,
                color:
                    Colors.redAccent,
                size: 23,
              ),
            ),
          ),
        ),
      );
    }

    // ==========================
    // TV SHOW
    // ==========================

    if (widget.mediaType ==
        'tv') {
      return Row(
        children: [
          statusButton(
            status:
                'watching',
            label:
                'Watching',
            icon:
                Icons
                    .play_circle_outline,
            color:
                chipluxCyan,
          ),

          const SizedBox(
            width: 7,
          ),

          statusButton(
            status:
                'completed',
            label:
                'Completed',
            icon:
                Icons
                    .check_circle_outline,
            color:
                const Color(
              0xFF7BE8A8,
            ),
          ),

          const SizedBox(
            width: 7,
          ),

          statusButton(
            status:
                'plan',
            label:
                'Plan',
            icon:
                Icons
                    .bookmark_border,
            color:
                chipluxPurple,
          ),

          const SizedBox(
            width: 7,
          ),

          statusButton(
            status:
                'dropped',
            label:
                'Dropped',
            icon:
                Icons.close,
            color:
                const Color(
              0xFFFF6B6B,
            ),
          ),

          if (item != null) ...[
            const SizedBox(
              width: 7,
            ),

            removeButton(),
          ],
        ],
      );
    }

    // ==========================
    // MOVIE
    // ==========================

    return Row(
      children: [
        statusButton(
          status:
              'completed',
          label:
              'Watched',
          icon:
              Icons
                  .check_circle_outline,
          color:
              const Color(
            0xFF7BE8A8,
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        statusButton(
          status:
              'plan',
          label:
              'Plan',
          icon:
              Icons
                  .bookmark_border,
          color:
              chipluxPurple,
        ),

        if (item != null) ...[
          const SizedBox(
            width: 8,
          ),

          removeButton(),
        ],
      ],
    );
  },
),

                  AnimatedBuilder(
  animation:
      library,
  builder:
      (context, _) {
    final item =
        library.getItem(
      widget.id,
      widget.mediaType,
    );

    final canComment =
        item?.status ==
            'completed';

    if (!canComment) {
      return const SizedBox
          .shrink();
    }

    return Column(
      children: [
        const SizedBox(
          height: 14,
        ),

        SizedBox(
          width:
              double.infinity,

          child:
              OutlinedButton.icon(
            onPressed:
                () {
              Navigator.push(
                context,

                MaterialPageRoute(
                  builder:
                      (_) =>
                          CommentsPage(

                            onProfileTap:
    (userId) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) =>
              PublicProfilePage(
        userId: userId,
      ),
    ),
  );
},
                    mediaType:
                        widget
                            .mediaType,

                    tmdbId:
                        widget.id,

                    title:
                        title
                            .toString(),

                    imagePath:
                        backdropPath
                            ?.toString(),
                  ),
                ),
              );
            },

            icon:
                const Icon(
              Icons
                  .forum_rounded,
            ),

            label:
    CommentCountLabel(
  mediaType:
      widget.mediaType,

  tmdbId:
      widget.id,
),

            style:
                OutlinedButton
                    .styleFrom(
              foregroundColor:
                  chipluxCyan,

              side:
                  BorderSide(
                color:
                    chipluxCyan
                        .withValues(
                  alpha:
                      0.65,
                ),
              ),

              backgroundColor:
                  chipluxCyan
                      .withValues(
                alpha:
                    0.06,
              ),

              padding:
                  const EdgeInsets
                      .symmetric(
                vertical:
                    14,
              ),

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  },
),

const SizedBox(
  height: 22,
),

AnimatedBuilder(
  animation:
      library,
  builder:
      (context, _) {
    return _buildPersonalMediaSection();
  },
),

const SizedBox(height: 30),

const Text(
  'Overview',
  style: TextStyle(
    fontSize: 21,
    fontWeight:
        FontWeight.bold,
  ),
),

const SizedBox(
  height: 10,
),

LayoutBuilder(
  builder: (
    context,
    constraints,
  ) {
    const overviewStyle =
        TextStyle(
      fontSize: 15,
      height: 1.55,
      color:
          Colors.white70,
    );

    final textPainter =
        TextPainter(
      text:
          TextSpan(
        text:
            overview,
        style:
            overviewStyle,
      ),
      maxLines: 3,
      textDirection:
          TextDirection.ltr,
    )..layout(
        maxWidth:
            constraints.maxWidth,
      );

    final bool needsExpansion =
        textPainter
            .didExceedMaxLines;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .start,
      children: [
        AnimatedSize(
          duration:
              const Duration(
            milliseconds: 280,
          ),
          curve:
              Curves.easeInOutCubic,
          alignment:
              Alignment.topCenter,
          child: Text(
            overview,
            maxLines:
                _overviewExpanded
                    ? null
                    : 3,
            overflow:
                _overviewExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
            style:
                overviewStyle,
          ),
        ),

        if (needsExpansion) ...[
          const SizedBox(
            height: 4,
          ),

          InkWell(
            borderRadius:
                BorderRadius.circular(
              8,
            ),
            onTap: () {
              final bool expanding =
                  !_overviewExpanded;

              setState(() {
                _overviewExpanded =
                    expanding;
              });

              if (expanding) {
                unawaited(
                  _scrollToOverviewEnd(),
                );
              }
            },
            child: Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                vertical: 6,
                horizontal: 2,
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Text(
                    _overviewExpanded
                        ? 'View less'
                        : 'View more',
                    style:
                        const TextStyle(
                      color:
                          chipluxCyan,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    width: 3,
                  ),

                  Icon(
                    _overviewExpanded
                        ? Icons
                            .keyboard_arrow_up_rounded
                        : Icons
                            .keyboard_arrow_down_rounded,
                    color:
                        chipluxCyan,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ],

        SizedBox(
          key:
              _overviewEndKey,
          height: 1,
        ),
      ],
    );
  },
),

// =====================================
// DIRECTOR / PRODUCER
// =====================================

if (featuredPerson !=
        null &&
    featuredPersonRole !=
        null) ...[
  const SizedBox(
    height: 18,
  ),

  _CreatorChip(
    person:
        featuredPerson!,
    role:
        featuredPersonRole!,
    onTap: () {
      final rawId =
          featuredPerson![
              'id'];

      if (rawId is! num) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PersonProjectsPage(
            personId:
                rawId.toInt(),
            personName:
                featuredPerson![
                            'name']
                        ?.toString() ??
                    'Unknown',
            role:
                featuredPersonRole!,
            profilePath:
                featuredPerson![
                        'profile_path']
                    ?.toString(),
          ),
        ),
      );
    },
  ),
],

if (cast.isNotEmpty) ...[
  const SizedBox(
    height: 28,
  ),

  const Text(
    'Top Billed Cast',
    style: TextStyle(
      fontSize: 21,
      fontWeight:
          FontWeight.bold,
    ),
  ),

  const SizedBox(
    height: 14,
  ),

  Builder(
  builder: (context) {
    final textScale =
        MediaQuery.textScalerOf(
      context,
    ).scale(1.0);

    final extraHeight =
        ((textScale - 1.0)
                    .clamp(
              0.0,
              0.5,
            )) *
            30;

    return SizedBox(
      height:
          212 + extraHeight,
      child:
          ListView.separated(
      scrollDirection:
          Axis.horizontal,
      physics:
          const BouncingScrollPhysics(),
      itemCount:
          math.min(
                cast.length,
                8,
              ) +
              (cast.length > 8
                  ? 1
                  : 0),
      separatorBuilder:
          (_, _) =>
              const SizedBox(
        width: 11,
      ),
      itemBuilder:
          (
            context,
            index,
          ) {
        // Last card = View more.
        if (index == 8) {
          return _CastViewMoreCard(
            remaining:
                cast.length - 8,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FullCastPage(
                    title:
                        title.toString(),
                    cast:
                        cast,
                  ),
                ),
              );
            },
          );
        }

        return _TopCastCard(
          person:
              cast[index],
        );
      },
          ),
    );
  },
),
],

                  if (widget.mediaType ==
                          'tv' &&
                      seasons.isNotEmpty) ...[
                    const SizedBox(
                        height: 35),

                    const Text(
                      'Seasons',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                        height: 14),

                    ...seasons.map(
  (season) {
    final int seasonNumber =
        (season['season_number'] as num)
            .toInt();

    final String seasonName =
        season['name'] ??
            'Season $seasonNumber';

    final String? seasonPosterPath =
        season['poster_path']
            ?.toString();

    final String? seasonPosterUrl =
        seasonPosterPath != null &&
                seasonPosterPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w185$seasonPosterPath'
            : null;

    final int episodeCount =
        season['episode_count'] is num
            ? (season['episode_count']
                    as num)
                .toInt()
            : 0;

    return AnimatedBuilder(
      animation: library,
      builder: (context, _) {
        final watched =
            library
                .watchedCountForSeason(
          widget.id,
          seasonNumber,
        );

        final allWatched =
            episodeCount > 0 &&
            watched >= episodeCount;

            final isExpanded =
    expandedSeasons.contains(
  seasonNumber,
);

final showSeasonGreen =
    allWatched && !isExpanded;

        return Container(
          margin:
              const EdgeInsets.only(
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: showSeasonGreen
                ? const Color(
                    0xFF173A29,
                  )
                : chipluxSurface,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: showSeasonGreen
                ? Border.all(
                    color:
                        const Color(
                      0xFF7BE8A8,
                    ).withValues(
                      alpha: 0.20,
                    ),
                  )
                : null,
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets
                    .symmetric(
              horizontal: 16,
              vertical: 5,
            ),
            childrenPadding:
                const EdgeInsets
                    .fromLTRB(
              12,
              0,
              12,
              12,
            ),

            leading: ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              child: seasonPosterUrl !=
                      null
                  ? Image.network(
                      seasonPosterUrl,
                      width: 44,
                      height: 66,
                      fit:
                          BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return Container(
                          width: 44,
                          height: 66,
                          color:
                              chipluxSurfaceLight,
                          child:
                              const Icon(
                            Icons
                                .image_outlined,
                            color: Colors
                                .white38,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 44,
                      height: 66,
                      color:
                          chipluxSurfaceLight,
                      child:
                          const Icon(
                        Icons
                            .image_outlined,
                        color:
                            Colors.white38,
                      ),
                    ),
            ),

            title: Text(
              seasonName,
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                color: showSeasonGreen
                    ? const Color(
                        0xFF7BE8A8,
                      )
                    : Colors.white,
              ),
            ),

            subtitle: Padding(
              padding:
                  const EdgeInsets.only(
                top: 6,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    '$watched / $episodeCount watched',
                    style: TextStyle(
                      color: showSeasonGreen
                          ? const Color(
                              0xFF7BE8A8,
                            )
                          : Colors
                              .white54,
                      fontSize: 12,
                      fontWeight:
                          showSeasonGreen
                              ? FontWeight
                                  .w600
                              : FontWeight
                                  .normal,
                    ),
                  ),

                  const SizedBox(
                      height: 6),

                  ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(8),
                    child:
                        LinearProgressIndicator(
                      value:
                          episodeCount == 0
                              ? 0
                              : (watched /
                                      episodeCount)
                                  .clamp(
                                0.0,
                                1.0,
                              ),
                      minHeight: 4,
                      backgroundColor:
                          chipluxSurfaceLight,
                      color: showSeasonGreen
                          ? const Color(
                              0xFF7BE8A8,
                            )
                          : chipluxCyan,
                    ),
                  ),
                ],
              ),
            ),

            trailing: IconButton(
              tooltip: allWatched
                  ? 'Clear season'
                  : 'Mark season watched',
              onPressed: () async {
                if (!loadedEpisodes
                    .containsKey(
                  seasonNumber,
                )) {
                  await loadSeason(
                    seasonNumber,
                  );
                }

                final episodes =
                    loadedEpisodes[
                        seasonNumber];

                if (episodes == null ||
                    episodes.isEmpty) {
                  return;
                }

                await library
                    .markSeason(
                  widget.id,
                  seasonNumber,
                  episodes,
                  !allWatched,
                );
                if (allWatched) {
  await CriticService.instance
      .clearSeasonAfterUnwatch(
    showId:
        widget.id,
    seasonNumber:
        seasonNumber,
  );

  try {
    await CommunityService.instance
        .deleteActivity(
      activityType:
          'rated',
      mediaType:
          'tv',
      tmdbId:
          widget.id,
      seasonNumber:
          seasonNumber,
    );

    if (library
            .watchedCountForShow(
          widget.id,
        ) ==
        0) {
      await CommunityService.instance
          .deleteActivity(
        activityType:
            'rated',
        mediaType:
            'tv',
        tmdbId:
            widget.id,
        titleLevelOnly:
            true,
      );
    }
  } catch (e) {
    debugPrint(
      'Could not remove season rating activities: $e',
    );
  }
}
              },
              icon: Icon(
                allWatched
                    ? Icons.check_circle
                    : Icons
                        .radio_button_unchecked,
                color: showSeasonGreen
    ? const Color(
        0xFF7BE8A8,
      )
    : Colors.white54,
                size: 28,
              ),
            ),

            onExpansionChanged:
    (expanded) {
  setState(() {
    if (expanded) {
      expandedSeasons.add(
        seasonNumber,
      );
    } else {
      expandedSeasons.remove(
        seasonNumber,
      );
    }
  });

  if (expanded) {
    loadSeason(
      seasonNumber,
    );
  }
},

            children: [
              if (loadingSeasons
                  .contains(
                seasonNumber,
              ))
                const Padding(
                  padding:
                      EdgeInsets.all(25),
                  child:
                      CircularProgressIndicator(),
                ),

              if (loadedEpisodes
                  .containsKey(
                seasonNumber,
              )) ...[
                ...loadedEpisodes[
                        seasonNumber]!
                    .map(
                  (episode) {
                    final int
                        episodeNumber =
                        (episode[
                                    'episode_number']
                                as num)
                            .toInt();

                    return _EpisodeTile(
                      showId:
                          widget.id,
                      seasonNumber:
                          seasonNumber,
                      episodeNumber:
                          episodeNumber,
                      title:
                          episode['name'] ??
                              'Episode',
                      stillPath:
                          episode[
                              'still_path'],
                      runtime:
                          episode['runtime']
                                  is num
                              ? (episode[
                                          'runtime']
                                      as num)
                                  .toInt()
                              : null,
                      rating:
                          episode[
                                      'vote_average']
                                  is num &&
                              (episode[
                                          'vote_average']
                                      as num)
                                  .toDouble() >
                                  0
                              ? (episode[
                                          'vote_average']
                                      as num)
                                  .toDouble()
                              : null,
                      overview:
                          episode[
                                      'overview']
                                  ?.toString() ??
                              '',
                      airDate:
                          episode[
                                  'air_date']
                              ?.toString(),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  },
),
],
                  const SizedBox(
                      height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCastCard
    extends StatelessWidget {
  final Map<String, dynamic>
      person;

  const _TopCastCard({
    required this.person,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final name =
        person['name']
                ?.toString() ??
            'Unknown';

    final character =
        person['character']
                ?.toString() ??
            '';

    final profilePath =
        person['profile_path']
            ?.toString();

    final profileUrl =
        profilePath != null &&
                profilePath
                    .isNotEmpty
            ? 'https://image.tmdb.org/t/p/w185$profilePath'
            : null;

    return SizedBox(
  width: 115,
  child: Material(
    color:
        Colors.transparent,
    child: InkWell(
      borderRadius:
          BorderRadius.circular(
        15,
      ),
      onTap: () {
        final rawId =
            person['id'];

        if (rawId is! num) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PersonProjectsPage(
              personId:
                  rawId.toInt(),
              personName:
                  name,
              role:
                  'Actor',
              profilePath:
                  profilePath,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.all(
              1,
            ),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              gradient:
                  LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  chipluxCyan
                      .withValues(
                    alpha: 0.45,
                  ),
                  chipluxViolet
                      .withValues(
                    alpha: 0.35,
                  ),
                  chipluxPurple
                      .withValues(
                    alpha: 0.40,
                  ),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              child:
                  profileUrl != null
                      ? Image.network(
                          profileUrl,
                          width: 115,
                          height: 150,
                          fit:
                              BoxFit.cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return _castPlaceholder();
                          },
                        )
                      : _castPlaceholder(),
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            name,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          if (character
              .isNotEmpty) ...[
            const SizedBox(
              height: 2,
            ),

            Text(
  'As $character',
  maxLines: 1,
  overflow:
      TextOverflow.ellipsis,
  style:
      const TextStyle(
    color:
        chipluxViolet,
    fontSize: 11,
    fontWeight:
        FontWeight.w500,
  ),
),
          ],
        ],
      ),
    ),
  ),
);
  }

  Widget _castPlaceholder() {
    return Container(
      width: 115,
      height: 150,
      color:
          chipluxSurfaceLight,
      child:
          const Icon(
        Icons.person_outline,
        color:
            Colors.white38,
        size: 35,
      ),
    );
  }
}

class _CastViewMoreCard
    extends StatelessWidget {
  final int remaining;
  final VoidCallback onTap;

  const _CastViewMoreCard({
    required this.remaining,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 115,
      child: Material(
        color:
            Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          onTap:
              onTap,
          child: Container(
            height: 150,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              gradient:
                  LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  chipluxCyan
                      .withValues(
                    alpha: 0.14,
                  ),
                  chipluxViolet
                      .withValues(
                    alpha: 0.18,
                  ),
                  chipluxPurple
                      .withValues(
                    alpha: 0.16,
                  ),
                ],
              ),
              border:
                  Border.all(
                color:
                    chipluxViolet
                        .withValues(
                  alpha: 0.45,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              children: [
                const Icon(
                  Icons
                      .arrow_forward_rounded,
                  color:
                      chipluxCyan,
                  size: 30,
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  'View more',
                  style:
                      TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  '+$remaining',
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FullCastPage
    extends StatelessWidget {
  final String title;

  final List<
          Map<String, dynamic>>
      cast;

  const FullCastPage({
    super.key,
    required this.title,
    required this.cast,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          chipluxBackground,
      appBar: AppBar(
        backgroundColor:
            chipluxBackground,
        title:
            const Text(
          'Full Cast',
        ),
      ),
      body: ChipluxBackground(
        style:
            ChipluxBackgroundStyle
                .discover,
        child: ListView.separated(
          padding:
              const EdgeInsets
                  .fromLTRB(
            20,
            12,
            20,
            30,
          ),
          itemCount:
              cast.length,
          separatorBuilder:
              (_, _) =>
                  const SizedBox(
            height: 9,
          ),
          itemBuilder:
              (
                context,
                index,
              ) {
            final person =
                cast[index];

            final name =
                person['name']
                        ?.toString() ??
                    'Unknown';

            final character =
                person[
                            'character']
                        ?.toString() ??
                    '';

            final profilePath =
                person[
                        'profile_path']
                    ?.toString();

            final profileUrl =
                profilePath !=
                            null &&
                        profilePath
                            .isNotEmpty
                    ? 'https://image.tmdb.org/t/p/w185$profilePath'
                    : null;

            return Material(
  color:
      Colors.transparent,
  child: InkWell(
    borderRadius:
        BorderRadius.circular(
      16,
    ),
    onTap: () {
      final rawId =
          person['id'];

      if (rawId is! num) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PersonProjectsPage(
            personId:
                rawId.toInt(),
            personName:
                name,
            role:
                'Actor',
            profilePath:
                profilePath,
          ),
        ),
      );
    },
    child: Container(
  constraints:
      const BoxConstraints(
    minHeight: 92,
  ),
  padding:
      const EdgeInsets.all(
    8,
  ),
              decoration:
                  BoxDecoration(
                color:
                    chipluxSurface,
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                border:
                    Border.all(
                  color:
                      Colors.white
                          .withValues(
                    alpha: 0.05,
                  ),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                    child:
                        profileUrl !=
                                null
                            ? Image.network(
                                profileUrl,
                                width:
                                    58,
                                height:
                                    76,
                                fit:
                                    BoxFit.cover,
                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return _FullCastPlaceholder();
                                },
                              )
                            : const _FullCastPlaceholder(),
                  ),

                  const SizedBox(
                    width: 13,
                  ),

                  Expanded(
  child: Column(
    mainAxisSize:
        MainAxisSize.min,
    mainAxisAlignment:
        MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          name,
                          maxLines:
                              1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize:
                                15,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        if (character
                            .isNotEmpty) ...[
                          const SizedBox(
                            height: 5,
                          ),

                          Text(
                            character,
                            maxLines:
                                2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white54,
                              fontSize:
                                  12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
                ),
  ),
);
          },
        ),
      ),
    );
  }
}

class _FullCastPlaceholder
    extends StatelessWidget {
  const _FullCastPlaceholder();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 58,
      height: 76,
      color:
          chipluxSurfaceLight,
      child:
          const Icon(
        Icons.person_outline,
        color:
            Colors.white38,
      ),
    );
  }
}

class _CreatorChip
    extends StatelessWidget {
  final Map<String, dynamic>
      person;

  final String role;

  final VoidCallback onTap;

  const _CreatorChip({
    required this.person,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final name =
        person['name']
                ?.toString() ??
            'Unknown';

    final profilePath =
        person['profile_path']
            ?.toString();

    final profileUrl =
        profilePath != null &&
                profilePath
                    .isNotEmpty
            ? 'https://image.tmdb.org/t/p/w185$profilePath'
            : null;

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        onTap:
            onTap,
        child: Container(
          // Gradient frame.
          padding:
              const EdgeInsets.all(
            1.2,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                chipluxCyan,
                chipluxViolet,
                chipluxPurple,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color:
                    chipluxViolet
                        .withValues(
                  alpha:
                      0.10,
                ),
                blurRadius:
                    15,
              ),
            ],
          ),
          child: Container(
  constraints:
      const BoxConstraints(
    minHeight: 68,
  ),
  padding:
      const EdgeInsets
          .symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                17,
              ),

              // Subtle gradient
              // background inside.
              gradient:
                  LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    chipluxCyan
                        .withValues(
                      alpha:
                          0.11,
                    ),
                    chipluxSurface,
                  ),
                  Color.alphaBlend(
                    chipluxViolet
                        .withValues(
                      alpha:
                          0.08,
                    ),
                    chipluxSurface,
                  ),
                  Color.alphaBlend(
                    chipluxPurple
                        .withValues(
                      alpha:
                          0.08,
                    ),
                    chipluxSurface,
                  ),
                ],
              ),
            ),
            child: Row(
              children: [
                // =====================
                // PERSON PHOTO
                // =====================

                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color:
                          chipluxViolet
                              .withValues(
                        alpha:
                            0.55,
                      ),
                      width:
                          1.2,
                    ),
                  ),
                  child:
                      ClipOval(
                    child:
                        profileUrl !=
                                null
                            ? Image.network(
                                profileUrl,
                                fit:
                                    BoxFit
                                        .cover,
                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return const ColoredBox(
                                    color:
                                        chipluxSurfaceLight,
                                    child:
                                        Icon(
                                      Icons
                                          .person_outline,
                                      color:
                                          Colors.white54,
                                    ),
                                  );
                                },
                              )
                            : const ColoredBox(
                                color:
                                    chipluxSurfaceLight,
                                child:
                                    Icon(
                                  Icons
                                      .person_outline,
                                  color:
                                      Colors.white54,
                                ),
                              ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                // =====================
                // ROLE + NAME
                // =====================

                Expanded(
                  child: Column(
  mainAxisSize:
      MainAxisSize.min,
  mainAxisAlignment:
      MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        role
                            .toUpperCase(),
                        style:
                            const TextStyle(
                          color:
                              chipluxCyan,
                          fontSize:
                              9,
                          fontWeight:
                              FontWeight
                                  .w800,
                          letterSpacing:
                              1.2,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        name,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize:
                              15,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      Colors.white54,
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PersonProjectsPage
    extends StatefulWidget {
  final int personId;
  final String personName;
  final String role;
  final String? profilePath;

  const PersonProjectsPage({
    super.key,
    required this.personId,
    required this.personName,
    required this.role,
    this.profilePath,
  });

  @override
  State<PersonProjectsPage>
      createState() =>
          _PersonProjectsPageState();
}

class _PersonProjectsPageState
    extends State<
        PersonProjectsPage> {
  final tmdb =
      TmdbService();

  List<Map<String, dynamic>>
      projects = [];

  bool loading = true;

  String? error;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    try {
      final result =
          await tmdb
              .getPersonCombinedCredits(
        widget.personId,
      );

      final bool isActor =
    widget.role == 'Actor';

final List<dynamic> rawCredits =
    isActor
        ? result['cast'] ?? []
        : result['crew'] ?? [];

final allCredits =
    <Map<String, dynamic>>[];

for (final raw
    in rawCredits) {
  if (raw is! Map) {
    continue;
  }

  final item =
      Map<String, dynamic>.from(
    raw,
  );

  final mediaType =
      item['media_type'];

  if (mediaType !=
          'movie' &&
      mediaType !=
          'tv') {
    continue;
  }

  allCredits.add(
    item,
  );
}

List<Map<String, dynamic>>
    filtered;

      if (isActor) {
  // Acting credits.
  filtered =
      allCredits;
} else if (widget.role ==
    'Director') {
  filtered =
      allCredits.where(
    (item) {
      return item['job']
              ?.toString() ==
          'Director';
    },
  ).toList();
} else if (widget.role
    .contains(
  'Producer',
)) {
  filtered =
      allCredits.where(
    (item) {
      return item['job']
              ?.toString()
              .contains(
                'Producer',
              ) ??
          false;
    },
  ).toList();
} else {
  filtered =
      allCredits;
}

if (filtered.isEmpty) {
  filtered =
      allCredits;
}

      // Remove duplicate projects.
      final seen =
          <String>{};

      filtered =
          filtered.where(
        (item) {
          final rawId =
              item['id'];

          final mediaType =
              item['media_type']
                  ?.toString();

          if (rawId is! num ||
              mediaType == null) {
            return false;
          }

          final key =
              '$mediaType:${rawId.toInt()}';

          return seen.add(
            key,
          );
        },
      ).toList();

      // Newest projects first.
      filtered.sort(
        (a, b) {
          final aDate =
              (a['release_date'] ??
                      a['first_air_date'] ??
                      '')
                  .toString();

          final bDate =
              (b['release_date'] ??
                      b['first_air_date'] ??
                      '')
                  .toString();

          return bDate
              .compareTo(
            aDate,
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        projects =
            filtered;

        loading =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading =
            false;

        error =
            'Could not load projects.';
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final profileUrl =
        widget.profilePath !=
                    null &&
                widget.profilePath!
                    .isNotEmpty
            ? 'https://image.tmdb.org/t/p/w185${widget.profilePath}'
            : null;

    return Scaffold(
      backgroundColor:
          chipluxBackground,
      appBar: AppBar(
        backgroundColor:
            chipluxBackground,
        title:
            const Text(
          'Projects',
        ),
      ),
      body: ChipluxBackground(
        style:
            ChipluxBackgroundStyle
                .discover,
        child: Column(
          children: [
            // ========================
            // PERSON HEADER
            // ========================

            Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                20,
                12,
                20,
                18,
              ),
              child: Row(
                children: [
                  ClipOval(
                    child:
                        profileUrl !=
                                null
                            ? Image.network(
                                profileUrl,
                                width:
                                    58,
                                height:
                                    58,
                                fit:
                                    BoxFit
                                        .cover,
                              )
                            : Container(
                                width:
                                    58,
                                height:
                                    58,
                                color:
                                    chipluxSurfaceLight,
                                child:
                                    const Icon(
                                  Icons
                                      .person_outline,
                                ),
                              ),
                  ),

                  const SizedBox(
                    width: 13,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          widget
                              .personName,
                          style:
                              const TextStyle(
                            fontSize:
                                20,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          widget.role,
                          style:
                              const TextStyle(
                            color:
                                chipluxCyan,
                            fontSize:
                                12,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!loading)
                    Text(
                      '${projects.length}',
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child:
                  loading
                      ? const Center(
                          child:
                              CircularProgressIndicator(),
                        )
                      : error != null
                          ? Center(
                              child:
                                  Text(
                                error!,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.redAccent,
                                ),
                              ),
                            )
                          : projects
                                  .isEmpty
                              ? const Center(
                                  child:
                                      Text(
                                    'No projects found.',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.white54,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets
                                          .fromLTRB(
                                    20,
                                    0,
                                    20,
                                    30,
                                  ),
                                  itemCount:
                                      projects
                                          .length,
                                  separatorBuilder:
                                      (_, _) =>
                                          const SizedBox(
                                    height:
                                        9,
                                  ),
                                  itemBuilder:
                                      (
                                    context,
                                    index,
                                  ) {
                                    return _PersonProjectCard(
                                      project:
                                          projects[
                                              index],
                                    );
                                  },
                                ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonProjectCard
    extends StatelessWidget {
  final Map<String, dynamic>
      project;

  const _PersonProjectCard({
    required this.project,
  });
  

  @override
  Widget build(
    BuildContext context,
  ) {
    final mediaType =
        project['media_type']
                ?.toString() ??
            'movie';

    final title =
        project['title'] ??
            project['name'] ??
            'Unknown';

    final posterPath =
        project['poster_path']
            ?.toString();

    final posterUrl =
        posterPath != null &&
                posterPath
                    .isNotEmpty
            ? 'https://image.tmdb.org/t/p/w185$posterPath'
            : null;

    final date =
        project['release_date'] ??
            project[
                'first_air_date'] ??
            '';

    final year =
        date.toString().length >=
                4
            ? date
                .toString()
                .substring(
              0,
              4,
            )
            : '';

    final rating =
        project['vote_average']
                is num
            ? (project[
                        'vote_average']
                    as num)
                .toDouble()
            : 0.0;

            final character =
    project['character']
            ?.toString()
            .trim() ??
        '';

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        onTap: () {
          final rawId =
              project['id'];

          if (rawId is! num) {
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MediaDetailsPage(
                id:
                    rawId.toInt(),
                mediaType:
                    mediaType,
              ),
            ),
          );
        },
        child: Container(
  constraints:
      const BoxConstraints(
    minHeight: 118,
  ),
  padding:
      const EdgeInsets.all(
    8,
  ),
          decoration:
              BoxDecoration(
            color:
                chipluxSurface,
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border:
                Border.all(
              color:
                  chipluxViolet
                      .withValues(
                alpha:
                    0.12,
              ),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
                child:
                    posterUrl !=
                            null
                        ? Image.network(
                            posterUrl,
                            width:
                                56,
                            height:
                                84,
                            fit:
                                BoxFit
                                    .cover,
                          )
                        : Container(
                            width:
                                56,
                            height:
                                84,
                            color:
                                chipluxSurfaceLight,
                            child:
                                const Icon(
                              Icons
                                  .movie_outlined,
                            ),
                          ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title.toString(),
                      maxLines:
                          2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    if (character.isNotEmpty) ...[
  const SizedBox(
    height: 4,
  ),

  Text(
    'as $character',
    maxLines: 1,
    overflow:
        TextOverflow.ellipsis,
    style:
        const TextStyle(
      color:
          chipluxViolet,
      fontSize: 11,
      fontWeight:
          FontWeight.w500,
    ),
  ),
],

const SizedBox(
  height: 7,
),

Row(
                      children: [
                        Text(
                          mediaType ==
                                  'tv'
                              ? 'TV Show'
                              : 'Movie',
                          style:
                              const TextStyle(
                            color:
                                chipluxCyan,
                            fontSize:
                                11,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),

                        if (year
                            .isNotEmpty) ...[
                          const Text(
                            '  •  ',
                            style:
                                TextStyle(
                              color:
                                  Colors.white30,
                            ),
                          ),

                          Text(
                            year,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white54,
                              fontSize:
                                  11,
                            ),
                          ),
                        ],

                        if (rating >
                            0) ...[
                          const Text(
                            '  •  ',
                            style:
                                TextStyle(
                              color:
                                  Colors.white30,
                            ),
                          ),

                          const Icon(
                            Icons
                                .star_rounded,
                            color:
                                Colors.amber,
                            size:
                                13,
                          ),

                          const SizedBox(
                            width:
                                3,
                          ),

                          Text(
                            rating
                                .toStringAsFixed(
                              1,
                            ),
                            style:
                                const TextStyle(
                              color:
                                  Colors.white54,
                              fontSize:
                                  11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _EpisodeTile
    extends StatelessWidget {
  final int showId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;

  final String? stillPath;
  final int? runtime;
  final double? rating;

  final String overview;
  final String? airDate;

  const _EpisodeTile({
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.stillPath,
    required this.runtime,
    required this.rating,
    required this.overview,
    required this.airDate,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final library =
        LibraryService.instance;

    final stillUrl =
        stillPath != null &&
                stillPath!.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w300$stillPath'
            : null;

    return AnimatedBuilder(
      animation: library,
      builder: (context, _) {
        final watched =
            library.isEpisodeWatched(
          showId,
          seasonNumber,
          episodeNumber,
        );

        return Padding(
          padding:
              const EdgeInsets.only(
            bottom: 8,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius:
                  BorderRadius.circular(
                14,
              ),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SwipeableEpisodePage(
                      showId:
                          showId,
                      seasonNumber:
                          seasonNumber,
                      episodeNumber:
                          episodeNumber,
                      title:
                          title,
                      stillPath:
                          stillPath,
                      runtime:
                          runtime,
                      rating:
                          rating,
                      overview:
                          overview,
                      airDate:
                          airDate,
                    ),
                  ),
                );
              },

              child: Container(
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  color: watched
                      ? const Color(
                          0xFF173A29,
                        )
                      : chipluxSurfaceLight,

                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),

                  border: watched
                      ? Border.all(
                          color:
                              const Color(
                            0xFF7BE8A8,
                          ).withValues(
                            alpha: .22,
                          ),
                        )
                      : null,
                ),

                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),

                      child: stillUrl !=
                              null
                          ? Image.network(
                              stillUrl,
                              width: 88,
                              height: 58,
                              fit:
                                  BoxFit.cover,

                              errorBuilder:
                                  (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return _episodeFallback();
                              },
                            )
                          : _episodeFallback(),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,

                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,

                            style:
                                TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w600,

                              color: watched
                                  ? const Color(
                                      0xFF7BE8A8,
                                    )
                                  : Colors.white,
                            ),
                          ),

                          const SizedBox(
                            height: 7,
                          ),

                          FittedBox(
                            fit:
                                BoxFit.scaleDown,

                            alignment:
                                Alignment.centerLeft,

                            child: Row(
                              mainAxisSize:
                                  MainAxisSize.min,

                              children: [
                                if (runtime !=
                                    null) ...[
                                  const Icon(
                                    Icons
                                        .access_time_rounded,
                                    size: 15,
                                    color:
                                        Colors.white54,
                                  ),

                                  const SizedBox(
                                    width: 4,
                                  ),

                                  Text(
                                    '${runtime}m',
                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white54,
                                    ),
                                  ),
                                ],

                                if (runtime !=
                                        null &&
                                    rating !=
                                        null)
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      '•',
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.white38,
                                      ),
                                    ),
                                  ),

                                if (rating !=
                                    null) ...[
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color:
                                        Colors.amber,
                                  ),

                                  const SizedBox(
                                    width: 4,
                                  ),

                                  Text(
                                    '${rating!.toStringAsFixed(1)}/10',
                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white60,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    IconButton(
                      constraints:
                          const BoxConstraints(
                        minWidth: 34,
                        minHeight: 38,
                      ),

                      padding:
                          EdgeInsets.zero,

                      onPressed: () async {
  final bool wasWatched =
      watched;

  await library.toggleEpisode(
    showId,
    seasonNumber,
    episodeNumber,
    runtimeMinutes:
        runtime ?? 0,
  );

  if (wasWatched) {
    await CriticService.instance
        .clearEpisodeAfterUnwatch(
      showId:
          showId,
      seasonNumber:
          seasonNumber,
      episodeNumber:
          episodeNumber,
    );

    try {
      await CommunityService.instance
          .deleteActivity(
        activityType:
            'rated',
        mediaType:
            'tv',
        tmdbId:
            showId,
        seasonNumber:
            seasonNumber,
        episodeNumber:
            episodeNumber,
      );

      if (library
              .watchedCountForShow(
            showId,
          ) ==
          0) {
        await CommunityService.instance
            .deleteActivity(
          activityType:
              'rated',
          mediaType:
              'tv',
          tmdbId:
              showId,
          titleLevelOnly:
              true,
        );
      }
    } catch (e) {
      debugPrint(
        'Could not remove rating activity: $e',
      );
    }
  }
},

                      icon: Icon(
                        watched
                            ? Icons
                                .check_circle
                            : Icons
                                .radio_button_unchecked,

                        color: watched
                            ? const Color(
                                0xFF7BE8A8,
                              )
                            : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _episodeFallback() {
    return Container(
      width: 88,
      height: 58,

      alignment:
          Alignment.center,

      color:
          chipluxBackground,

      child: Text(
        'S${seasonNumber.toString().padLeft(2, '0')}\n'
        'E${episodeNumber.toString().padLeft(2, '0')}',

        textAlign:
            TextAlign.center,

        style:
            const TextStyle(
          fontSize: 10,
          color:
              chipluxCyan,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}

class SwipeableEpisodePage
    extends StatefulWidget {
  final int showId;
  final int seasonNumber;
  final int episodeNumber;

  final String title;
  final String? stillPath;
  final int? runtime;
  final double? rating;
  final String overview;
  final String? airDate;

  const SwipeableEpisodePage({
    super.key,
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.stillPath,
    required this.runtime,
    required this.rating,
    required this.overview,
    required this.airDate,
  });

  @override
  State<SwipeableEpisodePage>
      createState() =>
          _SwipeableEpisodePageState();
}

class _SwipeableEpisodePageState
    extends State<
        SwipeableEpisodePage> {
  final TmdbService tmdb =
      TmdbService();

  final Map<
          int,
          List<Map<String, dynamic>>>
      _seasonEpisodeCache = {};

  late int _seasonNumber;
  late int _episodeNumber;

  late String _title;
  String? _stillPath;
  int? _runtime;
  double? _rating;
  late String _overview;
  String? _airDate;

  List<int> _seasonNumbers = [];

  bool _hasPrevious = false;
  bool _hasNext = false;

  bool _movingEpisode = false;

  int _transitionDirection = 1;

  @override
  void initState() {
    super.initState();

    _seasonNumber =
        widget.seasonNumber;

    _episodeNumber =
        widget.episodeNumber;

    _title =
        widget.title;

    _stillPath =
        widget.stillPath;

    _runtime =
        widget.runtime;

    _rating =
        widget.rating;

    _overview =
        widget.overview;

    _airDate =
        widget.airDate;

    unawaited(
      _prepareNavigation(),
    );
  }

  Future<void>
      _prepareNavigation() async {
    try {
      final details =
          await tmdb.getDetails(
        widget.showId,
        'tv',
      );

      final rawSeasons =
          details['seasons'];

      final seasonNumbers =
          <int>[];

      if (rawSeasons is List) {
        for (final raw
            in rawSeasons) {
          if (raw is! Map) {
            continue;
          }

          final number =
              raw['season_number'];

          final count =
              raw['episode_count'];

          // Ignore Specials.
          if (number is num &&
              number.toInt() > 0 &&
              count is num &&
              count.toInt() > 0) {
            seasonNumbers.add(
              number.toInt(),
            );
          }
        }
      }

      seasonNumbers.sort();

      _seasonNumbers =
          seasonNumbers;

      await _refreshNavigation();
    } catch (e) {
      debugPrint(
        'Could not prepare episode navigation: $e',
      );
    }
  }

  Future<
          List<Map<String, dynamic>>>
      _episodesForSeason(
    int seasonNumber,
  ) async {
    final cached =
        _seasonEpisodeCache[
            seasonNumber];

    if (cached != null) {
      return cached;
    }

    final rawEpisodes =
        await tmdb
            .getSeasonEpisodes(
      widget.showId,
      seasonNumber,
    );

    final episodes =
        <Map<String, dynamic>>[];

    for (final raw
        in rawEpisodes) {
      if (raw is! Map) {
        continue;
      }

      final episode =
          Map<String, dynamic>.from(
        raw,
      );

      if (episode[
              'episode_number']
          is! num) {
        continue;
      }

      episodes.add(
        episode,
      );
    }

    episodes.sort(
      (a, b) {
        final aNumber =
            (a['episode_number']
                    as num)
                .toInt();

        final bNumber =
            (b['episode_number']
                    as num)
                .toInt();

        return aNumber.compareTo(
          bNumber,
        );
      },
    );

    _seasonEpisodeCache[
            seasonNumber] =
        episodes;

    return episodes;
  }

  Future<void>
      _refreshNavigation() async {
    if (_seasonNumbers
        .isEmpty) {
      return;
    }

    final seasonIndex =
        _seasonNumbers.indexOf(
      _seasonNumber,
    );

    if (seasonIndex < 0) {
      return;
    }

    final episodes =
        await _episodesForSeason(
      _seasonNumber,
    );

    final episodeIndex =
        episodes.indexWhere(
      (episode) {
        final number =
            episode[
                'episode_number'];

        return number is num &&
            number.toInt() ==
                _episodeNumber;
      },
    );

    final hasPrevious =
        episodeIndex > 0 ||
            seasonIndex > 0;

    final hasNext =
        (episodeIndex >= 0 &&
                episodeIndex <
                    episodes.length -
                        1) ||
            seasonIndex <
                _seasonNumbers.length -
                    1;

    if (!mounted) {
      return;
    }

    setState(() {
      _hasPrevious =
          hasPrevious;

      _hasNext =
          hasNext;
    });
  }

  Future<void>
      _moveEpisode(
    int direction,
  ) async {
    if (_movingEpisode ||
        _seasonNumbers.isEmpty) {
      return;
    }

    if (direction < 0 &&
        !_hasPrevious) {
      return;
    }

    if (direction > 0 &&
        !_hasNext) {
      return;
    }

    setState(() {
      _movingEpisode =
          true;
    });

    try {
      int targetSeason =
          _seasonNumber;

      Map<String, dynamic>?
          targetEpisode;

      final currentSeasonIndex =
          _seasonNumbers.indexOf(
        _seasonNumber,
      );

      final currentEpisodes =
          await _episodesForSeason(
        _seasonNumber,
      );

      final currentEpisodeIndex =
          currentEpisodes
              .indexWhere(
        (episode) {
          final number =
              episode[
                  'episode_number'];

          return number is num &&
              number.toInt() ==
                  _episodeNumber;
        },
      );

      // ==========================
      // NEXT EPISODE
      // ==========================

      if (direction > 0) {
        if (currentEpisodeIndex >=
                0 &&
            currentEpisodeIndex <
                currentEpisodes
                        .length -
                    1) {
          targetEpisode =
              currentEpisodes[
                  currentEpisodeIndex +
                      1];
        } else {
          int seasonIndex =
              currentSeasonIndex +
                  1;

          while (seasonIndex <
              _seasonNumbers
                  .length) {
            final season =
                _seasonNumbers[
                    seasonIndex];

            final episodes =
                await _episodesForSeason(
              season,
            );

            if (episodes
                .isNotEmpty) {
              targetSeason =
                  season;

              targetEpisode =
                  episodes.first;

              break;
            }

            seasonIndex++;
          }
        }
      }

      // ==========================
      // PREVIOUS EPISODE
      // ==========================

      if (direction < 0) {
        if (currentEpisodeIndex >
            0) {
          targetEpisode =
              currentEpisodes[
                  currentEpisodeIndex -
                      1];
        } else {
          int seasonIndex =
              currentSeasonIndex -
                  1;

          while (seasonIndex >=
              0) {
            final season =
                _seasonNumbers[
                    seasonIndex];

            final episodes =
                await _episodesForSeason(
              season,
            );

            if (episodes
                .isNotEmpty) {
              targetSeason =
                  season;

              targetEpisode =
                  episodes.last;

              break;
            }

            seasonIndex--;
          }
        }
      }

      if (targetEpisode ==
    null) {
  if (mounted) {
    setState(() {
      _movingEpisode =
          false;
    });
  }

  return;
}

// From this point on,
// the episode is guaranteed
// to exist.
final Map<String, dynamic>
    episode =
    targetEpisode;

final rawEpisodeNumber =
    episode[
        'episode_number'];

      if (rawEpisodeNumber
          is! num) {
        if (mounted) {
          setState(() {
            _movingEpisode =
                false;
          });
        }

        return;
      }

      final rawRuntime =
          episode[
    'runtime'];

      final rawRating =
          episode[
    'vote_average'];

      final double?
          newRating =
          rawRating is num &&
                  rawRating
                          .toDouble() >
                      0
              ? rawRating
                  .toDouble()
              : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _transitionDirection =
            direction;

        _seasonNumber =
            targetSeason;

        _episodeNumber =
            rawEpisodeNumber
                .toInt();

        _title =
    episode[
                'name']
            ?.toString() ??
        'Episode';

        _stillPath =
    episode[
            'still_path']
        ?.toString();

        _runtime =
            rawRuntime is num
                ? rawRuntime
                    .toInt()
                : null;

        _rating =
            newRating;

        _overview =
    episode[
                'overview']
            ?.toString() ??
        '';

        _airDate =
    episode[
            'air_date']
        ?.toString();

        _movingEpisode =
            false;

        // Temporarily reset while
        // availability recalculates.
        _hasPrevious =
            false;

        _hasNext =
            false;
      });

      await _refreshNavigation();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _movingEpisode =
            false;
      });

      debugPrint(
        'Could not change episode: $e',
      );
    }
  }

  void _handleSwipe(
    DragEndDetails details,
  ) {
    final velocity =
        details.primaryVelocity ??
            0;

    // Ignore tiny accidental
    // horizontal movements.
    if (velocity.abs() <
        250) {
      return;
    }

    // Finger moved LEFT.
    if (velocity < 0) {
      unawaited(
        _moveEpisode(
          1,
        ),
      );

      return;
    }

    // Finger moved RIGHT.
    unawaited(
      _moveEpisode(
        -1,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final episodeKey =
        '$_seasonNumber-$_episodeNumber';

    return GestureDetector(
      behavior:
          HitTestBehavior.translucent,
      onHorizontalDragEnd:
          _handleSwipe,
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration:
                const Duration(
              milliseconds: 250,
            ),
            switchInCurve:
                Curves.easeOutCubic,
            switchOutCurve:
                Curves.easeInCubic,
            transitionBuilder:
                (
                  child,
                  animation,
                ) {
              final begin =
                  Offset(
                _transitionDirection >
                        0
                    ? 0.08
                    : -0.08,
                0,
              );

              final position =
                  Tween<Offset>(
                begin:
                    begin,
                end:
                    Offset.zero,
              ).animate(
                animation,
              );

              return FadeTransition(
                opacity:
                    animation,
                child:
                    SlideTransition(
                  position:
                      position,
                  child:
                      child,
                ),
              );
            },
            child:
                EpisodeInfoPage(
              key:
                  ValueKey(
                episodeKey,
              ),
              showId:
                  widget.showId,
              seasonNumber:
                  _seasonNumber,
              episodeNumber:
                  _episodeNumber,
              title:
                  _title,
              stillPath:
                  _stillPath,
              runtime:
                  _runtime,
              rating:
                  _rating,
              overview:
                  _overview,
              airDate:
                  _airDate,

              hasPreviousEpisode:
                  _hasPrevious,

              hasNextEpisode:
                  _hasNext,

              onPreviousEpisode:
                  () {
                unawaited(
                  _moveEpisode(
                    -1,
                  ),
                );
              },

              onNextEpisode:
                  () {
                unawaited(
                  _moveEpisode(
                    1,
                  ),
                );
              },
            ),
          ),

          if (_movingEpisode)
            Positioned(
              top:
                  MediaQuery.paddingOf(
                        context,
                      ).top +
                      12,
              right: 18,
              child:
                  const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EpisodeInfoPage
    extends StatelessWidget {
  final int showId;
  final int seasonNumber;
  final int episodeNumber;

  final bool hasPreviousEpisode;
final bool hasNextEpisode;

final VoidCallback?
    onPreviousEpisode;

final VoidCallback?
    onNextEpisode;

  final String title;
  final String? stillPath;
  final int? runtime;
  final double? rating;
  final String overview;
  final String? airDate;

  const EpisodeInfoPage({
    super.key,
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.hasPreviousEpisode = false,
this.hasNextEpisode = false,
this.onPreviousEpisode,
this.onNextEpisode,
    required this.title,
    required this.stillPath,
    required this.runtime,
    required this.rating,
    required this.overview,
    required this.airDate,
  });

  @override
  Widget build(BuildContext context) {
    final library =
        LibraryService.instance;

    final stillUrl =
        stillPath != null &&
                stillPath!.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w780$stillPath'
            : null;

    final episodeCode =
        'S${seasonNumber.toString().padLeft(2, '0')}'
        'E${episodeNumber.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor:
          chipluxBackground,
      appBar: AppBar(
        backgroundColor:
            chipluxBackground,
        title: Text(
          episodeCode,
        ),
      ),
      body: AnimatedBuilder(
        animation: library,
        builder: (context, _) {
          final watched =
              library
                  .isEpisodeWatched(
            showId,
            seasonNumber,
            episodeNumber,
          );

          return ListView(
            padding:
                const EdgeInsets
                    .fromLTRB(
              20,
              10,
              20,
              40,
            ),
            children: [
              // EPISODE IMAGE
              ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: stillUrl !=
                          null
                      ? Image.network(
                          stillUrl,
                          fit: BoxFit
                              .cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return _infoFallback(
                              episodeCode,
                            );
                          },
                        )
                      : _infoFallback(
                          episodeCode,
                        ),
                ),
              ),

              const SizedBox(
  height: 12,
),

Row(
  children: [
    Expanded(
      child: Align(
        alignment:
            Alignment.centerLeft,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          onTap:
              hasPreviousEpisode
                  ? onPreviousEpisode
                  : null,
          child: Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              vertical: 8,
              horizontal: 4,
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  Icons
                      .chevron_left_rounded,
                  size: 20,
                  color:
                      hasPreviousEpisode
                          ? chipluxCyan
                          : Colors.white24,
                ),

                const SizedBox(
                  width: 2,
                ),

                Text(
                  'Previous episode',
                  style:
                      TextStyle(
                    color:
                        hasPreviousEpisode
                            ? Colors.white60
                            : Colors.white24,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),

    Expanded(
      child: Align(
        alignment:
            Alignment.centerRight,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          onTap:
              hasNextEpisode
                  ? onNextEpisode
                  : null,
          child: Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              vertical: 8,
              horizontal: 4,
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  'Next episode',
                  style:
                      TextStyle(
                    color:
                        hasNextEpisode
                            ? Colors.white60
                            : Colors.white24,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  width: 2,
                ),

                Icon(
                  Icons
                      .chevron_right_rounded,
                  size: 20,
                  color:
                      hasNextEpisode
                          ? chipluxCyan
                          : Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
),

const SizedBox(
  height: 10,
),

              Text(
                episodeCode,
                style:
                    const TextStyle(
                  color:
                      chipluxCyan,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w700,
                  letterSpacing:
                      1.2,
                ),
              ),

              const SizedBox(
                  height: 7),

              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                  height: 14),

              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  if (runtime !=
                      null)
                    _EpisodeInfoMeta(
                      icon: Icons
                          .access_time_rounded,
                      text:
                          '${runtime}m',
                    ),

                  if (rating !=
                      null)
                    _EpisodeInfoMeta(
                      icon:
                          Icons.star,
                      text:
                          '${rating!.toStringAsFixed(1)}/10',
                      iconColor:
                          Colors.amber,
                    ),

                  if (airDate !=
                          null &&
                      airDate!
                          .isNotEmpty)
                    _EpisodeInfoMeta(
                      icon: Icons
                          .calendar_month_outlined,
                      text:
                          airDate!,
                    ),
                ],
              ),

              const SizedBox(
                  height: 24),

              // WATCHED BUTTON
              SizedBox(
                width:
                    double.infinity,
                child:
                    ElevatedButton.icon(
                  onPressed: () async {
  final bool wasWatched =
      watched;

  await library.toggleEpisode(
    showId,
    seasonNumber,
    episodeNumber,
    runtimeMinutes:
        runtime ?? 0,
  );

  if (wasWatched) {
    await CriticService.instance
        .clearEpisodeAfterUnwatch(
      showId:
          showId,
      seasonNumber:
          seasonNumber,
      episodeNumber:
          episodeNumber,
    );

    try {
      await CommunityService.instance
          .deleteActivity(
        activityType:
            'rated',
        mediaType:
            'tv',
        tmdbId:
            showId,
        seasonNumber:
            seasonNumber,
        episodeNumber:
            episodeNumber,
      );

      if (library
              .watchedCountForShow(
            showId,
          ) ==
          0) {
        await CommunityService.instance
            .deleteActivity(
          activityType:
              'rated',
          mediaType:
              'tv',
          tmdbId:
              showId,
          titleLevelOnly:
              true,
        );
      }
    } catch (e) {
      debugPrint(
        'Could not remove rating activity: $e',
      );
    }
  }
},
                  icon: Icon(
                    watched
                        ? Icons
                            .check_circle
                        : Icons
                            .radio_button_unchecked,
                  ),
                  label: Text(
                    watched
                        ? 'Watched'
                        : 'Mark as Watched',
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 14,
                    ),
                    backgroundColor:
    watched
        ? const Color(
            0xFF173A29,
          )
        : chipluxSurface,

foregroundColor:
    watched
        ? const Color(
            0xFF7BE8A8,
          )
        : chipluxCyan,
                  ),
                ),
              ),

              if (watched) ...[
  const SizedBox(
    height: 14,
  ),

  SizedBox(
    width:
        double.infinity,

    child:
        OutlinedButton.icon(
      onPressed:
          () {
        final showTitle =
            library
                    .getItem(
              showId,
              'tv',
            )
                    ?.title ??
                'TV Show';

        Navigator.push(
          context,

          MaterialPageRoute(
            builder:
                (_) =>
                    CommentsPage(

                      onProfileTap:
    (userId) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) =>
              PublicProfilePage(
        userId: userId,
      ),
    ),
  );
},
              mediaType:
                  'episode',

              tmdbId:
                  showId,

              seasonNumber:
                  seasonNumber,

              episodeNumber:
                  episodeNumber,

              title:
                  title,

              subtitle:
                  '$showTitle • $episodeCode',

              imagePath:
                  stillPath,
            ),
          ),
        );
      },

      icon:
          const Icon(
        Icons
            .forum_rounded,
      ),

      label:
    CommentCountLabel(
  mediaType:
      'episode',

  tmdbId:
      showId,

  seasonNumber:
      seasonNumber,

  episodeNumber:
      episodeNumber,
),

      style:
          OutlinedButton
              .styleFrom(
        foregroundColor:
            chipluxCyan,

        side:
            BorderSide(
          color:
              chipluxCyan
                  .withValues(
            alpha:
                0.65,
          ),
        ),

        backgroundColor:
            chipluxCyan
                .withValues(
          alpha:
              0.06,
        ),

        padding:
            const EdgeInsets
                .symmetric(
          vertical:
              14,
        ),

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius
                  .circular(
            15,
          ),
        ),
      ),
    ),
  ),
],

const SizedBox(
  height: 18,
),

_EpisodeRatingCard(
  showId:
      showId,
  seasonNumber:
      seasonNumber,
  episodeNumber:
      episodeNumber,
),

              if (overview
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(
                    height: 30),

                const Text(
                  'Overview',
                  style:
                      TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                    height: 10),

                Text(
                  overview,
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _infoFallback(
    String episodeCode,
  ) {
    return Container(
      alignment:
          Alignment.center,
      color: chipluxSurface,
      child: Text(
        episodeCode,
        style:
            const TextStyle(
          color: chipluxCyan,
          fontSize: 24,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}

class _EpisodeInfoMeta
    extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;

  const _EpisodeInfoMeta({
    required this.icon,
    required this.text,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: iconColor ??
              Colors.white54,
        ),

        const SizedBox(width: 5),

        Text(
          text,
          style:
              const TextStyle(
            color:
                Colors.white60,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

void showFavoriteBurst(
  BuildContext context,
) {
  final overlay =
      Overlay.maybeOf(
    context,
    rootOverlay: true,
  );

  if (overlay == null) {
    return;
  }

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) {
      return IgnorePointer(
        child: Material(
          color:
              Colors.transparent,
          child:
              TweenAnimationBuilder<
                  double>(
            tween: Tween(
              begin: 0,
              end: 1,
            ),
            duration:
                const Duration(
              milliseconds: 850,
            ),
            curve:
                Curves.easeOutCubic,
            builder: (
              context,
              progress,
              child,
            ) {
              final double pop =
                  math.sin(
                progress *
                    math.pi,
              );

              final double fade =
                  (1.0 -
                          ((progress -
                                      0.55) /
                                  0.45)
                              .clamp(
                            0.0,
                            1.0,
                          ))
                      .clamp(
                0.0,
                1.0,
              );

              return Stack(
                fit:
                    StackFit.expand,
                children: [
                  CustomPaint(
                    painter:
                        _FavoriteBurstPainter(
                      progress:
                          progress,
                    ),
                  ),

                  Align(
                    alignment:
                        const Alignment(
                      0,
                      -0.05,
                    ),
                    child: Opacity(
                      opacity:
                          fade,
                      child:
                          Transform.scale(
                        scale:
                            0.45 +
                                pop *
                                    0.85,
                        child:
                            Container(
                          width:
                              110,
                          height:
                              110,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            color:
                                chipluxSurface
                                    .withValues(
                              alpha:
                                  0.92,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors
                                        .pinkAccent
                                        .withValues(
                                  alpha:
                                      0.35,
                                ),
                                blurRadius:
                                    40,
                                spreadRadius:
                                    5,
                              ),
                            ],
                          ),
                          child:
                              const Icon(
                            Icons
                                .favorite_rounded,
                            size:
                                70,
                            color:
                                Colors
                                    .pinkAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );

  overlay.insert(
    entry,
  );

  Future.delayed(
    const Duration(
      milliseconds: 950,
    ),
    () {
      if (entry.mounted) {
        entry.remove();
      }
    },
  );
}

class _FavoriteBurstPainter
    extends CustomPainter {
  final double progress;

  const _FavoriteBurstPainter({
    required this.progress,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center =
        Offset(
      size.width / 2,
      size.height * 0.47,
    );

    final travel =
        Curves.easeOutCubic
            .transform(
      progress,
    );

    final fade =
        (1.0 -
                ((progress - 0.55) /
                        0.45)
                    .clamp(
                  0.0,
                  1.0,
                ))
            .clamp(
      0.0,
      1.0,
    );

    const colors = [
      Colors.pinkAccent,
      Color(0xFFFF5C72),
      Color(0xFFFF8A9A),
      chipluxPurple,
    ];

    const int count = 14;

    for (int i = 0;
        i < count;
        i++) {
      final angle =
          (math.pi *
                  2 /
                  count) *
              i;

      final distance =
          35 +
              travel *
                  (90 +
                      (i % 3) *
                          18);

      final position =
          center +
              Offset(
                math.cos(
                      angle,
                    ) *
                    distance,
                math.sin(
                      angle,
                    ) *
                    distance,
              );

      final paint =
          Paint()
            ..color =
                colors[
                        i %
                            colors
                                .length]
                    .withValues(
              alpha:
                  fade,
            );

      _drawHeart(
        canvas,
        position,
        5.0 +
            (i % 3),
        paint,
      );
    }
  }

  void _drawHeart(
    Canvas canvas,
    Offset center,
    double size,
    Paint paint,
  ) {
    final path =
        Path();

    path.moveTo(
      center.dx,
      center.dy +
          size,
    );

    path.cubicTo(
      center.dx -
          size * 1.5,
      center.dy,
      center.dx -
          size,
      center.dy -
          size,
      center.dx,
      center.dy -
          size * 0.2,
    );

    path.cubicTo(
      center.dx +
          size,
      center.dy -
          size,
      center.dx +
          size * 1.5,
      center.dy,
      center.dx,
      center.dy +
          size,
    );

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant
        _FavoriteBurstPainter
        oldDelegate,
  ) {
    return oldDelegate
            .progress !=
        progress;
  }
}

void showCompletionBurst(
  BuildContext context,
) {
  final overlay =
      Overlay.maybeOf(
    context,
    rootOverlay: true,
  );

  if (overlay == null) {
    return;
  }

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) {
      return IgnorePointer(
        child: Material(
          color:
              Colors.transparent,
          child:
              TweenAnimationBuilder<
                  double>(
            tween: Tween(
              begin: 0,
              end: 1,
            ),
            duration:
                const Duration(
              milliseconds: 950,
            ),
            curve:
                Curves.easeOutCubic,
            builder: (
              context,
              progress,
              child,
            ) {
              final fade =
                  (1.0 -
                          ((progress -
                                      0.60) /
                                  0.40)
                              .clamp(
                            0.0,
                            1.0,
                          ))
                      .clamp(
                0.0,
                1.0,
              );

              return Stack(
                fit:
                    StackFit.expand,
                children: [
                  CustomPaint(
                    painter:
                        _CompletionBurstPainter(
                      progress:
                          progress,
                    ),
                  ),

                  Align(
                    alignment:
                        const Alignment(
                      0,
                      -0.08,
                    ),
                    child: Opacity(
                      opacity:
                          fade,
                      child:
                          Transform.scale(
                        scale:
                            0.65 +
                                math.sin(
                                      progress *
                                          math.pi,
                                    ) *
                                    0.35,
                        child:
                            Container(
                          width: 64,
                          height: 64,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            color:
                                chipluxSurface,
                            border:
                                Border.all(
                              color:
                                  const Color(
                                0xFF7BE8A8,
                              ),
                              width:
                                  2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(
                                  0xFF7BE8A8,
                                ).withValues(
                                  alpha:
                                      0.30,
                                ),
                                blurRadius:
                                    25,
                                spreadRadius:
                                    2,
                              ),
                            ],
                          ),
                          child:
                              const Icon(
                            Icons
                                .check_rounded,
                            color:
                                Color(
                              0xFF7BE8A8,
                            ),
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );

  overlay.insert(
    entry,
  );

  Future.delayed(
    const Duration(
      milliseconds: 1050,
    ),
    () {
      if (entry.mounted) {
        entry.remove();
      }
    },
  );
}

class _CompletionBurstPainter
    extends CustomPainter {
  final double progress;

  const _CompletionBurstPainter({
    required this.progress,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center =
        Offset(
      size.width / 2,
      size.height * 0.46,
    );

    const colors = [
      Color(0xFFFFC857),
      chipluxCyan,
      chipluxViolet,
      chipluxPurple,
      Color(0xFF7BE8A8),
    ];

    final travel =
        Curves.easeOutCubic
            .transform(
      progress,
    );

    final fade =
        (1.0 -
                ((progress - 0.55) /
                        0.45)
                    .clamp(
                  0.0,
                  1.0,
                ))
            .clamp(
      0.0,
      1.0,
    );

    // Expanding ring.
    final ringPaint =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth =
              2
          ..color =
              const Color(
                0xFFFFC857,
              ).withValues(
                alpha:
                    0.45 *
                        fade,
              );

    canvas.drawCircle(
      center,
      25 +
          95 *
              travel,
      ringPaint,
    );

    // Main particles.
    const particleCount =
        28;

    for (int i = 0;
        i < particleCount;
        i++) {
      final angle =
          (math.pi *
                  2 /
                  particleCount) *
              i;

      final variation =
          i.isEven
              ? 1.0
              : 0.72;

      final distance =
          (45 +
                  130 *
                      travel) *
              variation;

      final position =
          center +
              Offset(
                math.cos(
                      angle,
                    ) *
                    distance,
                math.sin(
                      angle,
                    ) *
                    distance,
              );

      final color =
          colors[
              i %
                  colors.length];

      final particlePaint =
          Paint()
            ..color =
                color.withValues(
              alpha:
                  fade,
            );

      final radius =
          i % 3 == 0
              ? 4.0
              : 2.7;

      canvas.drawCircle(
        position,
        radius *
            (1 -
                progress *
                    0.25),
        particlePaint,
      );
    }

    // Shorter inner spark layer.
    const sparkCount =
        14;

    for (int i = 0;
        i < sparkCount;
        i++) {
      final angle =
          (math.pi *
                  2 /
                  sparkCount) *
                  i +
              0.20;

      final distance =
          30 +
              75 *
                  travel;

      final start =
          center +
              Offset(
                math.cos(
                      angle,
                    ) *
                    distance,
                math.sin(
                      angle,
                    ) *
                    distance,
              );

      final end =
          center +
              Offset(
                math.cos(
                      angle,
                    ) *
                    (distance +
                        12),
                math.sin(
                      angle,
                    ) *
                    (distance +
                        12),
              );

      final paint =
          Paint()
            ..strokeWidth =
                2.2
            ..strokeCap =
                StrokeCap.round
            ..color =
                colors[
                        (i + 1) %
                            colors
                                .length]
                    .withValues(
              alpha:
                  0.75 *
                      fade,
            );

      canvas.drawLine(
        start,
        end,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant
        _CompletionBurstPainter
        oldDelegate,
  ) {
    return oldDelegate
            .progress !=
        progress;
  }
}

class _RatingEffectStar
    extends StatefulWidget {
  final bool filled;
  final int pulseToken;
  final double size;
  final bool enabled;

  const _RatingEffectStar({
  required this.filled,
  required this.pulseToken,
  required this.size,
  this.enabled = true,
});

  @override
  State<_RatingEffectStar>
      createState() =>
          _RatingEffectStarState();
}

class _RatingEffectStarState
    extends State<_RatingEffectStar>
    with
        SingleTickerProviderStateMixin {
  late final AnimationController
      _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 260,
      ),
    );
  }

  @override
  void didUpdateWidget(
    covariant _RatingEffectStar
        oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    // Whenever the rating changes,
    // animate every currently
    // filled star.
    if (widget.pulseToken !=
            oldWidget.pulseToken &&
        widget.filled) {
      _controller.forward(
        from: 0,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation:
          _controller,
      builder:
          (
            context,
            child,
          ) {
        final double t =
            _controller.value;

        final double pulse =
            math.sin(
          t * math.pi,
        );

        final double shake =
            math.sin(
                  t *
                      math.pi *
                      5,
                ) *
                (1 - t) *
                2.3;

        final double scale =
            1 +
                pulse *
                    0.18;

        return Transform.translate(
          offset:
              Offset(
            shake,
            0,
          ),
          child:
              Transform.scale(
            scale:
                scale,
            child:
                SizedBox(
              width:
                  widget.size +
                      16,
              height:
                  widget.size +
                      16,
              child: Stack(
                alignment:
                    Alignment.center,
                children: [
                  // Tiny sparkle burst.
                  if (_controller
                      .isAnimating)
                    CustomPaint(
                      size:
                          Size.square(
                        widget.size +
                            16,
                      ),
                      painter:
                          _RatingStarSparkPainter(
                        progress:
                            t,
                      ),
                    ),

                  // Soft glow.
                  if (widget.filled)
                    Container(
                      width:
                          widget.size *
                              0.62,
                      height:
                          widget.size *
                              0.62,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape
                                .circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.amber
                                    .withValues(
                              alpha:
                                  0.10 +
                                      pulse *
                                          0.28,
                            ),
                            blurRadius:
                                13 +
                                    pulse *
                                        7,
                            spreadRadius:
                                pulse *
                                    2,
                          ),
                        ],
                      ),
                    ),

                  Icon(
                    widget.filled
                        ? Icons
                            .star_rounded
                        : Icons
                            .star_border_rounded,
                    size:
                        widget.size,
                    color:
    widget.filled
        ? Colors.amber
        : widget.enabled
            ? Colors.amber
            : Colors.white24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RatingStarSparkPainter
    extends CustomPainter {
  final double progress;

  const _RatingStarSparkPainter({
    required this.progress,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center =
        Offset(
      size.width / 2,
      size.height / 2,
    );

    final double opacity =
        math.sin(
              progress *
                  math.pi,
            ) *
            0.85;

    final double distance =
        17 +
            progress *
                9;

    const colors = [
      Color(
        0xFFFFC857,
      ),
      Colors.amber,
      Colors.white,
    ];

    for (int i = 0;
        i < 6;
        i++) {
      final angle =
          (math.pi * 2 / 6) *
              i;

      final point =
          center +
              Offset(
                math.cos(
                      angle,
                    ) *
                    distance,
                math.sin(
                      angle,
                    ) *
                    distance,
              );

      final paint =
          Paint()
            ..color =
                colors[
                        i %
                            colors
                                .length]
                    .withValues(
              alpha:
                  opacity,
            );

      canvas.drawCircle(
        point,
        1.8 *
            (1 -
                progress *
                    0.35),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant
        _RatingStarSparkPainter
        oldDelegate,
  ) {
    return oldDelegate
            .progress !=
        progress;
  }
}