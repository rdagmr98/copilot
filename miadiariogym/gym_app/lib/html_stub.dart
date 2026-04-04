// Questo file serve a "ingannare" il compilatore Android
class Window {
  Location location = Location();
  History history = History();
}

class Location {
  String href = "";
  String pathname = "";
}

class History {
  void replaceState(dynamic data, String title, String url) {}
}

Window window = Window();
