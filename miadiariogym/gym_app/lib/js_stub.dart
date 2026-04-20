// Stub for dart:js on non-web platforms
class JsObject {
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
  dynamic callMethod(String name, [List<dynamic>? args]) => null;
}

final JsObject context = JsObject();
