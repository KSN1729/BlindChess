import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BlindChess Learning',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(
        title: 'BlindChess Learning',
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
              Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),

        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [

                const SizedBox(height: 32),

                const Icon(
                  Icons.grid_on,
                  size: 64,
                  color: Colors.deepPurple,
                ),

                const SizedBox(height: 16),

                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'You have pushed the button this many times:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  elevation: 4,
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [

                        Text(
                          '$_counter',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                        ),

                        const SizedBox(height: 8),

                        const Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [

                            Icon(
                              Icons.touch_app,
                              size: 16,
                            ),

                            SizedBox(width: 4),

                            Text(
                              'Click Logged',
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: _incrementCounter,
                  icon: const Icon(Icons.plus_one),
                  label: const Text(
                    'Increment Counter',
                  ),
                ),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Gesture Tap Registered!',
                        ),
                        duration:
                            Duration(milliseconds: 500),
                      ),
                    );
                  },
                  child: InkWell(
                    onTap: () {},
                    borderRadius:
                        BorderRadius.circular(8),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Learn Flutter UI Widgets',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                          decoration:
                              TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        floatingActionButton:
            FloatingActionButton(
          onPressed: _incrementCounter,
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}