import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/tournaments_provider.dart';

class MatchSheetPdf {
  static Future<void> printMatchSheet(Tournament tournament, TournamentMatch match) async {
    final homeTeam = tournament.teams.firstWhere(
      (t) => t.id == match.homeTeamId,
      orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '', primaryColor: '', secondaryColor: '', players: []),
    );
    final awayTeam = tournament.teams.firstWhere(
      (t) => t.id == match.awayTeamId,
      orElse: () => TournamentTeam(id: '', name: 'TBD', logoUrl: '', primaryColor: '', secondaryColor: '', players: []),
    );

    final homeLineup = match.lineups.firstWhere(
      (l) => l.teamId == homeTeam.id,
      orElse: () => MatchLineup(teamId: homeTeam.id, startingXI: [], substitutes: [], formation: '—', submittedAt: DateTime.now()),
    );
    final awayLineup = match.lineups.firstWhere(
      (l) => l.teamId == awayTeam.id,
      orElse: () => MatchLineup(teamId: awayTeam.id, startingXI: [], substitutes: [], formation: '—', submittedAt: DateTime.now()),
    );

    final doc = pw.Document();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Center(
            child: pw.Text(tournament.name,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text('${tournament.sport.toUpperCase()} · ${tournament.location}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 12),

          // Match title
          pw.Center(
            child: pw.Text('${homeTeam.name}  vs  ${awayTeam.name}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              '${match.venue}  ·  ${match.date.day}/${match.date.month}/${match.date.year}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          ),
          if (match.refereeName.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text('Referee: ${match.refereeName}',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ),
          ],
          pw.SizedBox(height: 20),

          // Score box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text(homeTeam.name,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text(
                  match.status == 'completed'
                      ? '${match.homeScore}  –  ${match.awayScore}'
                      : '__  –  __',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(awayTeam.name,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Lineups side by side
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _buildLineupColumn(homeTeam.name, homeLineup)),
              pw.SizedBox(width: 20),
              pw.Expanded(child: _buildLineupColumn(awayTeam.name, awayLineup)),
            ],
          ),
          pw.SizedBox(height: 20),

          // Scorers & cards (if completed)
          if (match.status == 'completed') ...[
            pw.Divider(),
            pw.SizedBox(height: 8),
            if (match.scorers.isNotEmpty) ...[
              pw.Text('Goals', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              ...match.scorers.map((s) => pw.Text('• $s',
                style: const pw.TextStyle(fontSize: 11))),
              pw.SizedBox(height: 10),
            ],
            if (match.cards.isNotEmpty) ...[
              pw.Text('Cards', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              ...match.cards.map((c) => pw.Text('• $c',
                style: const pw.TextStyle(fontSize: 11))),
              pw.SizedBox(height: 10),
            ],
            if (match.motm != null && match.motm!.isNotEmpty) ...[
              pw.Text('Man of the Match: ${match.motm}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ],
          ],

          pw.Spacer(),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Home Team Signature: ___________________',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              pw.Text('Away Team Signature: ___________________',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text('Referee Signature: ___________________',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text('Generated by Skorio · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
          ),
        ],
      ),
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static pw.Widget _buildLineupColumn(String teamName, MatchLineup lineup) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(teamName,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 2),
        pw.Text('Formation: ${lineup.formation}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 6),
        pw.Text('Starting XI',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        if (lineup.startingXI.isEmpty)
          pw.Text('Not submitted', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500))
        else
          ...lineup.startingXI.asMap().entries.map((e) =>
            pw.Text('${e.key + 1}. ${e.value}', style: const pw.TextStyle(fontSize: 10))),
        if (lineup.substitutes.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('Substitutes',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          ...lineup.substitutes.map((s) => pw.Text('• $s', style: const pw.TextStyle(fontSize: 10))),
        ],
      ],
    );
  }
}
