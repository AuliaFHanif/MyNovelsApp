import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/server_config_service.dart';
import '../../services/reader_auth_service.dart';
import 'reader_login_screen.dart';

class ReaderSettingsScreen extends StatefulWidget {
  const ReaderSettingsScreen({super.key});

  @override
  State<ReaderSettingsScreen> createState() => _ReaderSettingsScreenState();
}

class _ReaderSettingsScreenState extends State<ReaderSettingsScreen> {
  final _urlController = TextEditingController();
  bool _urlDirty = false;
  bool _saving = false;
  bool _testing = false;
  String? _saveError;
  String? _saveSuccess;
  _ConnectionStatus _connectionStatus = _ConnectionStatus.unknown;

  @override
  void initState() {
    super.initState();
    final config = ServerConfigService();
    _urlController.text = config.url;
    _urlController.addListener(() {
      setState(() {
        _urlDirty = _urlController.text.trim() != config.url;
        _saveError = null;
        _saveSuccess = null;
        _connectionStatus = _ConnectionStatus.unknown;
      });
    });
    // Run an initial connection test
    _runTest();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    setState(() {
      _testing = true;
      _connectionStatus = _ConnectionStatus.unknown;
    });
    final ok = await ServerConfigService().testConnection();
    if (mounted) {
      setState(() {
        _testing = false;
        _connectionStatus = ok ? _ConnectionStatus.ok : _ConnectionStatus.error;
      });
    }
  }

