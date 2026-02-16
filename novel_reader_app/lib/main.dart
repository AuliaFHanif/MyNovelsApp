import 'package:flutter/material.dart';
import 'services/pocketbase_service.dart';

void main() {
  // Initialize PocketBase
  PocketBaseService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novel Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    final isConnected = await PocketBaseService().testConnection();
    setState(() {
      _isConnected = isConnected;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novel Reader App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.error,
                    size: 100,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isConnected
                        ? 'Connected to PocketBase! ✅'
                        : 'PocketBase connection failed ❌',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isConnected
                        ? 'Ready to build the app!'
                        : 'Make sure PocketBase is running',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }
}