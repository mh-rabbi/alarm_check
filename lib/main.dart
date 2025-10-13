import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

// Initialize notifications plugin
final FlutterLocalNotificationsPlugin notificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize alarm manager
  await AndroidAlarmManager.initialize();

  // Initialize notifications
  await _initializeNotifications();

  runApp(const MyApp());
}

// Initialize notifications
Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await notificationsPlugin.initialize(initializationSettings);
}

// This function runs when alarm triggers (even if app is closed)
@pragma('vm:entry-point')
Future<void> triggerAlarm() async {
  // Start the alarm ringtone and vibration
  _startAlarmRinging();
}

// Function to start continuous alarm ringing
void _startAlarmRinging() async {
  bool canVibrate = await Vibration.hasVibrator() ?? false;

  // Continuous vibration pattern (vibrate for 1 second, pause for 0.5 seconds)
  List<int> vibrationPattern = [1000, 500];

  // Start continuous vibration if device supports it
  if (canVibrate) {
    Vibration.vibrate(
      pattern: vibrationPattern,
      repeat: 0, // 0 means repeat indefinitely
    );
  }

  // Show full-screen notification to wake up device
  _showAlarmNotification();
}

// Show alarm notification that wakes up screen
void _showAlarmNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'alarm_channel',
    'Alarm Ringing',
    channelDescription: 'Channel for active alarm ringing',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    // sound: RawResourceAndroidNotificationSound('alarm_sound'), // Removed for simplicity
    enableVibration: true,
    // vibrationPattern: Int64List.fromList([1000, 500, 1000, 500]), // Simplified
    fullScreenIntent: true, // This wakes up the screen
    ongoing: true, // Cannot be dismissed by swiping
    autoCancel: false,
    // lights: const AndroidNotificationLights( // Removed - not available in current version
    //   [500, 500],
    //   [255, 0, 0],
    //   0
    // ),
    colorized: true,
    // color: Color(0xFFF44336), // Can't use Color in const, using alternative
  );

  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);

  await notificationsPlugin.show(
    12345, // Unique ID for alarm notification
    'ALARM RINGING!',
    'Tap to stop the alarm',
    platformChannelSpecifics,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Alarm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AlarmScreen(),
    );
  }
}

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  Timer? _alarmTimer;
  bool _isAlarmRinging = false;

  // Open time picker to select alarm time
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Schedule the alarm at selected time
  Future<void> _setAlarm() async {
    final now = DateTime.now();

    // Create DateTime for the alarm
    DateTime alarmTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute
    );

    // If selected time is already passed today, set for tomorrow
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }

    // Calculate delay in seconds
    final delayInSeconds = alarmTime.difference(now).inSeconds;

    // Schedule alarm using AndroidAlarmManager
    await AndroidAlarmManager.oneShot(
      Duration(seconds: delayInSeconds),
      1, // Unique alarm ID
      triggerAlarm,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alarm set for ${_selectedTime.format(context)}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // TEST FUNCTION: Trigger alarm immediately for testing
  void _testAlarmNow() {
    _startAlarmRing();
  }

  // Start the alarm ringing (simulates what happens when alarm triggers)
  void _startAlarmRing() {
    setState(() {
      _isAlarmRinging = true;
    });

    // Start vibration
    Vibration.hasVibrator().then((canVibrate) {
      if (canVibrate ?? false) {
        Vibration.vibrate(
          pattern: [1000, 500], // Vibrate 1s, pause 0.5s
          repeat: 0, // Repeat indefinitely
        );
      }
    });

    // Show alarm notification
    _showAlarmNotification();

    // Set timer to auto-stop after 1 minute (60 seconds)
    _alarmTimer = Timer(const Duration(minutes: 1), _stopAlarm);

    // Show alarm screen
    _showAlarmScreen();
  }

  // Stop the alarm ringing
  void _stopAlarm() {
    // Stop vibration
    Vibration.cancel();

    // Cancel timer
    _alarmTimer?.cancel();

    // Dismiss notification
    notificationsPlugin.cancel(12345);

    setState(() {
      _isAlarmRinging = false;
    });

    // Close any dialog
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Show full-screen alarm dialog
  void _showAlarmScreen() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // Prevent back button from closing
          child: AlertDialog(
            backgroundColor: Colors.red[50],
            title: const Row(
              children: [
                Icon(Icons.alarm, color: Colors.red, size: 40),
                SizedBox(width: 10),
                Text(
                  'ALARM RINGING!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Alarm is ringing continuously!',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 10),
                Text(
                  'It will automatically stop after 1 minute',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(height: 10),
                Text(
                  'Vibration pattern: 1 second ON, 0.5 seconds OFF',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: _stopAlarm,
                icon: const Icon(Icons.stop),
                label: const Text('STOP ALARM'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Alarm'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display selected time
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Alarm Time',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedTime.format(context),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Time picker button
            ElevatedButton.icon(
              onPressed: _selectTime,
              icon: const Icon(Icons.access_time),
              label: const Text('SELECT TIME'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
            ),

            const SizedBox(height: 15),

            // Set alarm button
            ElevatedButton.icon(
              onPressed: _setAlarm,
              icon: const Icon(Icons.alarm_add),
              label: const Text('SET ALARM'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
            ),

            const SizedBox(height: 15),

            // Test alarm button (for immediate testing)
            ElevatedButton.icon(
              onPressed: _testAlarmNow,
              icon: const Icon(Icons.play_arrow),
              label: const Text('TEST ALARM NOW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              ),
            ),

            const SizedBox(height: 30),

            // Instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    Text(
                      'How it works:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text('• Alarm will ring for 1 minute continuously'),
                    Text('• Device will vibrate repeatedly'),
                    Text('• Screen will wake up'),
                    Text('• Tap "STOP ALARM" to stop immediately'),
                  ],
                ),
              ),
            ),

            // Show status if alarm is ringing
            if (_isAlarmRinging) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.alarm, color: Colors.red),
                    SizedBox(width: 10),
                    Text(
                      'ALARM RINGING...',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}