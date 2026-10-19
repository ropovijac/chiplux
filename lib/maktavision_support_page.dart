import 'package:flutter/material.dart';
import 'theme/chiplux_palette.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Branded support contacts. These mailboxes must be created on maktavision.com
/// before this feature is published. The existing in-app bug reports are kept.
class MaktavisionSupportPage extends StatelessWidget {
  const MaktavisionSupportPage({super.key});

  static const _background = chipluxBackground;
  static const _surface = chipluxSurface;
  static const _accent = chipluxGold;

  Future<void> _contact(
    BuildContext context, {
    required String address,
    required String subject,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query: Uri(queryParameters: {'subject': subject}).query,
    );

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Fall through to the copyable address for phones without mail apps.
    }

    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No email app was found. Copied $address.')),
    );
  }

  Widget _contactRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String address,
    required String subject,
  }) {
    return Card(
      color: _surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(icon, color: _accent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$subtitle\n$address',
            style: const TextStyle(color: Colors.white70, height: 1.5)),
        isThreeLine: true,
        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
        onTap: () => _contact(context, address: address, subject: subject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final croatian = Localizations.localeOf(context).languageCode == 'hr';
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text(croatian ? 'Maktavision podrška' : 'Maktavision Support'),
        backgroundColor: _background,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Icon(Icons.support_agent_rounded, size: 45, color: _accent),
            const SizedBox(height: 14),
            Text(
              croatian
                  ? 'Kako ti možemo pomoći?'
                  : 'How can we help?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              croatian
                  ? 'Odaberi temu i otvori svoju aplikaciju za e-poštu.'
                  : 'Choose a topic to open your email application.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            _contactRow(
              context,
              icon: Icons.mail_outline_rounded,
              title: croatian ? 'Opća podrška' : 'General support',
              subtitle: croatian ? 'Pomoć s aplikacijom i računom' : 'App and account questions',
              address: 'support@maktavision.com',
              subject: '[Chiplux] Support request',
            ),
            _contactRow(
              context,
              icon: Icons.bug_report_outlined,
              title: croatian ? 'Prijavi grešku' : 'Report a bug',
              subtitle: croatian ? 'Tehnički problemi i greške' : 'Technical problems and crashes',
              address: 'bugs@maktavision.com',
              subject: '[Chiplux] Bug report',
            ),
            _contactRow(
              context,
              icon: Icons.flag_outlined,
              title: croatian ? 'Prijavi sadržaj ili korisnika' : 'Report content or a user',
              subtitle: croatian ? 'Sigurnost, sadržaj i moderiranje' : 'Safety, content and moderation',
              address: 'reports@maktavision.com',
              subject: '[Chiplux] Content or user report',
            ),
            const SizedBox(height: 18),
            Text(
              croatian
                  ? 'Prijave grešaka i sadržaja unutar aplikacije i dalje rade kao prije. Adrese e-pošte dostupne su nakon što se poštanski sandučići aktiviraju.'
                  : 'Existing in-app bug and content reporting remains available. Email delivery requires these mailboxes to be activated before release.',
              style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
