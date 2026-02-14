import 'package:flutter/foundation.dart';

import '../../../core/network/eios_endpoints.dart';
import '../../schedule/schedule_service.dart';
import '../models.dart';
import '../parser.dart';
import 'recordbook_remote_source.dart';

List<RecordbookGradebook> _parseRecordbook(String html) =>
    RecordbookParser.parse(html);

class WebRecordbookRemoteSource implements RecordbookRemoteSource {
  final ScheduleService _service;

  WebRecordbookRemoteSource({ScheduleService? service})
    : _service = service ?? ScheduleService();

  @override
  Future<List<RecordbookGradebook>> fetchGradebooks() async {
    final html = await _service.loadPage(EiosEndpoints.recordbook);
    final parsed = await compute(_parseRecordbook, html);
    parsed.sort((a, b) => a.number.compareTo(b.number));
    for (final g in parsed) {
      g.semesters.sort((a, b) => a.semester.compareTo(b.semester));
    }
    return parsed;
  }
}
