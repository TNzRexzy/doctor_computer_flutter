import 'dart:io';

void main() {
  final lines = File('analyze_output.txt').readAsLinesSync();
  for (var line in lines) {
    if (line.contains('invalid_constant') || line.contains('const_with_non_const')) {
      final parts = line.split(' - ');
      if (parts.length >= 3) {
        final location = parts[parts.length - 2].trim();
        final locParts = location.split(':');
        if (locParts.length == 3) {
          final file = locParts[0];
          final lineNum = int.parse(locParts[1]);
          
          final f2 = File(file);
          if (f2.existsSync()) {
            final fileLines = f2.readAsLinesSync();
            final targetLine = fileLines[lineNum - 1];
            fileLines[lineNum - 1] = targetLine.replaceAll('const ', '');
            f2.writeAsStringSync(fileLines.join('\n'));
          }
        }
      }
    }
  }
}
