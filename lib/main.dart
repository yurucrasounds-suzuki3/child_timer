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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TimerApp(),
    );
  }
}

class TimerApp extends StatefulWidget {
  const TimerApp({super.key});

  @override
  State<TimerApp> createState() => _TimerAppState();
}

class _TimerAppState extends State<TimerApp> {
  final AudioPlayer player = AudioPlayer();
  final AudioPlayer sequencePlayer = AudioPlayer();
  final Random random = Random();
  Timer? timer;

  int selectedHours = 0;
  int selectedMinutes = 1;
  int selectedSeconds = 0;

  int totalSeconds = 60;
  int startSeconds = 60;
  bool running = false;

  String scene = "cleanup";
  String speech = "いっしょに がんばろう！";
  String status = "たいきちゅう";

  final scenes = {
    "cleanup": {
      "label": "おかたづけ",
      "icon": "🧸",
      "startText": "おかたづけスタート！",
      "finishText": "おしまい！すごい！",
      "lines": ["その調子その調子！", "頑張って！", "がんばれー"],
      "startVoice": "「スタート」.mp3",
      "finishVoice": "「終了」.mp3",
    },
    "sleep": {
      "label": "ねるまえ",
      "icon": "🌙",
      "startText": "ねるじゅんびはじめるよ",
      "finishText": "おやすみ〜",
      "lines": ["頑張って！", "その調子その調子！", "フレーフレー"],
      "startVoice": "「スタート」.mp3",
      "finishVoice": "「終了」.mp3",
    },
  };

  final countdownVoices = <int, String>{
    10: "「10（じゅう↓）」.mp3",
    9: "「9」.mp3",
    8: "「8」.mp3",
    7: "「7」.mp3",
    6: "「6」.mp3",
    5: "「5」.mp3",
    4: "「4（よん）」.mp3",
    3: "「3」.mp3",
    2: "「2」.mp3",
    1: "「1」.mp3",
  };

  final cheerVoices = [
    "「フレーフレー」.mp3",
    "「頑張って！」.mp3",
    "「がんばれー」.mp3",
    "「その調子その調子！」.mp3",
    "「あとちょっと～！」.mp3",
    "「すごいすごい」.mp3",
  ];

  int getSelectedSeconds() {
    return selectedHours * 3600 + selectedMinutes * 60 + selectedSeconds;
  }

  String format(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;

    return "${h.toString().padLeft(2, '0')}:"
        "${m.toString().padLeft(2, '0')}:"
        "${s.toString().padLeft(2, '0')}";
  }

  double get progress {
    if (startSeconds <= 0) return 0;
    return (totalSeconds / startSeconds).clamp(0.0, 1.0);
  }

  Future<void> playSafe(String file) async {
    try {
      debugPrint("playSafe: attempting to play $file");
      await player.stop();
      await player.play(AssetSource(file));
      debugPrint("playSafe: successfully started playing $file");
    } catch (e) {
      debugPrint("audio error: $file => $e");
    }
  }

