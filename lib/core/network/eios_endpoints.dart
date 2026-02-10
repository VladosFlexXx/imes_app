class EiosEndpoints {
  EiosEndpoints._();

  static const String base = 'https://eos.imes.su';

  static const String my = '$base/my/';
  static const String userEdit = '$base/user/edit.php';

  static const String scheduleBase = '$base/mod/page/view.php?id=41428';
  static const String scheduleChanges = '$base/mod/page/view.php?id=56446';

  static const String gradesOverview = '$base/grade/report/overview/index.php';
  static const String notificationsWeb =
      '$base/message/output/popup/notifications.php';
}
