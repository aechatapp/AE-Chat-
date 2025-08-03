// AE Chat full app (Stages 1-6)
// Flutter + Firebase: Login, Profile, Chat, Stories, Reports, Verification, Theme

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(AEChatApp());
}

class AEChatApp extends StatefulWidget {
  @override
  _AEChatAppState createState() => _AEChatAppState();
}

class _AEChatAppState extends State<AEChatApp> {
  bool darkMode = true;

  void toggleTheme() {
    setState(() {
      darkMode = !darkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AE Chat',
      theme: darkMode ? ThemeData.dark() : ThemeData.light(),
      home: FirebaseAuth.instance.currentUser == null
          ? AuthPage()
          : LoadingPage(toggleTheme: toggleTheme),
    );
  }
}

// LoadingPage to check profile existence
class LoadingPage extends StatelessWidget {
  final VoidCallback toggleTheme;
  LoadingPage({required this.toggleTheme});

  Future<bool> checkProfileExists() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: checkProfileExists(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snapshot.data == false) {
          return CreateProfilePage(toggleTheme: toggleTheme);
        } else {
          return HomePage(toggleTheme: toggleTheme);
        }
      },
    );
  }
}

// Auth Page (Login/Signup)
class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => LoadingPage(toggleTheme: () {})));
    } catch (e) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passController.text.trim(),
        );
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => LoadingPage(toggleTheme: () {})));
      } catch (e) {
        Fluttertoast.showToast(msg: "Login or Signup failed.");
      }
    }
    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AE Chat Login / Signup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email')),
            TextField(controller: passController, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
            SizedBox(height: 20),
            loading
                ? CircularProgressIndicator()
                : ElevatedButton(onPressed: login, child: Text('Continue')),
          ],
        ),
      ),
    );
  }
}

// Create Profile Page
class CreateProfilePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  CreateProfilePage({required this.toggleTheme});
  @override
  _CreateProfilePageState createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final bioController = TextEditingController();
  final skillController = TextEditingController();
  String error = '';

  List<String> blockedUsernames = [
    'elonmusk', 'drdre', 'snoopdogg', '2pac', 'admin', 'moderator', 'support'
  ];

  bool isSaving = false;

  Future<void> saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final username = usernameController.text.trim().toLowerCase();

    if (username.length < 3) {
      setState(() {
        error = "Username must be at least 3 characters.";
      });
      return;
    }

    if (blockedUsernames.contains(username)) {
      setState(() => error = "That username is restricted.");
      return;
    }

    setState(() {
      error = '';
      isSaving = true;
    });

    final existing = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .get();

    if (existing.docs.isNotEmpty) {
      setState(() {
        error = "Username already taken.";
        isSaving = false;
      });
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'email': FirebaseAuth.instance.currentUser!.email,
      'name': nameController.text.trim(),
      'username': username,
      'bio': bioController.text.trim(),
      'skill': skillController.text.trim(),
      'verified': false,
      'createdAt': FieldValue.serverTimestamp(),
      'stories': [],
    });

    setState(() {
      isSaving = false;
    });

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => HomePage(toggleTheme: widget.toggleTheme)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Your Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name')),
              TextField(controller: usernameController, decoration: InputDecoration(labelText: 'Username')),
              TextField(
                controller: bioController,
                decoration: InputDecoration(labelText: 'Bio'),
                maxLength: 230,
              ),
              TextField(controller: skillController, decoration: InputDecoration(labelText: 'Skill (e.g. Entrepreneur)')),
              SizedBox(height: 20),
              if (error.isNotEmpty) Text(error, style: TextStyle(color: Colors.red)),
              SizedBox(height: 10),
              isSaving ? CircularProgressIndicator() : ElevatedButton(onPressed: saveProfile, child: Text('Save & Continue')),
            ],
          ),
        ),
      ),
    );
  }
}

