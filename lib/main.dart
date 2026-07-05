import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TM3 Converter',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
  double? _lat, _lon, _tm3X, _tm3Y;
  int? _tm3Zone, _tm3SubZone;

  void _onCalculated(double lat, double lon, double tm3X, double tm3Y, int tm3Zone, int tm3SubZone) {
    setState(() {
      _lat = lat; _lon = lon; _tm3X = tm3X; _tm3Y = tm3Y;
      _tm3Zone = tm3Zone; _tm3SubZone = tm3SubZone;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RF TM3 & Raster Generator'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.calculate), text: 'Kalkulator Offline'),
            Tab(icon: Icon(Icons.map), text: 'Generator Citra'),
          ]),
        ),
        body: TabBarView(children: [
          CalculatorTab(onCalculated: _onCalculated),
          GeneratorTab(lat: _lat, lon: _lon, tm3X: _tm3X, tm3Y: _tm3Y, tm3Zone: _tm3Zone, tm3SubZone: _tm3SubZone),
        ]),
      ),
    );
  }
}

// ============================================================================
// CALCULATOR TAB
// ============================================================================
class CalculatorTab extends StatefulWidget {
  final Function(double, double, double, double, int, int) onCalculated;
  const CalculatorTab({Key? key, required this.onCalculated}) : super(key: key);
  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  final _utmxController = TextEditingController();
  final _utmyController = TextEditingController();
  int _utmZone = 48, _tm3Zone = 48, _tm3SubZone = 1;
  bool _isSouth = true;
  String _resultText = '';

  void _calculate() {
    double? x = double.tryParse(_utmxController.text);
    double? y = double.tryParse(_utmyController.text);
    if (x == null || y == null) {
      setState(() => _resultText = 'Input tidak valid.');
      return;
    }
    try {
      final latlon = TM3Converter.utmToLatLon(x, y, _utmZone, _isSouth);
      final tm3 = TM3Converter.latLonToTm3(latlon['lat']!, latlon['lon']!, _tm3Zone, _tm3SubZone);
      setState(() {
        _resultText = 'Hasil Konversi TM3:\nX: ${tm3['x']!.toStringAsFixed(4)}\nY: ${tm3['y']!.toStringAsFixed(4)}\n\n(Lat: ${latlon['lat']!.toStringAsFixed(6)}, Lon: ${latlon['lon']!.toStringAsFixed(6)})';
      });
      widget.onCalculated(latlon['lat']!, latlon['lon']!, tm3['x']!, tm3['y']!, _tm3Zone, _tm3SubZone);
    } catch (e) {
      setState(() => _resultText = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _utmxController, decoration: const InputDecoration(labelText: 'X (Easting UTM)'), keyboardType: TextInputType.number),
        TextField(controller: _utmyController, decoration: const InputDecoration(labelText: 'Y (Northing UTM)'), keyboardType: TextInputType.number),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(value: _utmZone, decoration: const InputDecoration(labelText: 'UTM Zone'), items: List.generate(9, (i) => 46+i).map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(), onChanged: (v) => setState(() => _utmZone = v!))),
          Expanded(child: DropdownButtonFormField<bool>(value: _isSouth, decoration: const InputDecoration(labelText: 'Hemisphere'), items: const [DropdownMenuItem(value: true, child: Text('South')), DropdownMenuItem(value: false, child: Text('North'))], onChanged: (v) => setState(() => _isSouth = v!))),
        ]),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(value: _tm3Zone, decoration: const InputDecoration(labelText: 'TM3 Zone'), items: List.generate(9, (i) => 46+i).map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(), onChanged: (v) => setState(() => _tm3Zone = v!))),
          Expanded(child: DropdownButtonFormField<int>(value: _tm3SubZone, decoration: const InputDecoration(labelText: 'Subzone'), items: const [DropdownMenuItem(value: 1, child: Text('.1')), DropdownMenuItem(value: 2, child: Text('.2'))], onChanged: (v) => setState(() => _tm3SubZone = v!))),
        ]),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _calculate, child: const Text('HITUNG TM3')),
        if (_resultText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_resultText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      ]),
    );
  }
}

// ============================================================================
// GENERATOR TAB
// ============================================================================
class GeneratorTab extends StatefulWidget {
  final double? lat, lon, tm3X, tm3Y;
  final int? tm3Zone, tm3SubZone;
  const GeneratorTab({Key? key, this.lat, this.lon, this.tm3X, this.tm3Y, this.tm3Zone, this.tm3SubZone}) : super(key: key);
  @override
  State<GeneratorTab> createState() => _GeneratorTabState();
}

