// Stub for dart:js on non-web platforms
class JsObject {
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
}

final JsObject context = JsObject();
