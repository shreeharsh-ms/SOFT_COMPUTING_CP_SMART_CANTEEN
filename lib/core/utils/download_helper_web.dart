// ignore_for_file: avoid_web_libraries_in_flutter
import "dart:convert";
import "dart:html" as html;

void downloadFile(String filename, String content, {String mimeType = "text/html"}) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void printReceipt() {
  html.window.print();
}
