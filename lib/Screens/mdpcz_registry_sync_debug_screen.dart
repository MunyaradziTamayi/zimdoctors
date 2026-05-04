import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zimdoctors/services/mdpcz_registry_sync_service.dart';
import 'package:zimdoctors/services/verified_doctors_excel_import_service.dart';

class MdpczRegistrySyncDebugScreen extends StatefulWidget {
  static const String id = '/mdpcz_registry_sync_debug';

  const MdpczRegistrySyncDebugScreen({super.key});

  @override
  State<MdpczRegistrySyncDebugScreen> createState() =>
      _MdpczRegistrySyncDebugScreenState();
}

class _MdpczRegistrySyncDebugScreenState
    extends State<MdpczRegistrySyncDebugScreen> {
  final _svc = MdpczRegistrySyncService();
  final _excelImport = VerifiedDoctorsExcelImportService();

  bool _running = false;
  String? _status;
  String? _error;

  Future<void> _runSync() async {
    if (_running) return;

    if (!kDebugMode) {
      setState(() {
        _status = null;
        _error = 'This screen is only available in debug builds.';
      });
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _status = 'Starting...';
    });

    try {
      final res = await _svc.syncAll(
        onProgress: ({
          required int page,
          required int? lastPage,
          required int entriesFetched,
          required int entriesUpsertedSoFar,
        }) {
          if (!mounted) return;
          setState(() {
            final lp = lastPage == null ? '?' : '$lastPage';
            _status =
                'Page $page / $lp • fetched $entriesFetched • upserted $entriesUpsertedSoFar';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _status =
            'Done: pages=${res.pagesFetched}, upserted=${res.entriesUpserted}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _running = false);
    }
  }

  Future<void> _importExcel() async {
    if (_running) return;

    if (!kDebugMode) {
      setState(() {
        _status = null;
        _error = 'This screen is only available in debug builds.';
      });
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _status = 'Importing Excel...';
    });

    try {
      final res = await _excelImport.importIntoFirestore();
      if (!mounted) return;
      setState(() {
        _status =
            'Excel import done: rows=${res.rowsRead}, upserted=${res.entriesUpserted}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'MDPCZ Registry Sync (Debug)',
          style: GoogleFonts.inter(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Runs a one-time scrape of https://mdpcz.co.zw/public_register '
              'and upserts documents into Firestore collection `mdpcz_registry`.',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _running ? null : _runSync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF57E659),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  _running ? 'Syncing...' : 'Run Sync',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _running ? null : _importExcel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.file_open),
                label: Text(
                  'Import verifiedDoctors.xlsx',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_status != null)
              Text(
                _status!,
                style: GoogleFonts.inter(color: Colors.white),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: GoogleFonts.inter(color: Colors.orangeAccent),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'After sync:',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '- Check Firestore collection `mdpcz_registry`\n'
              '- Docs are keyed by normalized registration number\n'
              '- Doctor signup verification requires BOTH: full name + registration number',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
