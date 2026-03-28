import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const UnlockerApp());

class UnlockerApp extends StatelessWidget {
  const UnlockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFF00F2FF),
      ),
      home: const UnlockerPage(),
    );
  }
}

class UnlockerPage extends StatefulWidget {
  const UnlockerPage({super.key});

  @override
  State<UnlockerPage> createState() => _UnlockerPageState();
}

class _UnlockerPageState extends State<UnlockerPage> {
  final TextEditingController _idController = TextEditingController();
  String _generatedKey = "----";

  void _calculateKey() {
    final String input = _idController.text;
    if (input.length == 4) {
      int? idNum = int.tryParse(input);
      if (idNum != null) {
        // Formula sincronizzata con l'app cliente: (ID * 2) + 567
        int key = (idNum * 2) + 566;
        setState(() => _generatedKey = key.toString());
        HapticFeedback.mediumImpact();
      }
    } else {
      setState(() => _generatedKey = "----");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KEY GENERATOR UNLOCKGYM PT"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "INSERISCI DEVICE ID CLIENTE",
              style: TextStyle(
                color: Colors.white24,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _idController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 4,
              onChanged: (_) => _calculateKey(),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00F2FF),
              ),
              decoration: const InputDecoration(
                counterText: "",
                hintText: "0000",
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 50),
            const Icon(Icons.vpn_key_rounded, color: Colors.white10, size: 40),
            const SizedBox(height: 10),
            Text(
              _generatedKey,
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w100,
                letterSpacing: 10,
              ),
            ),
            const SizedBox(height: 40),
            if (_generatedKey != "----")
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedKey));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Copiato!"),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text("COPIA CODICE"),
              ),
          ],
        ),
      ),
    );
  }
}