  Future<void> playSequence(List<String> files) async {
    try {
      await sequencePlayer.stop();

      for (final file in files) {
        debugPrint("playSequence: attempting to play $file");
        await sequencePlayer.play(AssetSource(file));
        debugPrint("playSequence: successfully started playing $file");

        // Wait for the audio to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));
        
        // Wait until player is no longer playing
        while (sequencePlayer.state == PlayerState.playing) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      debugPrint("sequence audio error: $e");
    }
  }

  void syncSelectedTime() {
    final sec = getSelectedSeconds();

    setState(() {
      totalSeconds = sec <= 0 ? 1 : sec;
      startSeconds = totalSeconds;
      status = "たいきちゅう";
      speech = "じゅんびOK";
    });
  }

  Future<void> start() async {
    if (running) return;

    final sec = getSelectedSeconds();

    if (sec <= 0) {
      setState(() {
        status = "じかんをえらんでね";
        speech = "1びょういじょうにしてね";
      });
      return;
    }

    setState(() {
      totalSeconds = sec;
      startSeconds = sec;
      running = true;
      status = "じゅんび中";
      speech = "いくよー！";
    });

    await playSequence([
      "「準備はいいかな？」.mp3",
      "「よぉーい…」.mp3",
      scenes[scene]!["startVoice"] as String,
    ]);

    if (!mounted || !running) return;

    setState(() {
      status = "カウント中";
      speech = scenes[scene]!["startText"] as String;
    });

    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      final currentScene = scenes[scene]!;
      final next = totalSeconds - 1;

      setState(() {
        totalSeconds = next;
      });

      if (next > 0 && next <= 10 && countdownVoices.containsKey(next)) {
        setState(() {
          speech = "$next...";
        });

        unawaited(playSafe(countdownVoices[next]!));
      } else if (next > 0 && next % 20 == 0 && next != startSeconds) {
        final lines = (currentScene["lines"] as List).cast<String>();

        setState(() {
          speech = lines[random.nextInt(lines.length)];
        });

        unawaited(playSafe(cheerVoices[random.nextInt(cheerVoices.length)]));
      }

      if (next <= 0) {
        t.cancel();

        setState(() {
          running = false;
          totalSeconds = 0;
          status = "おしまい";
          speech = currentScene["finishText"] as String;
        });

        unawaited(playFinishSequence(currentScene["finishVoice"] as String));
      }
    });
  }

  Future<void> playFinishSequence(String finishVoice) async {
    await playSequence([
      finishVoice,
      "pass.mp3",
    ]);
  }

  void pause() {
    timer?.cancel();
    player.stop();
    sequencePlayer.stop();

    setState(() {
      running = false;
      status = "とまってる";
      speech = "いったん おやすみ";
    });
  }

  void reset() {
    timer?.cancel();
    player.stop();
    sequencePlayer.stop();

    setState(() {
      running = false;
      totalSeconds = getSelectedSeconds() <= 0 ? 1 : getSelectedSeconds();
      startSeconds = totalSeconds;
      status = "たいきちゅう";
      speech = "じゅんびOK";
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    sequencePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentScene = scenes[scene]!;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF6DA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    currentScene["icon"] as String,
                    style: const TextStyle(fontSize: 52),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "こどもカウントダウン",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF594A3C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9A8B7A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CustomPaint(
                      painter: CircleTimerPainter(progress),
                      child: Center(
                        child: Text(
                          format(totalSeconds),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF6D5DFC),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFFFDF8A),
                        width: 3,
                      ),
                    ),
                    child: Text(
                      speech,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B5B4B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TimePickerBox(
                          label: "じ",
                          value: selectedHours,
                          max: 23,
                          enabled: !running,
                          onChanged: (v) {
                            selectedHours = v;
                            syncSelectedTime();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TimePickerBox(
                          label: "ふん",
                          value: selectedMinutes,
                          max: 59,
                          enabled: !running,
                          onChanged: (v) {
                            selectedMinutes = v;
                            syncSelectedTime();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TimePickerBox(
                          label: "びょう",
                          value: selectedSeconds,
                          max: 59,
                          enabled: !running,
                          onChanged: (v) {
                            selectedSeconds = v;
                            syncSelectedTime();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: scene,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF4FFF4),
                      labelText: "どんなとき？",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: scenes.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              "${e.value["icon"]} ${e.value["label"]}",
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: running
                        ? null
                        : (v) {
                            setState(() {
                              scene = v!;
                              speech = "いっしょに がんばろう！";
                            });
                          },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: BigButton(
                          text: "スタート",
                          color: const Color(0xFF7AD97A),
                          onPressed: running ? null : start,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BigButton(
                          text: "とめる",
                          color: const Color(0xFFFFD36E),
                          textColor: const Color(0xFF6A5600),
                          onPressed: running ? pause : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BigButton(
                          text: "もどす",
                          color: const Color(0xFF9DB4FF),
                          onPressed: reset,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TimePickerBox extends StatelessWidget {
  const TimePickerBox({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0DCFF), width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF8A7B7B),
            ),
          ),
          DropdownButton<int>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            alignment: Alignment.center,
            items: List.generate(max + 1, (i) {
              return DropdownMenuItem(
                value: i,
                child: Center(
                  child: Text(
                    "$i",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }),
            onChanged: enabled ? (v) => onChanged(v!) : null,
          ),
        ],
      ),
    );
  }
}

class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.text,
    required this.color,
    required this.onPressed,
    this.textColor = Colors.white,
  });

  final String text;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        disabledBackgroundColor: color.withOpacity(0.45),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class CircleTimerPainter extends CustomPainter {
  CircleTimerPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFFEDEAFF)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = const Color(0xFF6D5DFC)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircleTimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}