  Future<void> _saveUrl() async {
    setState(() {
      _saving = true;
      _saveError = null;
      _saveSuccess = null;
    });

    final error = await ServerConfigService().setUrl(_urlController.text);

    if (mounted) {
      setState(() {
        _saving = false;
        if (error != null) {
          _saveError = error;
          _connectionStatus = _ConnectionStatus.error;
        } else {
          _saveSuccess = 'Connected and saved!';
          _urlDirty = false;
          _connectionStatus = _ConnectionStatus.ok;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ReaderAuthService>();
    final config = context.watch<ServerConfigService>();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      body: Row(
        children: [
          // ─── Left nav panel ───
          Container(
            width: 220,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    color: const Color(0xFF6B6B6B),
                    tooltip: 'Back',
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Text(
                    'Settings',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                _SideNavItem(label: 'Server', icon: Icons.dns_outlined),
                _SideNavItem(label: 'Account', icon: Icons.person_outline),
                _SideNavItem(label: 'About', icon: Icons.info_outline),
              ],
            ),
          ),

          // ─── Right content ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Server section ───
                    _SectionTitle(title: 'Server Connection'),
                    const SizedBox(height: 6),
                    Text(
                      'The address of your PocketBase server. Use your Tailscale IP to share with friends.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF6B6B6B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Connection status banner
                    _ConnectionBanner(
                      status: _connectionStatus,
                      testing: _testing,
                      url: config.url,
                    ),
                    const SizedBox(height: 20),

                    // URL field
                    _SettingsLabel(label: 'Server URL'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _urlController,
                            style: GoogleFonts.robotoMono(
                              fontSize: 13,
                              color: const Color(0xFF1A1A1A),
                            ),
                            decoration: InputDecoration(
                              hintText: 'http://100.x.x.x:8090',
                              hintStyle: GoogleFonts.robotoMono(
                                fontSize: 13,
                                color: const Color(0xFFBDBDBD),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0DED8),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0DED8),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF1A1A1A),
                                  width: 1.5,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                color: const Color(0xFF9E9E9E),
                                tooltip: 'Copy URL',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _urlController.text),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('URL copied'),
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Test button
                        OutlinedButton(
                          onPressed: _testing ? null : _runTest,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            foregroundColor: const Color(0xFF6B6B6B),
                            side: const BorderSide(color: Color(0xFFE0DED8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _testing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                )
                              : Text(
                                  'Test',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                        ),
                      ],
                    ),

                    // Error / success messages
                    if (_saveError != null) ...[
                      const SizedBox(height: 12),
                      _InlineMessage(message: _saveError!, isError: true),
                    ],
                    if (_saveSuccess != null) ...[
                      const SizedBox(height: 12),
                      _InlineMessage(message: _saveSuccess!, isError: false),
                    ],

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: (_saving || !_urlDirty) ? null : _saveUrl,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A1A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            disabledBackgroundColor: const Color(0xFFE0DED8),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Save & Connect',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        if (!config.isDefaultUrl) ...[
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () async {
                              await ServerConfigService().resetToDefault();
                              _urlController.text = ServerConfigService().url;
                              setState(() {
                                _urlDirty = false;
                                _saveError = null;
                                _saveSuccess = null;
                                _connectionStatus = _ConnectionStatus.unknown;
                              });
                              _runTest();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF9E9E9E),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              'Reset to default',
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Tailscale tip
                    _TipBox(
                      icon: Icons.tips_and_updates_outlined,
                      text:
                          'Sharing with friends? Use your Tailscale IP (e.g. http://100.x.x.x:8090). '
                          'Everyone needs to be on your Tailscale network to connect.',
                    ),

                    const SizedBox(height: 48),
                    const Divider(color: Color(0xFFF0EEE9)),
                    const SizedBox(height: 48),

                    // ─── Account section ───
                    _SectionTitle(title: 'Account'),
                    const SizedBox(height: 20),

                    if (auth.isLoggedIn) ...[
                      _AccountCard(
                        username: auth.username,
                        email: auth.email,
                        onLogout: () => auth.logout(),
                      ),
                    ] else ...[
                      Text(
                        'You\'re browsing as a guest. Sign in to sync your followed series across devices.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF6B6B6B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReaderLoginScreen(),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1A1A),
                          side: const BorderSide(color: Color(0xFF1A1A1A)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Sign in or create account',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 48),
                    const Divider(color: Color(0xFFF0EEE9)),
                    const SizedBox(height: 48),

                    // ─── About section ───
                    _SectionTitle(title: 'About'),
                    const SizedBox(height: 20),
                    _AboutRow(label: 'App', value: 'Novel Reader'),
                    _AboutRow(label: 'Version', value: '1.0.0'),
                    _AboutRow(
                      label: 'Built with',
                      value: 'Flutter + PocketBase',
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Connection banner
// ─────────────────────────────────────────

enum _ConnectionStatus { unknown, ok, error }

class _ConnectionBanner extends StatelessWidget {
  final _ConnectionStatus status;
  final bool testing;
  final String url;

  const _ConnectionBanner({
    required this.status,
    required this.testing,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    if (testing) {
      return _BannerShell(
        bg: const Color(0xFFF5F4F1),
        border: const Color(0xFFE0DED8),
        icon: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Color(0xFF6B6B6B),
          ),
        ),
        text: 'Testing connection…',
        textColor: const Color(0xFF6B6B6B),
      );
    }

    switch (status) {
      case _ConnectionStatus.ok:
        return _BannerShell(
          bg: const Color(0xFFF0FDF4),
          border: const Color(0xFFBBF7D0),
          icon: const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Color(0xFF16A34A),
          ),
          text: 'Connected to $url',
          textColor: const Color(0xFF16A34A),
        );
      case _ConnectionStatus.error:
        return _BannerShell(
          bg: const Color(0xFFFFF1F0),
          border: const Color(0xFFFFCCC7),
          icon: const Icon(
            Icons.error_outline,
            size: 16,
            color: Color(0xFFCF1322),
          ),
          text: 'Cannot reach $url',
          textColor: const Color(0xFFCF1322),
        );
      case _ConnectionStatus.unknown:
        return const SizedBox.shrink();
    }
  }
}

class _BannerShell extends StatelessWidget {
  final Color bg;
  final Color border;
  final Widget icon;
  final String text;
  final Color textColor;

  const _BannerShell({
    required this.bg,
    required this.border,
    required this.icon,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Account card
// ─────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final String? username;
  final String? email;
  final VoidCallback onLogout;

  const _AccountCard({
    required this.username,
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0EEE9)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF1A1A1A),
            child: Text(
              (username ?? email ?? 'U')[0].toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (username != null)
                  Text(
                    username!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                if (email != null)
                  Text(
                    email!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCF1322),
              side: const BorderSide(color: Color(0xFFFFCCC7)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Sign out', style: GoogleFonts.inter(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────

class _SideNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SideNavItem({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon, size: 18, color: const Color(0xFF6B6B6B)),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A1A1A),
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  final String label;
  const _SettingsLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1A1A1A),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final String message;
  final bool isError;
  const _InlineMessage({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F0) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? const Color(0xFFFFCCC7) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 15,
            color: isError ? const Color(0xFFCF1322) : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isError
                    ? const Color(0xFFCF1322)
                    : const Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0DED8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF6B6B6B),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF9E9E9E),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
