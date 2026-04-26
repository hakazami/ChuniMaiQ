import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

// IMPORTANT: We need this URL from the Realtime Database tab!
const String FIREBASE_DATABASE_URL = "https://chunimaiq-default-rtdb.asia-southeast1.firebasedatabase.app";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDB6_wejyoIdX65mYCsNBUuQO08V6Rl12s",
      appId: "1:953315725615:web:d3eb0660a89691d17551da",
      messagingSenderId: "953315725615",
      projectId: "chunimaiq",
      databaseURL: FIREBASE_DATABASE_URL,
    )
  );

  runApp(const ChunimaiQApp());
}

// --- Data Models & Global State ---
class Player {
  String id;
  String name;
  String mode; // 'PendingMatch', 'PairedMatch', 'Solo'
  String status; // 'Antre', 'Bermain'
  String time;
  bool isAfk;
  int skipCount;
  int timestamp;
  Map<dynamic, dynamic>? inviteData;

  Player({
    required this.id,
    required this.name,
    required this.mode,
    required this.status,
    required this.time,
    required this.isAfk,
    required this.skipCount,
    required this.timestamp,
    this.inviteData,
  });

  factory Player.fromMap(String key, Map<dynamic, dynamic> map) {
    return Player(
      id: key,
      name: map['name'] ?? '',
      mode: map['mode'] ?? '',
      status: map['status'] ?? 'Antre',
      time: map['time'] ?? '',
      isAfk: map['isAfk'] ?? false,
      skipCount: map['skipCount'] ?? 0,
      timestamp: map['timestamp'] ?? 0,
      inviteData: map['inviteData'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mode': mode,
      'status': status,
      'time': time,
      'isAfk': isAfk,
      'skipCount': skipCount,
      'timestamp': timestamp,
      'inviteData': inviteData,
    };
  }
}

class AppState {
  static String currentGame = "maimai DX";
  static const int minutesPerTurn = 5;
  static String? myPlayerId; // Stores THIS specific phone's identity
  static String? myOriginalName; // Stores original name before pairing
  static bool isAdmin = false; // Secret Admin mode
}

// --- App Root ---
class ChunimaiQApp extends StatelessWidget {
  const ChunimaiQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChunimaiQ!',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0a0a0f),
        primaryColor: const Color(0xFF00f2fe),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00f2fe),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HubScreen(),
    );
  }
}

