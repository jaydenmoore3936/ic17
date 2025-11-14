import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

Future<void> _messageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message received: ${message.notification?.body}');
}


class QuoteStyle {
  final Color color;
  final IconData icon;
  final String defaultTitle;

  QuoteStyle(this.color, this.icon, this.defaultTitle);
}

QuoteStyle _getStyleFromMessage(RemoteMessage message) {
  final type = message.data['type'] ?? 'regular';

  switch (type) {
    case 'important':
      return QuoteStyle(Colors.red.shade700, Icons.warning_amber_rounded, 'Urgent Alert!');
    case 'wisdom':
      return QuoteStyle(Colors.purple.shade700, Icons.lightbulb_outline, 'Ancient Wisdom');
    case 'motivation':
      return QuoteStyle(Colors.blue.shade700, Icons.emoji_events, 'Motivational Push!');
    case 'regular':
    default:
      return QuoteStyle(Colors.grey.shade700, Icons.message, 'Daily Inspiration');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_messageHandler);
  runApp(const MessagingTutorial());
}

class MessagingTutorial extends StatelessWidget {
  const MessagingTutorial({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firebase Messaging',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'FCM Quotes App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late FirebaseMessaging messaging;
  String? _fcmToken;
  List<RemoteMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    messaging = FirebaseMessaging.instance;

    _configureFCM();
  }

  void _configureFCM() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false, 
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }

    messaging.getToken().then((value) {
      debugPrint('FCM Token: $value');
      setState(() {
        _fcmToken = value;
      });
    });

    messaging.subscribeToTopic("quotes");

    FirebaseMessaging.onMessage.listen((RemoteMessage event) {
      debugPrint("Foreground message received");
      _showCustomNotificationDialog(event);
      setState(() {
        _messages.add(event);
      });
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Message clicked (Opened App)');
      setState(() {
        _messages.add(message);
      });
    });

    messaging.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('App opened from terminated state by initial notification.');
        setState(() {
          _messages.add(message);
        });
      }
    });
  }

  void _showCustomNotificationDialog(RemoteMessage message) {
    final style = _getStyleFromMessage(message);
    final notification = message.notification;
    final type = message.data['type'] ?? 'regular';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          backgroundColor: style.color.withOpacity(0.1),
          title: Row(
            children: [
              Icon(style.icon, color: style.color),
              const SizedBox(width: 10),
              Text(
                notification?.title ?? style.defaultTitle,
                style: TextStyle(color: style.color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification?.body ?? 'No message body.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                'Type: $type (Category: ${message.data['category'] ?? 'N/A'})',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Got it!", style: TextStyle(color: style.color)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              "FCM Status",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            Text(
              'Token Status: ${_fcmToken != null ? 'READY (See console)' : 'Loading...'}',
              style: TextStyle(fontSize: 16, color: _fcmToken != null ? Colors.green : Colors.orange),
            ),
            const SizedBox(height: 5),
            GestureDetector(
              onTap: () {
                debugPrint('FCM Token Copied to console: $_fcmToken');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('FCM Token copied to the console for testing!')),
                );
              },
              child: Text(
                _fcmToken ?? 'Waiting for token...',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  decoration: TextDecoration.underline,
                  color: Colors.blue,
                ),
              ),
            ),
            const Divider(height: 40),
            const Text(
              "Received Notifications",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        "Send a test message from the Firebase Console (Add custom data: type:regular/important/wisdom/motivation)",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final style = _getStyleFromMessage(message);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: style.color.withOpacity(0.05),
                          child: ListTile(
                            leading: Icon(style.icon, color: style.color),
                            title: Text(message.notification?.title ?? style.defaultTitle),
                            subtitle: Text(
                                '${message.notification?.body}\n[Type: ${message.data['type'] ?? 'regular'}]'),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