// Home Page (Main Chat + Stories + Profile + Settings)
class HomePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  HomePage({required this.toggleTheme});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final msgController = TextEditingController();
  bool isSending = false;
  bool loadImages = true;
  int messageLimit = 30;
  late TabController _tabController;
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  // Send message with length check and ban check
  Future<void> sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    String messageText = msgController.text.trim();
    if (user == null || messageText.isEmpty) return;

    if (messageText.length > 200) {
      Fluttertoast.showToast(msg: "Message too long (max 200 chars).");
      return;
    }

    bool banned = await isUserBanned(user.uid);
    if (banned) {
      Fluttertoast.showToast(msg: "You are muted due to reports.");
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'text': messageText,
        'sender': user.email,
        'senderId': user.uid,
        'time': Timestamp.now(),
        'reactions': {},
      });
      msgController.clear();
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to send message.");
    }

    setState(() {
      isSending = false;
    });
  }

  // Check if user banned from group messaging
  Future<bool> isUserBanned(String userId) async {
    final reportDoc = await FirebaseFirestore.instance.collection('reports').doc(userId).get();
    if (!reportDoc.exists) return false;

    final bannedUntilTimestamp = reportDoc.data()?['bannedUntil'];
    if (bannedUntilTimestamp == null) return false;

    final bannedUntil = (bannedUntilTimestamp as Timestamp).toDate();
    return DateTime.now().isBefore(bannedUntil);
  }

  // Report user (group ban logic)
  Future<void> reportUser(String userId) async {
    final reportDoc = FirebaseFirestore.instance.collection('reports').doc(userId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportDoc);
      if (!snapshot.exists) {
        transaction.set(reportDoc, {
          'count': 1,
          'lastReported': FieldValue.serverTimestamp(),
          'bannedUntil': null,
        });
      } else {
        int currentCount = snapshot['count'] ?? 0;
        currentCount++;
        DateTime? newBanUntil;

        DateTime now = DateTime.now();

        if (currentCount == 5) {
          newBanUntil = now.add(Duration(days: 10));
        } else if (currentCount == 6) {
          newBanUntil = now.add(Duration(days: 20));
        } else if (currentCount >= 7) {
          newBanUntil = now.add(Duration(days: 30));
        }

        transaction.update(reportDoc, {
          'count': currentCount,
          'lastReported': FieldValue.serverTimestamp(),
          'bannedUntil': newBanUntil,
        });
      }
    });

    Fluttertoast.showToast(msg: "User reported.");
  }

  // Log out user
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AuthPage()));
  }

  // Toggle data saver (just UI icon for now)
  void toggleDataSaver() {
    setState(() {
      loadImages = !loadImages;
    });
  }

  // Build chat message list
  Widget buildMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .orderBy('time', descending: true)
          .limit(messageLimit)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return ListView.builder(
          reverse: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final msg = docs[index];
            final text = msg['text'] ?? '';
            final sender = msg['sender'] ?? 'Unknown';
            final senderId = msg['senderId'] ?? '';
            final reactions = Map<String, dynamic>.from(msg['reactions'] ?? {});
            final msgId = msg.id;

            return ListTile(
              title: Text(text),
              subtitle: Text(sender),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...reactions.entries.map((e) => Text("${e.key} ${e.value}")),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'Report') {
                        if (senderId == currentUserId) {
                          Fluttertoast.showToast(msg: "You can't report yourself.");
                          return;
                        }
                        await reportUser(senderId);
                      } else if (value == 'React 👍') {
                        await reactToMessage(msgId, '👍');
                      } else if (value == 'React ❤️') {
                        await reactToMessage(msgId, '❤️');
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'Report', child: Text('Report')),
                      PopupMenuItem(value: 'React 👍', child: Text('React 👍')),
                      PopupMenuItem(value: 'React ❤️', child: Text('React ❤️')),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> reactToMessage(String msgId, String reaction) async {
    final msgRef = FirebaseFirestore.instance.collection('messages').doc(msgId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(msgRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> reactions = Map<String, dynamic>.from(snapshot['reactions'] ?? {});
      reactions[reaction] = (reactions[reaction] ?? 0) + 1;

      transaction.update(msgRef, {'reactions': reactions});
    });
  }

  // Stories Tab
  Widget buildStories() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final users = snapshot.data!.docs;

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final stories = List.from(user['stories'] ?? []);
            final name = user['name'] ?? 'Unknown';
            final username = user['username'] ?? '';
            final pfpUrl = ''; // You can add photo url later

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  CircleAvatar(radius: 30, child: Text(name[0].toUpperCase())),
                  SizedBox(height: 4),
                  Text(username, style: TextStyle(fontSize: 12)),
                  if (stories.isNotEmpty)
                    Container(
                      width: 50,
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: stories.length,
                        itemBuilder: (context, i) {
                          final story = stories[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Container(
                              width: 50,
                              height: 70,
                              color: Colors.blueAccent,
                              child: Center(child: Text(story['text'] ?? '', style: TextStyle(color: Colors.white, fontSize: 10))),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Profile Tab
  Widget buildProfile() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final user = snapshot.data!;
        final name = user['name'] ?? '';
        final username = user['username'] ?? '';
        final bio = user['bio'] ?? '';
        final skill = user['skill'] ?? '';
        final verified = user['verified'] ?? false;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(radius: 40, child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A', style: TextStyle(fontSize: 40))),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  if (verified) ...[
                    SizedBox(width: 6),
                    Icon(Icons.verified, color: Colors.blueAccent),
                  ],
                ],
              ),
              Text('@$username', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 10),
              Text(bio),
              SizedBox(height: 10),
              Text(bio),
              SizedBox(height: 10),
              Text('Skill: $skill'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // Simple toggle verified for demo
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
                  final doc = await docRef.get();
                  final currentVerified = doc['verified'] ?? false;
                  await docRef.update({'verified': !currentVerified});
                  setState(() {});
                },
                child: Text('Toggle Verified Badge (Demo)'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AuthPage()));
                },
                child: Text('Logout'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AE Chat'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.message), text: 'Chats'),
            Tab(icon: Icon(Icons.auto_stories), text: 'Stories'),
            Tab(icon: Icon(Icons.person), text: 'Profile'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(loadImages ? Icons.data_usage : Icons.data_saver_on),
            tooltip: loadImages ? 'Data Saver Off' : 'Data Saver On',
            onPressed: toggleDataSaver,
          ),
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildMessages(),
          buildStories(),
          buildProfile(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: _tabController.index == 0
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msgController,
                      maxLength: 200,
                      maxLines: 3,
                      decoration: InputDecoration(hintText: 'Enter message'),
                    ),
                  ),
                  IconButton(
                    icon: isSending ? CircularProgressIndicator() : Icon(Icons.send),
                    onPressed: isSending ? null : sendMessage,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// Settings Page
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // For now, simple placeholder
    return Center(
      child: Text('Settings will come here'),
    );
  }
}