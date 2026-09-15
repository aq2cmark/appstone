// Web driver entrypoint for running integration_test/*.dart in a real
// browser via `flutter drive`. See README notes in integration_test/ for the
// exact commands (web devices aren't supported by `flutter test -d chrome`
// directly, so this driver is required for Chrome/Edge runs).
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
