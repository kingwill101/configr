import 'package:get_it/get_it.dart';

final di = GetIt.instance;

class DryRunFlag {
  final bool value;
  const DryRunFlag(this.value);
}
