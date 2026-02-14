enum AppDataSource { web, api }

class AppDataSourceConfig {
  static const _raw = String.fromEnvironment(
    'APP_DATA_SOURCE',
    defaultValue: 'web',
  );

  static AppDataSource get current {
    switch (_raw.trim().toLowerCase()) {
      case 'api':
        return AppDataSource.api;
      case 'web':
      default:
        return AppDataSource.web;
    }
  }
}

T selectDataSource<T>({
  required T web,
  required T api,
}) {
  return AppDataSourceConfig.current == AppDataSource.api ? api : web;
}
