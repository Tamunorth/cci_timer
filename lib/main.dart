import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:custom_timer/custom_timer.dart';
import 'package:desktop_lifecycle/desktop_lifecycle.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:multi_window/event_widget.dart';
// import 'package:flutter_multi_window_example/event_widget.dart';

void main(List<String> args) {
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    final argument = args[2].isEmpty
        ? const {}
        : jsonDecode(args[2]) as Map<String, dynamic>;
    runApp(_ExampleSubWindow(
      windowController: WindowController.fromWindowId(windowId),
      args: argument,
    ));
  } else {
    runApp(const _ExampleMainWindow());
  }
}

class _ExampleMainWindow extends StatefulWidget {
  const _ExampleMainWindow({Key? key}) : super(key: key);

  @override
  State<_ExampleMainWindow> createState() => _ExampleMainWindowState();
}

class _ExampleMainWindowState extends State<_ExampleMainWindow> {
  late final TextEditingController secondsCtrl;
  late final TextEditingController minutesCtrl;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    minutesCtrl = TextEditingController();
    secondsCtrl = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () async {
                final windowIds = await DesktopMultiWindow.getAllSubWindowIds();

                if (windowIds.length >= 1) {
                  return;
                }
                final window =
                    await DesktopMultiWindow.createWindow(jsonEncode({
                  'args1': 'Timer window',
                  'args2': 10,
                  'args3': true,
                  'business': 'business_test',
                }));
                window
                  ..setFrame(const Offset(1920, 0) & const Size(1920, 1080))
                  // ..setTitle('Another window')
                  ..resizable(true)
                  ..show();
              },
              child: const Text('Create a Timer Window'),
            ),
            TextField(
                controller: minutesCtrl,
                decoration: InputDecoration(
                  hintText: 'Minutes',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ]),
            SizedBox(
              height: 10,
            ),
            TextField(
                controller: secondsCtrl,
                decoration: InputDecoration(
                  hintText: 'Seconds',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ]),
            TextButton(
              child: const Text('Update Timer'),
              onPressed: () async {
                if (minutesCtrl.text.trim().isEmpty) {
                  minutesCtrl.text = '0';
                }

                if (secondsCtrl.text.trim().isEmpty) {
                  secondsCtrl.text = '0';
                }

                final subWindowIds =
                    await DesktopMultiWindow.getAllSubWindowIds();
                for (final windowId in subWindowIds) {
                  DesktopMultiWindow.invokeMethod(
                    windowId,
                    'onChange',
                    [minutesCtrl.text.trim(), secondsCtrl.text.trim()],
                  );
                }
              },
            ),
            Expanded(
              child: EventWidget(controller: WindowController.fromWindowId(0)),
            )
          ],
        ),
      ),
    );
  }
}

class _ExampleSubWindow extends StatelessWidget {
  const _ExampleSubWindow({
    Key? key,
    required this.windowController,
    required this.args,
  }) : super(key: key);

  final WindowController windowController;
  final Map? args;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late CustomTimerController _controller = CustomTimerController(
    vsync: this,
    begin: Duration(minutes: 0, seconds: 0),
    end: Duration(),
    initialState: CustomTimerState.counting,
    interval: CustomTimerInterval.milliseconds,
  );

  StopWatchTimer? stopwatch;
  bool isCountdown = true;
  double fontsize = 400;

  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler(_handleMethodCallback);
    _controller?.state.addListener(() {
      if (_controller?.state.value == CustomTimerState.finished) {
        switchToStopwatch();
      }
    });
    _initTimerAndStopwatch();
  }

  _initTimerAndStopwatch() {
    stopwatch = StopWatchTimer(
      mode: StopWatchMode.countUp,
    );
  }

  void switchToStopwatch() {
    setState(() {
      isCountdown = false;
    });

    stopwatch?.onStartTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (isCountdown)
              CustomTimer(
                  controller: _controller!,
                  builder: (state, time) {
                    // Build the widget you want!🎉
                    return Text(
                      time.hours != '00'
                          ? "${time.hours}:${time.minutes}:${time.seconds}"
                          : "${time.minutes}:${time.seconds}",
                      style: TextStyle(
                          fontSize: time.hours != '00' ? 300 : fontsize,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    );
                  }),
            if (!isCountdown)
              StreamBuilder<int>(
                stream: stopwatch?.rawTime,
                initialData: stopwatch?.rawTime.value,
                builder: (context, snapshot) {
                  final value = snapshot.data;
                  final displayTime = StopWatchTimer.getDisplayTime(value!,
                      hours: false, milliSecond: false);
                  return Text(
                    '-${displayTime}',
                    style: TextStyle(
                      fontSize: fontsize,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<dynamic> _handleMethodCallback(
      MethodCall call, int fromWindowId) async {
    if (call.method == 'onChange') {
      // debugPrint("onChange result2: ${call.arguments.toString()}");
      // _controller?.start();

      _controller.begin = Duration(
        minutes: int.parse(call.arguments[0]),
        seconds: int.parse(call.arguments[1]),
      );
      _controller.reset();
      _controller.start();
      isCountdown = true;
      stopwatch?.onResetTimer();
      setState(() {});

      // _controller = CustomTimerController(
      //   vsync: this,
      //   begin: Duration(minutes: 2),
      //   end: Duration(),
      //   initialState: CustomTimerState.counting,
      //   interval: CustomTimerInterval.milliseconds,
      // );

      return "send";
    }
    if (call.arguments.toString() == "ping") {
      return "pong";
    }

    /// if the callback method is not handled do this instead
    return Future.value('no callback');
  }

  @override
  void dispose() {
    _controller.dispose();
    stopwatch?.dispose();
    DesktopMultiWindow.setMethodHandler(null);

    super.dispose();
  }
}
