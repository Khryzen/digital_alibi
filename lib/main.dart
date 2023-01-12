import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:http/http.dart';
import 'dart:convert';

void main() {
  zx.setLogEnabled(!kDebugMode);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

var resp, resp_code;
Map valueMap = jsonDecode(resp);
// var CountryCode = valueMap["CountryCode"];

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'ID ALIBI SCANNER',
      home: DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({Key? key}) : super(key: key);

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  Uint8List? createdCodeBytes;

  Code? result;

  bool showDebugInfo = true;
  int successScans = 0;
  int failedScans = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ID ALIBI SCANNER',
            textAlign: TextAlign.center,
          ),
          // bottom: const Text('Scan Code')
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (kIsWeb)
              const UnsupportedPlatformWidget()
            else if (result != null)
              ScanResultWidget(
                result: result?.rawBytes.toString(),
                qrdata: resp,
                data: valueMap,
                onScanAgain: () => setState(() => result = null),
              )
            else
              Stack(
                children: [
                  ReaderWidget(
                    onScan: _onScanSuccess,
                    onScanFailure: () => _onScanFailure(null),
                    tryInverted: true,
                  ),
                  if (showDebugInfo)
                    DebugInfoWidget(
                      successScans: successScans,
                      failedScans: failedScans,
                      onReset: _onReset,
                    ),
                ],
              ),
            if (kIsWeb)
              const UnsupportedPlatformWidget()
            else
              ListView(
                children: [
                  WriterWidget(
                    messages: const Messages(
                      createButton: 'Create Code',
                    ),
                    onSuccess: (result, bytes) {
                      setState(() {
                        createdCodeBytes = bytes;
                      });
                    },
                    onError: (error) {
                      _showMessage(context, 'Error: $error');
                    },
                  ),
                  if (createdCodeBytes != null)
                    Image.memory(createdCodeBytes ?? Uint8List(0), height: 200),
                ],
              ),
          ],
        ),
      ),
    );
  }

  _onScanSuccess(value) {
    setState(() async {
      successScans++;
      result = value;
      var temp = (result?.rawBytes).toString();
      print('temp:$temp');
      await makePostRequest(temp);
      print('resp: $resp_code');
      print('resp: $resp');
      // result = resp;
    });
  }

  _onScanFailure(String? error) {
    setState(() {
      failedScans++;
    });
    if (error != null) {
      _showMessage(context, error);
    }
  }

  _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  _onReset() {
    setState(() {
      successScans = 0;
      failedScans = 0;
    });
  }
}

class ScanResultWidget extends StatelessWidget {
  const ScanResultWidget({
    Key? key,
    this.result,
    this.qrdata,
    this.onScanAgain,
    this.data,
    // required qrdata,
  }) : super(key: key);

  final String? result;
  final String? qrdata;
  final Map? data;
  final Function()? onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Text(
          //   result ?? '',
          //   style: Theme.of(context).textTheme.headline6,
          // ),
          // Text(
          //   qrdata ?? '',
          //   style: Theme.of(context).textTheme.headline6,
          // ),
          Text(
            data!["CountryCode"],
            style: Theme.of(context).textTheme.headline6,
          ),
          Text(
            data!["DateTime"],
            style: Theme.of(context).textTheme.headline6,
          ),
          Text(
            data!["UID"],
            style: Theme.of(context).textTheme.headline6,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: onScanAgain,
            child: const Text('Scan Again'),
          ),
        ],
      ),
    );
  }
}

class DebugInfoWidget extends StatelessWidget {
  const DebugInfoWidget({
    Key? key,
    required this.successScans,
    required this.failedScans,
    this.onReset,
  }) : super(key: key);

  final int successScans;
  final int failedScans;

  final Function()? onReset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Colors.white.withOpacity(0.7),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Success: $successScans\nFailed: $failedScans',
                  style: Theme.of(context).textTheme.headline6,
                ),
                TextButton(
                  onPressed: onReset,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnsupportedPlatformWidget extends StatelessWidget {
  const UnsupportedPlatformWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'This platform is not supported yet.',
        style: Theme.of(context).textTheme.headline6,
      ),
    );
  }
}

Future<void> makePostRequest(str) async {
  print('STRING: $str');
  final url = Uri.parse('https://flutter.pudding.ws/api/decode');
  final headers = {"Content-type": "application/json"};
  final json = '{"raw_bytes":$str}';
  final response = await post(url, headers: headers, body: json);
  resp = response.body;
  resp_code = response.statusCode;
}
