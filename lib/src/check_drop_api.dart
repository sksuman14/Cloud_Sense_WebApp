import 'package:desktop_drop/desktop_drop.dart';

void foo(DropDoneDetails details) async {
  for (final file in details.files) {
    final bytes = await file.readAsBytes();
    final name = file.name;
    final length = await file.length();
  }
}
