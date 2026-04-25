import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TimerApp(),
    );
  }
}

class TimerApp extends StatefulWidget {
  @override
  State<TimerApp> createState() => _TimerAppState();
}

class _TimerAppState extends State<TimerApp> {
  final AudioPlayer player = AudioPlayer();
  Timer? timer;

  int totalSeconds = 60;
  int startSeconds = 60;
  bool running = false;

  final hoursCtrl = TextEditingController(text: "0");
  final minutesCtrl = TextEditingController(text: "1");
  final secondsCtrl = TextEditingController(text: "0");

  String scene = "cleanup";
  String speech = "いっしょに がんばろう！";
  String status = "たいきちゅう";

  final scenes = {
    "cleanup": {
      "icon": "🧸",
      "startText": "おかたづけスタート！",
      "finishText": "おしまい！すごい！",
      "lines": [
        "ひとつずつでだいじょうぶ",
        "いいかんじ！",
        "あとちょっと！",
      ],
      "sound": "start.mp3",
    },
    "sleep": {
      "icon": "🌙",
      "startText": "ねるじゅんびはじめるよ",
      "finishText": "おやすみ〜",
      "lines": ["ゆっくりでいいよ", "すすんでるよ", "もうすぐ"],
      "sound": "start.mp3",
    },
  };

  int getInputSeconds() {
    return (int.tryParse(hoursCtrl.text) ?? 0) * 3600 +
        (int.tryParse(minutesCtrl.text) ?? 0) * 60 +
        (int.tryParse(secondsCtrl.text) ?? 0);
  }

  String format(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return "${h.toString().padLeft(2, '0')}:"
        "${m.toString().padLeft(2, '0')}:"
        "${s.toString().padLeft(2, '0')}";
  }

  double progress() {
    return totalSeconds / startSeconds;
  }

  Future<void> play(String file) async {
    // assets想定
    await player.play(AssetSource(file));
  }

  void start() {
    if (running) return;

    totalSeconds = getInputSeconds();
    startSeconds = totalSeconds;

    final s = scenes[scene]!;

    setState(() {
      running = true;
      speech = s["startText"] as String;
      status = "カウント中";
    });

    play(s["sound"] as String);

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        totalSeconds--;
      });

      if (totalSeconds > 0 && totalSeconds <= 10) {
        setState(() {
          speech = "$totalSeconds...";
        });
      }

      if (totalSeconds % 20 == 0 && totalSeconds > 0) {
        final lines = s["lines"] as List;
        speech = lines[Random().nextInt(lines.length)];
      }

      if (totalSeconds <= 0) {
        stop();
        setState(() {
          speech = s["finishText"] as String;
          status = "おしまい";
        });
      }
    });
  }

  void pause() {
    timer?.cancel();
    setState(() {
      running = false;
      status = "とまってる";
    });
  }

  void stop() {
    timer?.cancel();
    setState(() {
      running = false;
      totalSeconds = 0;
    });
  }

  void reset() {
    pause();
    totalSeconds = getInputSeconds();
    startSeconds = totalSeconds;
    setState(() {
      status = "たいきちゅう";
      speech = "じゅんびOK";
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = scenes[scene]!;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7D6),
      body: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s["icon"] as String, style: const TextStyle(fontSize: 50)),
              const Text("こどもカウントダウン",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),

              const SizedBox(height: 10),

              Text(format(totalSeconds),
                  style: const TextStyle(fontSize: 32)),

              LinearProgressIndicator(
                value: progress().isFinite ? progress() : 0,
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(child: TextField(controller: hoursCtrl)),
                  Expanded(child: TextField(controller: minutesCtrl)),
                  Expanded(child: TextField(controller: secondsCtrl)),
                ],
              ),

              DropdownButton(
                value: scene,
                items: scenes.keys
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => scene = v!),
              ),

              Row(
                children: [
                  ElevatedButton(onPressed: start, child: const Text("スタート")),
                  ElevatedButton(onPressed: pause, child: const Text("とめる")),
                  ElevatedButton(onPressed: reset, child: const Text("リセット")),
                ],
              ),

              const SizedBox(height: 10),

              Text(speech),
              Text(status),
            ],
          ),
        ),
      ),
    );
  }
}