class _GeneratorTabState extends State<GeneratorTab> {
  bool _isGenerating = false;
  String _status = 'Siap.';

  Future<void> _generate() async {
    if (widget.lat == null) return;
    setState(() { _isGenerating = true; _status = 'Mengunduh citra...'; });
    try {
      final r = 0.0025;
      final result = await TileDownloader.downloadAndStitch(widget.lat!-r, widget.lon!-r, widget.lat!+r, widget.lon!+r, zoom: 19);
      final path = await FileExporter.saveImageAndJgw(result['imageBytes'], result['jgw'], 'citra_${DateTime.now().millisecondsSinceEpoch}');
      setState(() => _status = 'Tersimpan di:\n$path');
    } catch (e) {
      setState(() => _status = 'Gagal: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _exportKml() async {
    if (widget.lat == null) return;
    try {
      final kml = FileExporter.generateKmlPoint(widget.lat!, widget.lon!, 'Titik_Ukur');
      final path = await FileExporter.saveKml(kml, 'titik_${DateTime.now().millisecondsSinceEpoch}');
      setState(() => _status = 'KML Tersimpan di:\n$path');
    } catch (e) {
      setState(() => _status = 'Gagal mengekspor KML: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.lat != null ? 'Titik Pusat:\nLat: ${widget.lat!.toStringAsFixed(6)}\nLon: ${widget.lon!.toStringAsFixed(6)}' : 'Belum ada koordinat.', style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _isGenerating ? null : _generate, icon: const Icon(Icons.map), label: const Text('GENERATE CITRA & JGW')),
      const SizedBox(height: 8),
      ElevatedButton.icon(onPressed: _exportKml, icon: const Icon(Icons.share_location), label: const Text('EKSPOR KML')),
      const SizedBox(height: 16),
      Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]));
  }
}

// ============================================================================
// UTILS
// ============================================================================
class TM3Converter {
  static const double a = 6378137.0, f = 1 / 298.257223563, b = a * (1 - f), e = 0.0818191908;
  static const double e2 = e * e, e4 = e2 * e2, e6 = e4 * e2, ep2 = (a * a - b * b) / (b * b);

  static Map<String, double> utmToLatLon(double x, double y, int zone, bool isSouth) {
    x -= 500000.0; y -= isSouth ? 10000000.0 : 0.0;
    final m = y / 0.9996, mu = m / (a * (1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256));
    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2)), e1_2 = e1 * e1, e1_3 = e1_2 * e1, e1_4 = e1_3 * e1;
    final fp = mu + (3*e1/2 - 27*e1_3/32)*math.sin(2*mu) + (21*e1_2/16 - 55*e1_4/32)*math.sin(4*mu) + (151*e1_3/96)*math.sin(6*mu) + (1097*e1_4/512)*math.sin(8*mu);
    final c1 = ep2 * math.pow(math.cos(fp), 2), t1 = math.pow(math.tan(fp), 2);
    final r1 = a * (1 - e2) / math.pow(1 - e2 * math.pow(math.sin(fp), 2), 1.5);
    final n1 = a / math.sqrt(1 - e2 * math.pow(math.sin(fp), 2));
    final d = x / (n1 * 0.9996);
    final lat = fp - (n1 * math.tan(fp) / r1) * (d * d / 2.0 - (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ep2) * math.pow(d, 4) / 24.0 + (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 3 * c1 * c1 - 252 * ep2) * math.pow(d, 6) / 720.0);
    final lon = (zone * 6 - 183) * math.pi / 180.0 + (d - (1 + 2 * t1 + c1) * math.pow(d, 3) / 6.0 + (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * ep2 + 24 * t1 * t1) * math.pow(d, 5) / 120.0) / math.cos(fp);
    return {'lat': lat * 180.0 / math.pi, 'lon': lon * 180.0 / math.pi};
  }

  static Map<String, double> latLonToTm3(double lat, double lon, int zone, int subZone) {
    final lon0 = (93.0 + (zone - 46) * 6.0 + (subZone == 1 ? -1.5 : 1.5)) * math.pi / 180.0;
    final latRad = lat * math.pi / 180.0, lonRad = lon * math.pi / 180.0;
    final n = a / math.sqrt(1 - e2 * math.pow(math.sin(latRad), 2)), t = math.pow(math.tan(latRad), 2), c = ep2 * math.pow(math.cos(latRad), 2), A = (lonRad - lon0) * math.cos(latRad);
    final m = a * ((1 - e2/4 - 3*e4/64 - 5*e6/256)*latRad - (3*e2/8 + 3*e4/32 + 45*e6/1024)*math.sin(2*latRad) + (15*e4/256 + 45*e6/1024)*math.sin(4*latRad) - (35*e6/3072)*math.sin(6*latRad));
    final A2 = A*A, A3 = A2*A, A4 = A3*A, A5 = A4*A, A6 = A5*A;
    return {
      'x': 0.9999 * n * (A + (1 - t + c) * A3 / 6 + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * A5 / 120) + 200000.0,
      'y': 0.9999 * (m + n * math.tan(latRad) * (A2 / 2 + (5 - t + 9 * c + 4 * c * c) * A4 / 24 + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * A6 / 720)) + 1500000.0
    };
  }
}

