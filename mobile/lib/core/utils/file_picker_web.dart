import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web-only implementation of file picking via a browser <input type="file"> element.
Future<List<int>?> pickImageFromWeb() async {
  final completer = Completer<List<int>?>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..style.display = 'none';

  html.document.body!.append(input);

  input.onChange.listen((event) async {
    final file = input.files?.first;
    if (file == null) {
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoad.listen((_) {
      final result = reader.result as List<int>;
      completer.complete(result);
    });
    reader.onError.listen((_) {
      completer.complete(null);
    });
  });

  input.click();

  // Clean up the element after picking (or cancel)
  Future.delayed(const Duration(minutes: 1), () {
    input.remove();
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}