// --- HUB SCREEN ---
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  int maimaiCount = 0;
  int chunithmCount = 0;

  bool isQueuedMaimai = false;
  bool isQueuedChunithm = false;

  Future<void> _checkWipe(String gameName) async {
    final metaSnap = await FirebaseDatabase.instance.ref('queues/$gameName/meta/lastActive').get();
    if (metaSnap.exists) {
      int lastActive = metaSnap.value as int;
      int now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastActive > 30 * 60 * 1000) { // 30 minutes
        await FirebaseDatabase.instance.ref('queues/$gameName').remove();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen for live counts after checking wipe
    _checkWipe('maimai DX').then((_) {
      FirebaseDatabase.instance.ref('queues/maimai DX').onValue.listen((event) {
        if (mounted) {
          bool queued = false;
          if (event.snapshot.exists && AppState.myPlayerId != null) {
            final map = event.snapshot.value as Map<dynamic, dynamic>;
            queued = map.containsKey(AppState.myPlayerId);
          }
          setState(() {
            // exclude 'meta' from count
            maimaiCount = event.snapshot.exists ? event.snapshot.children.where((c) => c.key != 'meta').length : 0;
            isQueuedMaimai = queued;
          });
        }
      });
    });

    _checkWipe('CHUNITHM').then((_) {
      FirebaseDatabase.instance.ref('queues/CHUNITHM').onValue.listen((event) {
        if (mounted) {
          bool queued = false;
          if (event.snapshot.exists && AppState.myPlayerId != null) {
            final map = event.snapshot.value as Map<dynamic, dynamic>;
            queued = map.containsKey(AppState.myPlayerId);
          }
          setState(() {
            // exclude 'meta' from count
            chunithmCount = event.snapshot.exists ? event.snapshot.children.where((c) => c.key != 'meta').length : 0;
            isQueuedChunithm = queued;
          });
        }
      });
    });
  }

  Future<void> _handleGameSelect(String gameName) async {
    AppState.currentGame = gameName;

    // Session Recovery
    if (AppState.isAdmin) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      return;
    }

    if (AppState.myPlayerId != null) {
      final snapshot = await FirebaseDatabase.instance.ref('queues/$gameName/${AppState.myPlayerId}').get();
      if (snapshot.exists) {
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
          return;
        }
      }
    }
    
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LandingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'ChunimaiQ!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Color(0xFF00f2fe)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sistem Antrean maimai & CHUNITHM',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              const Text(
                'Cek & Pilih Game',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              _buildGameCard(
                "maimai DX", 
                "assets/images/maimai.png", 
                maimaiCount, 
                maimaiCount * AppState.minutesPerTurn,
                const Color(0xFF00f2fe),
                isQueuedMaimai,
              ),
              const SizedBox(height: 24),
              _buildGameCard(
                "CHUNITHM", 
                "assets/images/chunithm.png", 
                chunithmCount, 
                chunithmCount * AppState.minutesPerTurn,
                const Color(0xFFffb100),
                isQueuedChunithm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(String gameName, String imagePath, int count, int time, Color color, bool isQueued) {
    return Container(
      decoration: BoxDecoration(
        color: isQueued ? color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isQueued ? color : Colors.white.withValues(alpha: 0.1), width: isQueued ? 2 : 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Image.asset(imagePath, height: 120, errorBuilder: (context, error, stackTrace) => const SizedBox(height: 120, child: Icon(Icons.videogame_asset, size: 60))),
          const SizedBox(height: 16),
          if (isQueued)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Text('✅ Anda Terdaftar', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              onPressed: () => _handleGameSelect(gameName),
              child: Text(gameName, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('👥 $count Antrean', style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 16),
                Text('⏱️ ~$time m', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- LANDING SCREEN ---
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _joinQueue() async {
    String name = _nameController.text.trim().toUpperCase();
    
    // SECRET ADMIN LOGIN
    if (name == "ADMIN") {
      AppState.isAdmin = true;
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
      return;
    }

    if (name.isEmpty) {
      name = "GUEST_${DateTime.now().millisecondsSinceEpoch % 100}";
    }

    FirebaseDatabase.instance.ref('queues/${AppState.currentGame}/meta/lastActive').set(ServerValue.timestamp);

    // 1. AUTO-PAIRING SEARCH (maimai DX only)
    if (AppState.currentGame == "maimai DX") {
      final snapshot = await FirebaseDatabase.instance.ref('queues/${AppState.currentGame}').get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> map = snapshot.value as Map<dynamic, dynamic>;
        List<Player> list = map.entries
            .where((e) => e.key != 'meta')
            .map((e) => Player.fromMap(e.key, e.value as Map<dynamic, dynamic>))
            .toList();
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        try {
          Player target = list.firstWhere((p) => p.mode == "PendingMatch" && !p.isAfk);
          
          // WE FOUND A PARTNER! Join their record.
          AppState.myPlayerId = target.id;
          AppState.myOriginalName = name;
          AppState.isAdmin = false;

          await FirebaseDatabase.instance.ref('queues/${AppState.currentGame}/${target.id}').update({
            'name': '${target.name} & $name',
            'mode': 'PairedMatch',
          });

          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
          }
          return;
        } catch (e) {
          // No partner found, proceed to create new record
        }
      }
    }

    // 2. NO PARTNER FOUND - JOIN AS NEW RECORD
    String mode = (AppState.currentGame == "maimai DX") ? "PendingMatch" : "Solo";
    String now = DateTime.now().toLocal().toString().split(' ')[1].split('.')[0]; // HH:mm:ss
    String timeStr = now;

    String newPlayerId = const Uuid().v4();
    AppState.myPlayerId = newPlayerId;
    AppState.myOriginalName = name;
    AppState.isAdmin = false;

    DatabaseReference ref = FirebaseDatabase.instance.ref('queues/${AppState.currentGame}/$newPlayerId');
    
    await ref.set({
      'name': name,
      'mode': mode,
      'status': "Antre",
      'time': timeStr,
      'isAfk': false,
      'skipCount': 0,
      'timestamp': ServerValue.timestamp,
    });

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppState.currentGame,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00f2fe)),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  const Text('Daftar Antrean', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Masukkan inisial/nama kamu untuk mulai mengantre!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    maxLength: 12,
                    decoration: InputDecoration(
                      labelText: 'Inisial Player',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF00f2fe)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _joinQueue,
                      child: const Text('MASUK ANTREAN'),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DASHBOARD SCREEN ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseReference _queueRef = FirebaseDatabase.instance.ref('queues/${AppState.currentGame}');
  StreamSubscription? _inviteSub;
  bool _isShowingInvite = false;

  void _heartbeat() {
    FirebaseDatabase.instance.ref('queues/${AppState.currentGame}/meta/lastActive').set(ServerValue.timestamp);
  }

  @override
  void initState() {
    super.initState();
    _bindPlayerListener();
  }

  void _bindPlayerListener() {
    _inviteSub?.cancel();
    if (AppState.myPlayerId != null && !AppState.isAdmin) {
      _inviteSub = _queueRef.child(AppState.myPlayerId!).onValue.listen((event) {
        if (!event.snapshot.exists) {
          // Our record was deleted (e.g. partner pressed Selesai, or Admin kicked us)
          if (mounted) {
            AppState.myPlayerId = null;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HubScreen()));
          }
          return;
        }

        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          
          // 1. Check for incoming invites
          if (data['inviteData'] != null && !_isShowingInvite) {
            // Only show if the invite is specifically for ME
            if (data['inviteData']['toName'] == AppState.myOriginalName) {
              _isShowingInvite = true;
              _showInviteDialog(data['inviteData']);
            }
          }

          // 1.1 Auto-dismiss invite if it's gone from DB
          if (data['inviteData'] == null && _isShowingInvite) {
            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
              _isShowingInvite = false;
            }
          }

          // 2. Check for Declined invites
          if (data['declinedBy'] != null) {
            String decliner = data['declinedBy'];
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$decliner menolak ajakan party Anda.'), backgroundColor: Colors.redAccent)
              );
            }
            _queueRef.child(AppState.myPlayerId!).child('declinedBy').remove();
          }
          
          // 3. Check for Identity Transfer (we were merged into someone else)
          if (data['mergedInto'] != null) {
            String targetId = data['mergedInto'];
            String oldId = AppState.myPlayerId!;
            
            AppState.myPlayerId = targetId; // Transfer identity!
            _queueRef.child(oldId).remove(); // Delete our old ghost shell
            
            _bindPlayerListener(); // Re-bind to our new identity
          }

          // 4. Check for Kicked Status
          if (data['status'] == 'Kicked') {
            _showKickedDialog();
          }
        }
      });

      // 5. Global Identity Router (Identity Teleportation for Swaps)
      FirebaseDatabase.instance.ref('queues/${AppState.currentGame}/meta/transfers/${AppState.myOriginalName}').onValue.listen((event) {
        if (event.snapshot.exists) {
          String newId = event.snapshot.value as String;
          AppState.myPlayerId = newId;
          
          // Clear the transfer entry
          event.snapshot.ref.remove();
          
          _bindPlayerListener();
        }
      });
    }
  }

  void _showKickedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a24),
        title: const Text('⚠️ Dikeluarkan', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Anda telah dikeluarkan dari antrean karena telah di-skip sebanyak 3 kali (AFK).'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _queueRef.child(AppState.myPlayerId!).remove();
              AppState.myPlayerId = null;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HubScreen()));
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
  }

  void _showInviteDialog(Map<dynamic, dynamic> inviteData) {
    bool isSwap = inviteData['type'] == 'Swap';
    String from = inviteData['fromName'] ?? 'Seseorang';
    String action = isSwap ? 'swap partner' : 'pair';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a24),
        title: Text(isSwap ? '🔄 Swap Invite!' : '🎉 Party Invite!', style: TextStyle(color: isSwap ? Colors.orange : const Color(0xFFffb100))),
        content: Text('$from invited you to $action!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _isShowingInvite = false;
              _queueRef.child(AppState.myPlayerId!).child('inviteData').remove();
              // Notify the inviter
              _queueRef.child(inviteData['fromId']).update({
                'declinedBy': inviteData['toName']
              });
            }, 
            child: const Text('Tolak', style: TextStyle(color: Colors.redAccent))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00f2fe)),
            onPressed: () {
              Navigator.pop(ctx);
              _isShowingInvite = false;
              
              if (inviteData['type'] == 'Swap') {
                _executeSwap(inviteData);
              } else {
                // Accept the pair
                _queueRef.child(AppState.myPlayerId!).update({
                  'mode': 'PairedMatch',
                  'name': '${inviteData['fromName']} & ${inviteData['toName']}',
                  'inviteData': null
                });
                // Perform Identity Transfer handshake instead of deleting
                _queueRef.child(inviteData['fromId']).update({
                  'mergedInto': AppState.myPlayerId
                });
              }
              _heartbeat();
            }, 
            child: const Text('Terima')
          )
        ],
      )
    );
  }

  void _ajakPair(Player targetPlayer, Player me) {
    _queueRef.child(targetPlayer.id).child('inviteData').set({
      'type': 'Pair',
      'fromId': me.id,
      'fromName': me.name,
      'toName': targetPlayer.name
    });
    _heartbeat();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menunggu respons dari ${targetPlayer.name}...'), backgroundColor: Colors.orange)
    );
  }

  void _ajakSwap(Player targetGroup, Player me) {
    // 1. Choose who from MY party is swapping
    List<String> myPartners = me.name.split('&').map((s) => s.trim()).toList();
    List<String> targetPartners = targetGroup.name.split('&').map((s) => s.trim()).toList();

    if (myPartners.length < 2 || targetPartners.length < 2) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a24),
        title: const Text('Siapa yang akan swap dari party Anda?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: myPartners.map((myPart) => ListTile(
            title: Text(myPart),
            onTap: () {
              Navigator.pop(ctx);
              // 2. Choose who from THEIR party to swap with
              showDialog(
                context: context,
                builder: (ctx2) => AlertDialog(
                  backgroundColor: const Color(0xFF1a1a24),
                  title: Text('Swap $myPart dengan siapa?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: targetPartners.map((tPart) => ListTile(
                      title: Text(tPart),
                      onTap: () {
                        Navigator.pop(ctx2);
                        _queueRef.child(targetGroup.id).child('inviteData').set({
                          'type': 'Swap',
                          'fromId': me.id,
                          'fromGroupName': me.name,
                          'fromName': myPart, // Now adding fromName for the dialog
                          'toName': tPart, // Target player specifically
                          'initiatorSwapper': myPart,
                          'targetSwapper': tPart,
                          'targetGroupId': targetGroup.id,
                          'targetGroupName': targetGroup.name,
                        });
                        _heartbeat();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Menunggu respons dari $tPart...'), backgroundColor: Colors.orange)
                        );
                      },
                    )).toList(),
                  ),
                ),
              );
            },
          )).toList(),
        ),
      ),
    );
  }

  void _executeSwap(Map<dynamic, dynamic> inviteData) async {
    // inviteData: {fromId (ID 2), fromGroupName (Joe & Bill), initiatorSwapper (Joe), targetSwapper (HKZ), targetGroupId (ID 1), targetGroupName (HKZ & Greg)}
    
    String idA = inviteData['targetGroupId']; // ID 1
    String idB = inviteData['fromId']; // ID 2
    
    String joe = inviteData['initiatorSwapper']; // The one leaving ID 2
    String hkz = inviteData['targetSwapper']; // The one leaving ID 1
    
    // Staying behind
    String greg = inviteData['targetGroupName'].split('&').map((s) => s.trim()).firstWhere((s) => s != hkz, orElse: () => "PartnerA");
    String bill = inviteData['fromGroupName'].split('&').map((s) => s.trim()).firstWhere((s) => s != joe, orElse: () => "PartnerB");

    // Execution:
    // ID 1 (was HKZ & Greg) -> becomes Joe & Greg
    // ID 2 (was Joe & Bill) -> becomes HKZ & Bill
    
    await _queueRef.child(idA).update({
      'name': '$joe & $greg',
      'inviteData': null,
    });
    
    await _queueRef.child(idB).update({
      'name': '$hkz & $bill',
    });

    // Teleportation:
    // Joe moves from idB -> idA
    // HKZ moves from idA -> idB
    // (Greg stays idA, Bill stays idB)
    
    await FirebaseDatabase.instance.ref('queues/${AppState.currentGame}/meta/transfers/$joe').set(idA);
    await FirebaseDatabase.instance.ref('queues/${AppState.currentGame}/meta/transfers/$hkz').set(idB);
  }

  void _adminDeletePlayer(String playerId) {
    _queueRef.child(playerId).remove();
    _heartbeat();
  }

  void _mulaiMain() {
    if (AppState.myPlayerId != null) {
      _queueRef.child(AppState.myPlayerId!).update({'status': 'Bermain'});
      _heartbeat();
    }
  }

  Future<void> _selesaiMain() async {
    if (AppState.myPlayerId != null) {
      // 1. Scan for AFK players and increment skipCount (The 2-Skip Rule)
      final snapshot = await _queueRef.get();
      if (snapshot.exists) {
        final map = snapshot.value as Map<dynamic, dynamic>;
        for (var entry in map.entries) {
          if (entry.key == 'meta') continue;
          Player p = Player.fromMap(entry.key, entry.value as Map<dynamic, dynamic>);
          if (p.isAfk) {
            int newSkip = p.skipCount + 1;
            if (newSkip >= 3) {
              await _queueRef.child(p.id).update({'status': 'Kicked'}); // Move to Kicked status
            } else {
              await _queueRef.child(p.id).update({'skipCount': newSkip});
            }
          }
        }
      }

      // 2. Leave
      _queueRef.child(AppState.myPlayerId!).remove();
      AppState.myPlayerId = null;
      _heartbeat();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HubScreen()));
    }
  }

  void _toggleAfk(Player me) {
    if (AppState.myPlayerId != null) {
      if (!me.isAfk && me.mode == 'PairedMatch' && AppState.myOriginalName != null) {
        // We are going AFK while paired! Unpairing Protocol.
        String remainingName = me.name.replaceAll(AppState.myOriginalName!, '').replaceAll('&', '').trim();
        if (remainingName.isEmpty) remainingName = "GUEST";
        
        // 1. Leave the remaining person in their spot
        _queueRef.child(AppState.myPlayerId!).update({
          'name': remainingName,
          'mode': 'PendingMatch'
        });
        
        // 2. Create a NEW record for ourselves with the exact same timestamp
        String newPlayerId = const Uuid().v4();
        AppState.myPlayerId = newPlayerId; // Swap our phone to the new ID
        _queueRef.child(newPlayerId).set({
          'name': AppState.myOriginalName,
          'mode': 'PendingMatch',
          'status': 'Antre',
          'time': me.time,
          'isAfk': true, // Immediately AFK
          'skipCount': 0,
          'timestamp': me.timestamp, // Keep the same timestamp!
        });
        _bindPlayerListener(); // Rebind to new ID
      } else {
        // Normal AFK toggle
        _queueRef.child(AppState.myPlayerId!).update({'isAfk': !me.isAfk});
      }
      _heartbeat();
    }
  }

  void _leaveQueue(Player me) {
    if (AppState.myPlayerId != null) {
      if (me.mode == 'PairedMatch' && AppState.myOriginalName != null) {
        _unpair(me);
      } else {
        // Normal leave
        _queueRef.child(AppState.myPlayerId!).remove();
      }
      AppState.myPlayerId = null;
      _heartbeat();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HubScreen()));
    }
  }

  void _unpair(Player me) {
    String remainingName = me.name.replaceAll(AppState.myOriginalName!, '').replaceAll('&', '').trim();
    if (remainingName.isEmpty) remainingName = "GUEST";
    
    _queueRef.child(AppState.myPlayerId!).update({
      'name': remainingName,
      'mode': 'PendingMatch'
    });
  }

  void _switchToSolo(Player me) {
    if (AppState.myPlayerId == null) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a24),
        title: const Text('⚠️ Main Solo?', style: TextStyle(color: Colors.orange)),
        content: const Text('Bermain Solo kurang disarankan saat antrean panjang demi efisiensi mesin. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (me.mode == 'PairedMatch') {
                // Break party and become solo
                _unpair(me);
                
                // Create a new solo record for ourselves
                String newId = const Uuid().v4();
                AppState.myPlayerId = newId;
                _queueRef.child(newId).set({
                  'name': AppState.myOriginalName,
                  'mode': 'Solo',
                  'status': 'Antre',
                  'time': me.time,
                  'isAfk': false,
                  'skipCount': 0,
                  'timestamp': me.timestamp + 1, // slightly behind original
                });
                _bindPlayerListener();
              } else {
                // Just change mode to Solo
                _queueRef.child(AppState.myPlayerId!).update({'mode': 'Solo'});
              }
              _heartbeat();
            },
            child: const Text('Ya, Solo'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // REMOVE Duplicate Back Button
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppState.currentGame + (AppState.isAdmin ? " [ADMIN]" : ""), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Galaxy Mall Surabaya', style: TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HubScreen())),
          )
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _queueRef.orderByChild('timestamp').onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("Antrean kosong.", style: TextStyle(color: Colors.white54)));
          }

          Map<dynamic, dynamic> map = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List<Player> list = map.entries.where((e) => e.key != 'meta').map((e) => Player.fromMap(e.key, e.value as Map<dynamic, dynamic>)).toList();
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          int activeCount = list.where((p) => !p.isAfk).length;
          
          // Find "Me"
          Player? me;
          if (!AppState.isAdmin) {
            try {
              me = list.firstWhere((p) => p.id == AppState.myPlayerId);
            } catch (e) {
              me = null;
            }
          }

          // 4-Button Logic
          bool isRank1 = (me != null && !me.isAfk && list.where((p)=>!p.isAfk).toList().indexOf(me) == 0);
          bool canMulai = (isRank1 && me!.status == "Antre");
          bool canSelesai = (me != null && me.status == "Bermain");
          bool canAfk = (me != null && me.status != "Bermain");

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Menunggu ...', activeCount.toString())),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Estimasi Waktu', '~${activeCount * AppState.minutesPerTurn}m')),
                  ],
                ),
                const SizedBox(height: 24),
                const Align(alignment: Alignment.centerLeft, child: Text('Antrean Selanjutnya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      var player = list[index];
                      bool isCurrentTurn = (!player.isAfk && list.where((p)=>!p.isAfk).toList().indexOf(player) == 0);
                      bool isMe = player.id == AppState.myPlayerId;
                      
                      Color cardColor = isCurrentTurn ? const Color(0xFF00f2fe).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05);
                      Color borderColor = isMe ? Colors.orange : (isCurrentTurn ? const Color(0xFF00f2fe) : (player.isAfk ? Colors.white54 : Colors.white.withValues(alpha: 0.1)));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: isMe ? 2 : 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(player.name + (isMe ? " (You)" : ""), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: player.isAfk ? Colors.white54 : (isMe ? Colors.orange : Colors.white))),
                                      Text('🕒 ${player.time}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (player.isAfk)
                                        _buildBadge('💤 AFK Skiped (Peringatan ${player.skipCount}/3)', Colors.white54),
                                      if (!player.isAfk && player.mode == "PairedMatch")
                                        _buildBadge('✅ Paired Game', Colors.green),
                                      if (!player.isAfk && player.mode == "Solo")
                                        _buildBadge('👤 Solo Play', Colors.orange),
                                      if (!player.isAfk && player.mode == "PendingMatch" && AppState.currentGame == "maimai DX")
                                        _buildBadge('Tersedia Pairing', Colors.white54),
                                    ],
                                  ),
                                  
                                  // Pairing/Swap Buttons
                                  if (!isMe && me != null && !player.isAfk && AppState.currentGame == "maimai DX")
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          // Ajak Pair: Only if both sides are solitary (Solo/Pending)
                                          if (player.mode == "PendingMatch" && (me!.mode == "PendingMatch" || me!.mode == "Solo"))
                                            OutlinedButton.icon(
                                              onPressed: () => _ajakPair(player, me!), 
                                              icon: const Icon(Icons.add, size: 16), 
                                              label: const Text('Ajak Pair', style: TextStyle(fontSize: 12)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF00f2fe),
                                                side: const BorderSide(color: Color(0xFF00f2fe)),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                minimumSize: const Size(0, 24),
                                              ),
                                            ),
                                          // Ajak Swap: Only if both sides are already Paired
                                          if (player.mode == "PairedMatch" && me!.mode == "PairedMatch")
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: OutlinedButton.icon(
                                                onPressed: () => _ajakSwap(player, me!), 
                                                icon: const Icon(Icons.swap_horiz, size: 16), 
                                                label: const Text('Ajak Swap', style: TextStyle(fontSize: 12)),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.orange,
                                                  side: const BorderSide(color: Colors.orange),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                  minimumSize: const Size(0, 24),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(isCurrentTurn ? (player.status == 'Bermain' ? '🔥 SEDANG BERMAIN' : '💫 GILIRAN SEKARANG') : 'Menunggu antrean', style: TextStyle(fontSize: 12, color: isCurrentTurn ? const Color(0xFF00f2fe) : Colors.white54, fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            ),
                            if (AppState.isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _adminDeletePlayer(player.id),
                              )
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // --- 4 BUTTON UI STATE (Bottom) ---
                if (!AppState.isAdmin && me != null)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: canMulai ? _mulaiMain : null,
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('MULAI MAIN'),
                                style: ElevatedButton.styleFrom(backgroundColor: canMulai ? Colors.green : Colors.grey.shade800),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: canSelesai ? _selesaiMain : null,
                                icon: const Icon(Icons.stop, size: 18),
                                label: const Text('SELESAI'),
                                style: ElevatedButton.styleFrom(backgroundColor: canSelesai ? Colors.redAccent : Colors.grey.shade800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: canAfk ? () => _toggleAfk(me!) : null, 
                                icon: const Icon(Icons.nightlight_round, size: 16), 
                                label: Text(me!.isAfk ? 'Batal AFK' : 'Tandai AFK'),
                                style: OutlinedButton.styleFrom(foregroundColor: canAfk ? Colors.orange : Colors.grey.shade600, side: BorderSide(color: canAfk ? Colors.orange : Colors.grey.shade600)),
                              )
                            ),
                            const SizedBox(width: 12),
                            if (me!.mode != "Solo")
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _switchToSolo(me!), 
                                  icon: const Icon(Icons.person, size: 16), 
                                  label: const Text('Main Solo'),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                                )
                              ),
                            if (me!.mode == "Solo")
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _leaveQueue(me!), 
                                  icon: const Icon(Icons.exit_to_app, size: 16), 
                                  label: const Text('Keluar'),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                                )
                              ),
                          ],
                        ),
                        if (me!.mode != "Solo")
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: OutlinedButton.icon(
                              onPressed: () => _leaveQueue(me!), 
                              icon: const Icon(Icons.exit_to_app, size: 16), 
                              label: const Text('Keluar dari Antrean'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                            ),
                          ),
                      ],
                    ),
                  ),

                // --- ADMIN CONTROL PANEL ---
                if (AppState.isAdmin)
                   Container(
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                         ElevatedButton.icon(
                           onPressed: () {
                             String newId = const Uuid().v4();
                             _queueRef.child(newId).set({
                               'name': 'DUMMY_${DateTime.now().millisecondsSinceEpoch % 1000}',
                               'mode': AppState.currentGame == 'maimai DX' ? 'PendingMatch' : 'Solo',
                               'status': 'Antre',
                               'time': DateTime.now().toLocal().toString().split(' ')[1].split('.')[0], // HH:mm:ss
                               'isAfk': false,
                               'skipCount': 0,
                               'timestamp': ServerValue.timestamp,
                             });
                             _heartbeat();
                           },
                           icon: const Icon(Icons.add, size: 18),
                           label: const Text('TAMBAH DUMMY PLAYER'),
                         ),
                         const SizedBox(height: 12),
                         Row(
                           children: [
                             Expanded(
                               child: OutlinedButton.icon(
                                 onPressed: () {
                                   _queueRef.remove();
                                   _heartbeat();
                                 }, // Nukes the entire queue!
                                 icon: const Icon(Icons.delete_sweep, size: 16), 
                                 label: const Text('Kosongkan Antrean'),
                                 style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                               )
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               child: OutlinedButton.icon(
                                 onPressed: () {
                                   AppState.isAdmin = false;
                                   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HubScreen()));
                                 }, 
                                 icon: const Icon(Icons.exit_to_app, size: 16), 
                                 label: const Text('Keluar Admin'),
                                 style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white70)),
                               )
                             ),
                           ],
                         )
                       ],
                     ),
                   )
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildStatCard(String label, String val) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00f2fe))),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
