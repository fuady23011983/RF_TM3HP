import 'package:flutter/material.dart';
import 'screens/calculator_tab.dart';
import 'screens/generator_tab.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TM3 Converter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  double? _lat;
  double? _lon;
  double? _tm3X;
  double? _tm3Y;
  int? _tm3Zone;
  int? _tm3SubZone;

  void _onCalculated(double lat, double lon, double tm3X, double tm3Y, int tm3Zone, int tm3SubZone) {
    setState(() {
      _lat = lat;
      _lon = lon;
      _tm3X = tm3X;
      _tm3Y = tm3Y;
      _tm3Zone = tm3Zone;
      _tm3SubZone = tm3SubZone;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RF TM3 & Raster Generator'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.calculate), text: 'Kalkulator Offline'),
              Tab(icon: Icon(Icons.map), text: 'Generator Citra'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CalculatorTab(onCalculated: _onCalculated),
            GeneratorTab(
              lat: _lat,
              lon: _lon,
              tm3X: _tm3X,
              tm3Y: _tm3Y,
              tm3Zone: _tm3Zone,
              tm3SubZone: _tm3SubZone,
            ),
          ],
        ),
      ),
    );
  }
}
