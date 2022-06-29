// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'src/application_state.dart';
import 'src/player_widget.dart';
import 'src/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (context) => ApplicationState(),
      builder: (context, _) => const MyMusicBoxApp(),
    ),
  );
}

class MyMusicBoxApp extends StatelessWidget {
  const MyMusicBoxApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Music Box',
      theme: ThemeData(
        primaryColor: Colors.red.shade200,
      ),
      home: PlayerPage(buildContext: context),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({Key? key, required this.buildContext}) : super(key: key);
  final BuildContext buildContext;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late String filePath;
  late PlayerWidget _playerWidget;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      filePath =
          'https://firebasestorage.googleapis.com/v0/b/codelab-assets.appspot.com/o/firebase-song.mp3?alt=media&token=44d4fc4f-20f6-40e0-998b-f9cf033a7d07';
    } else {
      filePath = 'better-together.mp3';
    }

    _playerWidget = PlayerWidget(url: filePath, context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Box'),
        backgroundColor: Colors.deepPurple.shade400,
        actions: const [AppBarMenuButton()],
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade200,
              Colors.red.shade300,
            ],
          ),
        ),
        child: ListView(
          children: <Widget>[
            SizedBox(
              child: Center(
                  child: Container(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: Offset(3, 0),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: Image.asset(
                    'assets/better-together.png',
                    width: (MediaQuery.of(context).size.width * 0.8),
                    fit: BoxFit.contain,
                  ),
                ),
              )),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              child: const Center(
                child: Text(
                  'A Firebase Song',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: const BorderRadius.all(Radius.circular(25.0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [_playerWidget],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Text(
                    'Device controller: ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ActiveControllerText(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