class TileDownloader {
  static int lon2tile(double lon, int z) => ((lon + 180.0) / 360.0 * math.pow(2.0, z)).floor();
  static int lat2tile(double lat, int z) => ((1.0 - math.log(math.tan(lat * math.pi / 180.0) + 1.0 / math.cos(lat * math.pi / 180.0)) / math.pi) / 2.0 * math.pow(2.0, z)).floor();
  static double tile2lon(int x, int z) => x / math.pow(2.0, z) * 360.0 - 180;
  static double tile2lat(int y, int z) { double n = math.pi - 2.0 * math.pi * y / math.pow(2.0, z); return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n))); }

  static Future<Map<String, dynamic>> downloadAndStitch(double minLat, double minLon, double maxLat, double maxLon, {int zoom = 19}) async {
    int minX = lon2tile(minLon, zoom), maxX = lon2tile(maxLon, zoom), minY = lat2tile(maxLat, zoom), maxY = lat2tile(minLat, zoom);
    if ((maxX - minX + 1) * (maxY - minY + 1) > 25) throw Exception('Area terlalu besar');
    final stitched = img.Image(width: (maxX - minX + 1) * 256, height: (maxY - minY + 1) * 256);
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        final res = await http.get(Uri.parse('https://mt1.google.com/vt/lyrs=s&x=$x&y=$y&z=$zoom'));
        if (res.statusCode == 200) {
          final t = img.decodeImage(res.bodyBytes);
          if (t != null) img.compositeImage(stitched, t, dstX: (x - minX) * 256, dstY: (y - minY) * 256);
        }
      }
    }
    double px = (tile2lon(maxX + 1, zoom) - tile2lon(minX, zoom)) / stitched.width;
    double py = (tile2lat(maxY + 1, zoom) - tile2lat(minY, zoom)) / stitched.height;
    return {
      'imageBytes': Uint8List.fromList(img.encodeJpg(stitched, quality: 90)),
      'jgw': '${px.toStringAsFixed(10)}\n0.0\n0.0\n${py.toStringAsFixed(10)}\n${tile2lon(minX, zoom).toStringAsFixed(10)}\n${tile2lat(minY, zoom).toStringAsFixed(10)}\n'
    };
  }
}

class FileExporter {
  static Future<Directory?> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      if (!(await Permission.manageExternalStorage.request().isGranted)) {
        if (!(await Permission.storage.request().isGranted)) return null;
      }
    }
    final dir = Directory('/storage/emulated/0/Download/Hasil_Citra_AutoCAD');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
  static Future<String> saveImageAndJgw(Uint8List img, String jgw, String name) async {
    final d = await getDownloadDirectory();
    if (d == null) throw Exception('Izin storage ditolak');
    await File('${d.path}/$name.jpg').writeAsBytes(img);
    await File('${d.path}/$name.jgw').writeAsString(jgw);
    return d.path;
  }
  static Future<String> saveKml(String kml, String name) async {
    final d = await getDownloadDirectory();
    if (d == null) throw Exception('Izin storage ditolak');
    await File('${d.path}/$name.kml').writeAsString(kml);
    return d.path;
  }
  static String generateKmlPoint(double lat, double lon, String name) => '<?xml version="1.0" encoding="UTF-8"?>\n<kml xmlns="http://www.opengis.net/kml/2.2">\n  <Placemark>\n    <name>$name</name>\n    <Point><coordinates>$lon,$lat,0</coordinates></Point>\n  </Placemark>\n</kml>';
}
