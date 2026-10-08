import 'package:flutter/material.dart';

import 'services/data_export_service.dart';

const Color _exportBackground = Color(0xFF07111C);
const Color _exportSurface = Color(0xFF111D2A);
const Color _exportSurfaceLight = Color(0xFF162536);
const Color _exportCyan = Color(0xFF43E8FF);
const Color _exportViolet = Color(0xFF8B7CFF);
const Color _exportPurple = Color(0xFFD65CFF);

class DataExportPage extends StatefulWidget {
  const DataExportPage({super.key});

  @override
  State<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends State<DataExportPage> {
  final service = DataExportService.instance;

  String cadence = 'off';
  bool loading = true;
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    cadence = await service.getCadence();

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  String _label(String value) {
    switch (value) {
      case 'daily':
        return 'Every day';
      case 'weekly':
        return 'Every week';
      case 'monthly':
        return 'Every month';
      default:
        return 'Off';
    }
  }

  Future<void> _change() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _exportSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _gradientTitle(
                  'Automatic backup',
                  fontSize: 21,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Choose how often Chiplux should create a local JSON backup.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                for (final option in const [
                  'off',
                  'daily',
                  'weekly',
                  'monthly',
                ])
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 8,
                    ),
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(
                          sheetContext,
                          option,
                        );
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: option == cadence
                              ? _exportCyan.withValues(
                                  alpha: 0.08,
                                )
                              : _exportSurfaceLight,
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: option == cadence
                                ? _exportCyan
                                    .withValues(
                                      alpha: 0.40,
                                    )
                                : Colors.white
                                    .withValues(
                                      alpha: 0.05,
                                    ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _label(option),
                                style: TextStyle(
                                  fontWeight:
                                      option == cadence
                                          ? FontWeight
                                              .bold
                                          : FontWeight
                                              .w500,
                                ),
                              ),
                            ),
                            if (option == cadence)
                              const Icon(
                                Icons
                                    .check_circle_rounded,
                                color: _exportCyan,
                                size: 20,
                              ),
                          ],
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

    if (value == null) {
      return;
    }

    await service.setCadence(value);

    if (mounted) {
      setState(() {
        cadence = value;
      });
    }
  }

  Future<void> _export() async {
    if (exporting) {
      return;
    }

    setState(() {
      exporting = true;
    });

    try {
      await service.exportAndShare();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not export data: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          exporting = false;
        });
      }
    }
  }

  Widget _gradientTitle(
    String text, {
    double fontSize = 28,
  }) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            _exportCyan,
            _exportViolet,
            _exportPurple,
          ],
        ).createShader(bounds);
      },
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(1.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _exportCyan.withValues(alpha: 0.42),
            _exportViolet.withValues(alpha: 0.24),
            _exportPurple.withValues(alpha: 0.30),
          ],
        ),
      ),
      child: Material(
        color: _exportSurface,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(13),
                    gradient:
                        const LinearGradient(
                      colors: [
                        _exportCyan,
                        _exportViolet,
                      ],
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: _exportBackground,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white38,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _exportBackground,

      // Back arrow only. Avoid the duplicated white page title.
      appBar: AppBar(
        backgroundColor: _exportBackground,
        elevation: 0,
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                35,
              ),
              children: [
                _gradientTitle('Data & Export'),
                const SizedBox(height: 5),
                const Text(
                  'Back up your Chiplux account data or create an export whenever you want.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _exportSurface,
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: 0.06,
                      ),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons
                            .shield_outlined,
                        color: _exportCyan,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Exports include your profile settings, library, '
                          'watched episodes, ratings, comments, activity, '
                          'following list, notifications, reports and '
                          'blocked-user list.',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _actionCard(
                  icon: Icons.download_rounded,
                  title: 'Export now',
                  subtitle:
                      'Create a JSON backup and choose where to save or share it.',
                  onTap:
                      exporting ? null : _export,
                  trailing: exporting
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                _actionCard(
                  icon: Icons.schedule_rounded,
                  title: 'Automatic backup',
                  subtitle: cadence == 'off'
                      ? 'Off'
                      : '${_label(cadence)} while Chiplux is being used',
                  onTap: _change,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _exportViolet.withValues(
                      alpha: 0.05,
                    ),
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: _exportViolet.withValues(
                        alpha: 0.14,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Automatic backups are checked when Chiplux opens. '
                    'If an interval passed while the app was closed, '
                    'the backup is created the next time the app starts.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
