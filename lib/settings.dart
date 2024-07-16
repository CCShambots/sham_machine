import 'package:sham_states/services/ip_address_util.dart';

class Settings {
  static const String repositoryLink =
      'https://github.com/Gold872/elastic-dashboard';
  static const String releasesLink = '$repositoryLink/releases/latest';

  static IPAddressMode ipAddressMode = IPAddressMode.driverStation;

  static String ipAddress = '127.0.0.1';
  static int teamNumber = 9999;

  static double defaultPeriod = 0.06;
  static double defaultGraphPeriod = 0.033;
}

class PrefKeys {
  static String ipAddress = 'ip_address';
  static String ipAddressMode = 'ip_address_mode';
  static String teamNumber = 'team_number';
  static String defaultPeriod = 'default_period';
  static String defaultGraphPeriod = 'default_graph_period';

}
