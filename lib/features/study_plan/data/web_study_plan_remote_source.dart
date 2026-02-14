import 'package:flutter/foundation.dart';

import '../../../core/network/eios_endpoints.dart';
import '../../schedule/schedule_service.dart';
import '../models.dart';
import '../parser.dart';
import 'study_plan_remote_source.dart';

List<StudyPlanItem> _parseStudyPlan(String html) => StudyPlanParser.parse(html);

class WebStudyPlanRemoteSource implements StudyPlanRemoteSource {
  final ScheduleService _service;

  WebStudyPlanRemoteSource({ScheduleService? service})
    : _service = service ?? ScheduleService();

  @override
  Future<List<StudyPlanItem>> fetchItems() async {
    final html = await _service.loadPage(EiosEndpoints.studyPlan);
    final parsed = await compute(_parseStudyPlan, html);
    parsed.sort((a, b) {
      final s = a.semester.compareTo(b.semester);
      if (s != 0) return s;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return parsed;
  }
}
