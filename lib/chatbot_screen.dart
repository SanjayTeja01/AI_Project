
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:campus_gaurd_final/profile_screen.dart';
import 'package:campus_gaurd_final/contacts_screen.dart';
import 'package:campus_gaurd_final/sos_screen.dart';
import 'package:campus_gaurd_final/active_sos_screen.dart';
import 'package:campus_gaurd_final/auth_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

enum BotState { idle, listening, processing }
enum MessageType { user, bot }

class ChatMessage {
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final String? documentId; // For Firestore document ID

  ChatMessage({
    required this.text,
    required this.type,
    required this.timestamp,
    this.documentId,
  });

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'type': type == MessageType.user ? 'user' : 'bot',
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // Create from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      text: data['text'] as String? ?? '',
      type: data['type'] == 'user' ? MessageType.user : MessageType.bot,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      documentId: doc.id,
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int messageCount;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    required this.messageCount,
  });

  factory ChatSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSession(
      id: doc.id,
      title: data['title'] as String? ?? 'New Chat',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      messageCount: data['messageCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'messageCount': messageCount,
    };
  }
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Chat messages list
  final List<ChatMessage> _messages = [];

  // Conversation history for context awareness (keeps last 10 exchanges)
  final List<String> _conversationHistory = [];

  // Chat sessions
  final List<ChatSession> _chatSessions = [];
  String? _currentSessionId;

  // Animation controller for chatbot icon
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  String _currentLocale = '';
  String _username = 'User';
  BotState _botState = BotState.idle;
  bool _hasShownWelcome = false;
  bool _isLoadingHistory = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    
    _userId = _auth.currentUser?.uid;
    
    // Initialize animation controller for chatbot icon
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _initSpeech();
    _initTts();
    _fetchUsername();
    _loadChatSessions(); // Load chat sessions first
    _textController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // Load chat sessions list (for initial load)
  Future<void> _loadChatSessions() async {
    if (_userId == null) {
      setState(() {
        _isLoadingHistory = false;
        _hasShownWelcome = false;
      });
      _createNewSession();
      return;
    }

    try {
      final sessionsSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chat_sessions')
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          _chatSessions.clear();
          for (var doc in sessionsSnapshot.docs) {
            _chatSessions.add(ChatSession.fromFirestore(doc));
          }
        });

        // If no sessions exist, create a new one
        if (_chatSessions.isEmpty) {
          await _createNewSession();
        } else {
          // Load the most recent session
          await _loadSession(_chatSessions.first.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        await _createNewSession();
      }
    }
  }
  
  // Create a new chat session
  Future<void> _createNewSession() async {
    if (_userId == null) {
      setState(() {
        _currentSessionId = null;
        _messages.clear();
        _isLoadingHistory = false;
        _hasShownWelcome = false; // Reset to show welcome
      });
      _showWelcomeMessage();
      return;
    }

    try {
      final newSessionRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chat_sessions')
          .add({
        'title': 'New Chat',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'messageCount': 0,
      });

      final newSession = ChatSession(
        id: newSessionRef.id,
        title: 'New Chat',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messageCount: 0,
      );

      if (mounted) {
        setState(() {
          _currentSessionId = newSessionRef.id;
          _messages.clear();
          _conversationHistory.clear();
          _chatSessions.insert(0, newSession);
          _isLoadingHistory = false;
          _hasShownWelcome = false; // Reset to show welcome for new session
        });
        
        // Show welcome message immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasShownWelcome && _messages.isEmpty && !_isLoadingHistory) {
            _showWelcomeMessage();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentSessionId = null;
          _messages.clear();
          _isLoadingHistory = false;
          _hasShownWelcome = false; // Reset to show welcome
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showWelcomeMessage();
          }
        });
      }
    }
  }
  
  // Load a specific chat session
  Future<void> _loadSession(String sessionId) async {
    if (_userId == null || sessionId == _currentSessionId) return;

    setState(() {
      _isLoadingHistory = true;
      _currentSessionId = sessionId;
      _messages.clear();
    });

    try {
      final messagesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chat_sessions')
          .doc(sessionId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      if (mounted) {
        setState(() {
          _messages.clear();
          _conversationHistory.clear();
          for (var doc in messagesSnapshot.docs) {
            final message = ChatMessage.fromFirestore(doc);
            _messages.add(message);
            // Rebuild conversation history
            if (message.type == MessageType.user) {
              _conversationHistory.add(message.text);
            } else if (_conversationHistory.isNotEmpty) {
              _conversationHistory.add(message.text);
            }
          }
          _isLoadingHistory = false;
          // Only show welcome if this is an empty session (new chat)
          if (_messages.isEmpty) {
            _hasShownWelcome = false;
          } else {
            _hasShownWelcome = true; // Don't show welcome for existing sessions with messages
          }
        });

        // Show welcome message if session is empty
        if (_messages.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasShownWelcome && _messages.isEmpty && !_isLoadingHistory) {
              _showWelcomeMessage();
            }
          });
        }

        // Scroll to bottom after loading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          // If error loading, treat as new chat
          if (_messages.isEmpty) {
            _hasShownWelcome = false;
          }
        });
        // Show welcome if empty after error
        if (_messages.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasShownWelcome && _messages.isEmpty && !_isLoadingHistory) {
              _showWelcomeMessage();
            }
          });
        }
      }
    }
  }
  
  // Update session title based on first user message
  Future<void> _updateSessionTitle(String firstUserMessage) async {
    if (_userId == null || _currentSessionId == null) return;

    try {
      final title = firstUserMessage.length > 30 
          ? '${firstUserMessage.substring(0, 30)}...'
          : firstUserMessage;

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chat_sessions')
          .doc(_currentSessionId)
          .update({
        'title': title,
        'updatedAt': Timestamp.now(),
      });

      // Update local session
      if (mounted) {
        setState(() {
          final index = _chatSessions.indexWhere((s) => s.id == _currentSessionId);
          if (index != -1) {
            _chatSessions[index] = ChatSession(
              id: _chatSessions[index].id,
              title: title,
              createdAt: _chatSessions[index].createdAt,
              updatedAt: DateTime.now(),
              messageCount: _chatSessions[index].messageCount,
            );
          }
        });
      }
    } catch (e) {
      // Silent fail
    }
  }
  
  
  // Save message to Firestore (under current session)
  Future<void> _saveMessageToFirestore(ChatMessage message) async {
    if (_userId == null || _currentSessionId == null) return;

    try {
      // Save message to current session
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chat_sessions')
          .doc(_currentSessionId)
          .collection('messages')
          .add(message.toFirestore());

      // Get actual message count from Firestore for accuracy
      final messagesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chat_sessions')
          .doc(_currentSessionId)
          .collection('messages')
          .get();

      final messageCount = messagesSnapshot.docs.length;

      // Update session metadata
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chat_sessions')
          .doc(_currentSessionId)
          .update({
        'updatedAt': Timestamp.now(),
        'messageCount': messageCount,
      });

      // Update session title if this is the first user message
      if (message.type == MessageType.user) {
        // Check if there's only one user message in this session
        final userMessagesSnapshot = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('chat_sessions')
            .doc(_currentSessionId)
            .collection('messages')
            .where('type', isEqualTo: 'user')
            .get();
        
        if (userMessagesSnapshot.docs.length == 1) {
          _updateSessionTitle(message.text);
        }
      }
    } catch (e) {
      // Silent fail - messages will still be shown in UI even if save fails
    }
  }
  
  // Add welcome message when username is fetched
  void _showWelcomeMessage() {
    // Only show welcome if we haven't shown it and we're not loading history
    // and messages are empty (new chat) and we have a session (or null for offline mode)
    if (!_hasShownWelcome && !_isLoadingHistory && _messages.isEmpty && mounted) {
      _hasShownWelcome = true;
      final usernameText = _username.isNotEmpty && _username != 'User' ? _username : 'there';
      final welcomeText = 'Hello $usernameText! 👋 Welcome to Campus Guard. I\'m Chitti, your safety assistant. How can I help you today?';
      _addMessage(welcomeText, MessageType.bot, saveToFirestore: true);
      // Speak welcome message immediately
      _speak(welcomeText, showInChat: false);
    }
  }
  
  // Add message to chat
  void _addMessage(String text, MessageType type, {bool saveToFirestore = true}) {
    final message = ChatMessage(
      text: text,
      type: type,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(message);
    });
    
    // Save to Firestore (async, don't wait)
    if (saveToFirestore) {
      _saveMessageToFirestore(message);
    }
    
    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  // Add user message
  void _addUserMessage(String text) {
    _addMessage(text, MessageType.user);
  }
  
  // Add bot message
  void _addBotMessage(String text) {
    _addMessage(text, MessageType.bot);
  }
  
  // Build chat history drawer (ChatGPT/Gemini style)
  Widget _buildChatHistoryDrawer() {
    return Drawer(
      width: 280, // Width similar to ChatGPT
      child: Column(
        children: [
          // Header with New Chat button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // New Chat button - prominent at top
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _createNewSession();
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'New Chat',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chat History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Chat sessions list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _userId != null
                  ? _firestore
                      .collection('users')
                      .doc(_userId)
                      .collection('chat_sessions')
                      .orderBy('updatedAt', descending: true)
                      .limit(50)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.purple));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading chats',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                List<ChatSession> sessionsList = [];
                if (snapshot.hasData && snapshot.data != null) {
                  sessionsList = snapshot.data!.docs
                      .map((doc) => ChatSession.fromFirestore(doc))
                      .toList();
                }

                if (sessionsList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No chat history yet.\nTap "New Chat" to start!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sessionsList.length,
                  itemBuilder: (context, index) {
                    final session = sessionsList[index];
                    final isActive = session.id == _currentSessionId;
                    
                    return Dismissible(
                      key: Key(session.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: Colors.red[300]),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Chat'),
                            content: const Text('Are you sure you want to delete this chat?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
                      onDismissed: (direction) {
                        _deleteSessionFromDrawer(session.id);
                      },
                      child: ListTile(
                        leading: Icon(
                          Icons.chat_bubble_outline,
                          color: isActive ? Colors.purple : Colors.grey[600],
                          size: 20,
                        ),
                        title: Text(
                          session.title,
                          style: TextStyle(
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            color: isActive ? Colors.purple : Colors.black87,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${session.messageCount} messages',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        selected: isActive,
                        selectedTileColor: Colors.purple[50],
                        onTap: () {
                          Navigator.pop(context);
                          if (session.id != _currentSessionId) {
                            _loadSession(session.id);
                          }
                        },
                        trailing: isActive
                            ? Icon(Icons.check, color: Colors.purple, size: 20)
                            : IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
                                onPressed: () => _deleteSessionFromDrawer(session.id),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Delete session from drawer
  Future<void> _deleteSessionFromDrawer(String sessionId) async {
    if (_userId == null) return;

    try {
      // Delete all messages in the session
      final messagesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chat_sessions')
          .doc(sessionId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      // Delete the session document
      batch.delete(_firestore
          .collection('users')
          .doc(_userId)
          .collection('chat_sessions')
          .doc(sessionId));
      await batch.commit();

      // Remove from local list and create new session if active was deleted
      if (mounted) {
        setState(() {
          _chatSessions.removeWhere((s) => s.id == sessionId);
          if (_currentSessionId == sessionId) {
            _createNewSession();
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete chat')),
        );
      }
    }
  }
  


  Future<bool> _initSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          if (mounted) {
            setState(() {
              _botState = BotState.idle;
            });
            // Don't show error here, it will be handled in _startListening
          }
        },
        onStatus: (status) {
          if (mounted && status == 'done') {
            setState(() {
              if (_botState == BotState.listening) {
                _botState = BotState.idle;
              }
            });
          }
        },
      );
      
      if (available) {
        final locales = await _speechToText.locales();
        if (locales.isNotEmpty) {
          var enLocale = locales.firstWhere((l) => l.localeId.startsWith('en_'), orElse: () => locales.first);
          _currentLocale = enLocale.localeId;
        }
      }
      
      if (mounted) {
        setState(() {});
      }
      
      return available;
    } catch (e) {
      // Don't show error here, return false and let _startListening handle it
      if (mounted) {
        setState(() {});
      }
      return false;
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _botState = BotState.idle;
      });
    });
  }

  Future<void> _fetchUsername() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('username')) {
          if (mounted) {
            setState(() {
              _username = doc.data()!['username'];
            });
          }
        }
      } catch (e) {
        // Continue even if error
      }
    }
    // Welcome message will be shown by _createNewSession or _loadSession
  }

  void _toggleListening() {
    if (_botState != BotState.listening) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  void _startListening() async {
    if (!mounted) return;
    
    // Request microphone permission first
    PermissionStatus micPermission = await Permission.microphone.status;
    if (!micPermission.isGranted) {
      micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required for voice input. Please grant it in settings.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }
    
    // Check if speech recognition is available, if not try to initialize
    if (!_speechToText.isAvailable) {
      bool initialized = await _initSpeech();
      if (!initialized || !_speechToText.isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition is not available on this device. Please install Google app or use text input instead.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }
    
    try {
      setState(() {
        _botState = BotState.listening;
      });
      
      bool started = await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        localeId: _currentLocale,
        partialResults: false,
        cancelOnError: false,
      );
      
      if (!started && mounted) {
        setState(() {
          _botState = BotState.idle;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start voice recognition. Please try again or use text input.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _botState = BotState.idle;
        });
        String errorMsg = 'Voice recognition error. Please use text input instead.';
        if (e.toString().contains('recognizerNotAvailable') || e.toString().contains('not available')) {
          errorMsg = 'Speech recognition is not available on this device. Please install Google app or use text input.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    if (mounted) {
      setState(() {
        _botState = BotState.idle;
      });
    }
  }

  void _onSpeechResult(result) async {
    if (!mounted || !result.finalResult) return;

    final recognizedText = result.recognizedWords.toLowerCase();
    setState(() {
      _botState = BotState.processing;
    });

    _addUserMessage(result.recognizedWords);
    await _executeCommand(recognizedText);
  }


  void _handleTextCommand() {
    final command = _textController.text.trim();
    if (command.isEmpty) return;

    _addUserMessage(command);
    _textController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _botState = BotState.processing;
    });

    _executeCommand(command.toLowerCase());
  }

  Future<void> _executeCommand(String command) async {

    // Case 2: Known, hard-coded commands for navigation and actions.
    final isEmergency = (command.contains('sos') || command.contains('help') || command.contains('save me') || command.contains('emergency'))  ;
    final isStopSos = (command.contains('stop') || command.contains('cancel')) && command.contains('sos');
    final isKnownCommand = command.contains('profile') ||
        command.contains('contacts') ||
        command.contains('history') ||
        isEmergency ||
        isStopSos ||
        command.contains('logout') || command.contains('log out');

    if (isKnownCommand) {
      if (isEmergency) {
        _addBotMessage('Activating SOS immediately...');
        await _triggerAutomaticSOS();
        return; // SOS function handles its own state.
      } else if (isStopSos) {
        _addBotMessage('Stopping SOS alert...');
        await _handleStopSOS();
        return; // Stop SOS function handles its own state.
      } else if (command.contains('profile')) {
        final response = 'Opening your profile.';
        _addBotMessage(response);
        await _speak(response, showInChat: false);
        if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (c) => const ProfileScreen()));
      } else if (command.contains('contacts')) {
        final response = 'Showing your emergency contacts.';
        _addBotMessage(response);
        await _speak(response, showInChat: false);
        if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (c) => const ContactsScreen()));
      } else if (command.contains('history')) {
        final response = 'Opening your S.O.S. history.';
        _addBotMessage(response);
        await _speak(response, showInChat: false);
        if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (c) => const SosScreen(isActivation: false)));
      } else if (command.contains('logout') || command.contains('log out')) {
        final response = 'Logging you out. Goodbye!';
        _addBotMessage(response);
        await _speak(response, showInChat: false);
        await _auth.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
          return;
        }
      }

      if (mounted) {
        setState(() {
          _botState = BotState.idle;
        });
      }
    } else {
      // Not a known command, use rule-based interactive responses
      await _handleGenericQuery(command);
    }
  }


  Future<void> _triggerAutomaticSOS() async {
    final message = 'Activating SOS immediately. Searching for contacts.';
    _addBotMessage(message);
    await _speak(message, showInChat: false);

    final user = _auth.currentUser;
    if (user == null) {
      await _speak('I cannot find your user profile. Please log in again.');
      if (mounted) { setState(() { _botState = BotState.idle; }); }
      return;
    }

    // Check location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _speak('Location services are disabled. Please enable them in settings.');
      if (mounted) { setState(() { _botState = BotState.idle; }); }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _speak('I need location permission to send an SOS. Please grant it in your phone settings.');
        if (mounted) { setState(() { _botState = BotState.idle; }); }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _speak('Location permissions are permanently denied. Please enable them in settings.');
      if (mounted) { setState(() { _botState = BotState.idle; }); }
      return;
    }

    try {
      // Step 1: Fetch contacts from trusted_contacts subcollection
        final contactsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
          .collection('trusted_contacts')
            .get();

        if (contactsSnapshot.docs.isEmpty) {
            await _speak('You have no emergency contacts saved. I cannot send an alert. Redirecting you to add contacts now.');
            if (mounted) {
                Navigator.of(context).push(MaterialPageRoute(builder: (c) => const ContactsScreen()));
            }
            if (mounted) { setState(() { _botState = BotState.idle; }); }
            return;
        }

        final List<String> phoneNumbers = contactsSnapshot.docs
          .map((doc) {
            final data = doc.data();
            final phone = data['phone']?.toString() ?? '';
            // Remove spaces and other non-digit characters except +
            final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
            return cleanPhone;
          })
          .where((phone) => phone.isNotEmpty && phone.length >= 10)
            .toList();

      if (phoneNumbers.isEmpty) {
        await _speak('No valid phone numbers found in your emergency contacts. Please add valid contacts.');
        if (mounted) { setState(() { _botState = BotState.idle; }); }
        return;
      }

      // Step 2: Get location
        await _speak('Contacts found. Getting your location.');
      final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final locationLink =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      // Step 3: Create SOS event in Firestore
      String? sosId;
      Timestamp? triggeredTimestamp;
      try {
        triggeredTimestamp = Timestamp.now();
        final sosEventRef = await _firestore.collection('sos_events').add({
          'userId': user.uid,
          'triggeredAt': triggeredTimestamp,
          'timestamp': FieldValue.serverTimestamp(), // For backward compatibility
          'location': GeoPoint(position.latitude, position.longitude),
          'locationLink': locationLink,
          'status': 'active',
          'stoppedAt': null,
        });
        sosId = sosEventRef.id;
        print('✅ SOS event created with ID: $sosId');
      } catch (firestoreError) {
        print('⚠️ Firestore error: $firestoreError');
        // Continue anyway to send SMS
      }

      // Step 4: Get username from Firestore
      String username = 'Your Friend';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          username = userData?['username']?.toString() ?? user.displayName ?? 'Your Friend';
        }
      } catch (e) {
        print('Error fetching username: $e');
        username = user.displayName ?? 'Your Friend';
      }

      // Step 5: Open SMS app with new message format
      final String messageBody =
          'EMERGENCY! Your Friend $username is in an emergency. Their last known location is: $locationLink';

      final String phoneList = phoneNumbers.join(',');
        final Uri smsUri = Uri(
          scheme: 'sms',
        path: phoneList,
        queryParameters: {'body': messageBody},
      );

      try {
        final canLaunch = await canLaunchUrl(smsUri);
        if (canLaunch) {
          // Navigate FIRST to ActiveSosScreen, then open SMS
          if (sosId != null && mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => ActiveSosScreen(sosId: sosId!),
                settings: const RouteSettings(name: '/active_sos'),
              ),
              (route) => false,
            );
          }
          
          // Now open SMS
          await launchUrl(smsUri, mode: LaunchMode.externalApplication);
          await _speak('SOS activated. Your messaging app is opening. Please press send to confirm the alert.');
        } else {
           await _speak('I could not open your messaging app to send the SOS.');
        }
      } catch (smsError) {
        print('Error opening SMS: $smsError');
        await _speak('I encountered an error opening your messaging app. Please try manually.');
        }

    } catch (e) {
      print('Error during automatic SOS: $e');
      await _speak('I encountered an error while activating SOS. Please try again or do it manually.');
    } finally {
        // Reset state
        if (mounted) {
          setState(() {
            _botState = BotState.idle;
          });
        }
    }
  }

  Future<void> _handleStopSOS() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _speak('I cannot find your user profile. Please log in again.');
      if (mounted) { setState(() { _botState = BotState.idle; }); }
      return;
    }

    try {
      // Check if there's an active SOS event
      final activeSosQuery = await _firestore
          .collection('sos_events')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (activeSosQuery.docs.isEmpty) {
        await _speak('There is no active SOS alert to stop.');
        if (mounted) { setState(() { _botState = BotState.idle; }); }
        return;
      }

      final sosDoc = activeSosQuery.docs.first;
      final sosId = sosDoc.id;

      await _speak('Stopping SOS alert and sending safe message.');
      
      // Navigate to ActiveSosScreen which has the stop functionality
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ActiveSosScreen(sosId: sosId),
            settings: const RouteSettings(name: '/active_sos'),
          ),
          (route) => false,
        );
      }

      // The ActiveSosScreen will handle the actual stop functionality
      // We'll just tell the user to click the button
      await _speak('Please click the Stop SOS button on the screen to complete the process.');
      
    } catch (e) {
      print('Error handling stop SOS: $e');
      await _speak('I encountered an error while stopping SOS. Please try manually.');
    } finally {
      if (mounted) {
        setState(() {
          _botState = BotState.idle;
        });
      }
    }
  }

  /// Rule-based interactive response system - handles general queries with predefined patterns
  Future<void> _handleGenericQuery(String query) async {
    // Add to conversation history
    _conversationHistory.add(query);
    if (_conversationHistory.length > 10) {
      _conversationHistory.removeAt(0);
    }

    // Show thinking indicator
    final thinkingMessage = ChatMessage(
      text: 'Chitti is thinking...',
      type: MessageType.bot,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(thinkingMessage);
    });
    
    // Simulate thinking delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));

    // Get response based on query patterns
    String response = _getInteractiveResponse(query);
    
    // Remove thinking message and add actual response
    setState(() {
      _messages.removeLast(); // Remove thinking message
      _addBotMessage(response);
    });
    
    // Add response to history
    _conversationHistory.add(response);
    if (_conversationHistory.length > 10) {
      _conversationHistory.removeAt(0);
    }

    await _speak(response, showInChat: false);
  }

  /// Rule-based response system with patterns and variations
  String _getInteractiveResponse(String query) {
    final lowerQuery = query.toLowerCase().trim();

    // Greetings and casual conversation
    if (_matchesPattern(lowerQuery, ['hello', 'hi', 'hey', 'good morning', 'good afternoon', 'good evening'])) {
      final greetings = [
        'Hello $_username! How can I help you today?',
        'Hi there! What can I do for you?',
        'Hey $_username! Ready to assist you.',
        'Hello! I\'m here to help you stay safe.',
        'Hi! I\'m Chitti, your safety assistant. How can I help?',
      ];
      return _getRandomResponse(greetings);
    }

    if (_matchesPattern(lowerQuery, ['how are you', 'how do you do', 'what\'s up', 'whats up'])) {
      final responses = [
        'I\'m doing great! Always ready to help you stay safe. What can I do for you?',
        'I\'m fine, thank you! My main job is to keep you safe. Need any help?',
        'All good here! I\'m always ready when you need me. How can I assist?',
        'I\'m excellent! Here to help you with safety and emergencies. What do you need?',
      ];
      return _getRandomResponse(responses);
    }

    if (_matchesPattern(lowerQuery, ['thank', 'thanks', 'thank you'])) {
      final responses = [
        'You\'re welcome! Always happy to help.',
        'My pleasure, $_username! Anything else you need?',
        'Happy to help! Stay safe out there.',
        'Anytime! Remember, I\'m here whenever you need me.',
      ];
      return _getRandomResponse(responses);
    }

    if (_matchesPattern(lowerQuery, ['goodbye', 'bye', 'see you', 'see ya'])) {
      final responses = [
        'Goodbye $_username! Stay safe!',
        'See you later! Take care.',
        'Bye! Remember, I\'m just a voice command away if you need me.',
        'Farewell! Stay safe out there.',
      ];
      return _getRandomResponse(responses);
    }

    // App features and functionality questions
    if (_matchesPattern(lowerQuery, ['what can you do', 'what do you do', 'help', 'features', 'capabilities'])) {
      return 'I can help you with many things! I can activate SOS alerts, manage your emergency contacts, show your SOS history, open your profile, and answer safety questions. Just ask me anything, or say SOS, contacts, history, or profile to get started!';
    }

    if (_matchesPattern(lowerQuery, ['how does sos work', 'explain sos', 'what is sos', 'tell me about sos'])) {
      return 'The SOS feature is simple and powerful! When you say "SOS" or "emergency", I immediately get your location, send an SMS to all your trusted contacts with your location link, and open the Active SOS screen. You can stop the alert anytime by saying "stop SOS". It\'s designed to be fast and reliable in emergencies!';
    }

    if (_matchesPattern(lowerQuery, ['how to add contacts', 'add contact', 'manage contacts', 'contacts help'])) {
      return 'To add emergency contacts, say "contacts" and I\'ll open your contacts screen. There, you can add trusted people who will receive your SOS alerts. Make sure to add people you trust and who can help in emergencies!';
    }

    if (_matchesPattern(lowerQuery, ['sos history', 'view history', 'past alerts', 'alert history'])) {
      return 'Your SOS history shows all your past alerts with details like when they were triggered, when they ended, and location links. Just say "history" and I\'ll show you the complete history screen!';
    }

    // Safety-related questions
    if (_matchesPattern(lowerQuery, ['how to stay safe', 'safety tips', 'safety advice', 'stay safe'])) {
      final safetyTips = [
        'Here are some key safety tips: Always share your location with trusted contacts, avoid walking alone at night, stay aware of your surroundings, keep your phone charged, and don\'t hesitate to use the SOS feature if you feel unsafe.',
        'Stay safe by: Trusting your instincts, staying in well-lit areas, keeping emergency contacts updated, testing the SOS feature regularly, and letting someone know your plans when going out.',
        'Important safety practices: Keep your location services enabled, maintain your emergency contacts list, stay alert to your environment, plan your routes ahead, and remember - when in doubt, activate SOS!',
      ];
      return _getRandomResponse(safetyTips);
    }

    if (_matchesPattern(lowerQuery, ['night', 'dark', 'walking alone', 'walking at night'])) {
      return 'Walking at night requires extra caution. Stay in well-lit areas, avoid shortcuts through isolated places, keep your phone ready with SOS accessible, let someone know your route, and trust your instincts. If you feel unsafe, don\'t hesitate to activate SOS immediately!';
    }

    if (_matchesPattern(lowerQuery, ['emergency', 'danger', 'unsafe', 'scared', 'afraid'])) {
      return 'If you\'re in danger right now, say "SOS" immediately! I\'ll activate the emergency alert and notify your trusted contacts with your location. Don\'t wait - your safety is the top priority!';
    }

    if (_matchesPattern(lowerQuery, ['parking', 'parking lot', 'parking area'])) {
      return 'Parking lots can be risky, especially at night. Park close to exits and in well-lit areas, have your keys ready before reaching your car, check your vehicle before entering, stay alert, and keep SOS ready. Safety first!';
    }

    // Location and privacy questions
    if (_matchesPattern(lowerQuery, ['location', 'tracking', 'privacy', 'location sharing'])) {
      return 'Your location is only shared with your trusted contacts when you activate SOS. It\'s sent via SMS with a Google Maps link. You control who receives it by managing your emergency contacts list. Your privacy is important!';
    }

    // Who/what/where questions
    if (_matchesPattern(lowerQuery, ['who are you', 'what are you', 'tell me about yourself'])) {
      return 'I\'m Chitti, your intelligent safety assistant for the Campus Guard app! I help you stay safe by managing SOS alerts, emergency contacts, and providing safety guidance. I\'m always here when you need me, $_username!';
    }

    if (_matchesPattern(lowerQuery, ['your name', 'who is chitti', 'what is your name'])) {
      return 'My name is Chitti! I\'m your safety assistant in the Campus Guard app. I\'m here to help you stay safe and manage emergency situations. Nice to meet you, $_username!';
    }

    // General questions
    if (_matchesPattern(lowerQuery, ['what time', 'what\'s the time', 'time'])) {
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      return 'The current time is $timeStr. Is there anything safety-related I can help you with?';
    }

    if (_matchesPattern(lowerQuery, ['what can you help', 'what should i do', 'help me'])) {
      return 'I can help you with SOS alerts, managing contacts, viewing history, safety advice, and general questions about the app. What would you like to know? Just ask me anything!';
    }

    // Confirmation and clarification
    if (_matchesPattern(lowerQuery, ['yes', 'yeah', 'yep', 'okay', 'ok', 'sure'])) {
      final responses = [
        'Great! What would you like me to do?',
        'Perfect! How can I help?',
        'Awesome! What\'s next?',
        'Sounds good! What do you need?',
      ];
      return _getRandomResponse(responses);
    }

    if (_matchesPattern(lowerQuery, ['no', 'nope', 'nah'])) {
      final responses = [
        'No problem! Is there anything else I can help with?',
        'That\'s okay! Let me know if you need anything.',
        'Alright! I\'m here if you change your mind.',
      ];
      return _getRandomResponse(responses);
    }

    // App navigation help
    if (_matchesPattern(lowerQuery, ['where', 'show me', 'open', 'go to'])) {
      if (lowerQuery.contains('profile')) {
        return 'I can open your profile. Just say "profile" and I\'ll take you there!';
      } else if (lowerQuery.contains('contact')) {
        return 'Say "contacts" and I\'ll show you your emergency contacts screen!';
      } else if (lowerQuery.contains('history')) {
        return 'Just say "history" and I\'ll open your SOS alert history!';
      }
    }

    // Compliments and feedback
    if (_matchesPattern(lowerQuery, ['good job', 'well done', 'you\'re great', 'you\'re awesome', 'love you'])) {
      final responses = [
        'Thank you, $_username! That means a lot to me!',
        'You\'re too kind! I\'m just here to help you stay safe.',
        'Aw, thanks! Your safety is my priority.',
        'That\'s so sweet! I\'m always here for you.',
      ];
      return _getRandomResponse(responses);
    }

    // Questions about the app
    if (_matchesPattern(lowerQuery, ['app', 'application', 'campus guard'])) {
      return 'Campus Guard is your safety companion app! It helps you stay safe with SOS alerts, emergency contacts, location sharing, and safety features. I\'m here to help you use all these features effectively!';
    }

    // ========== CAMPUS INFORMATION RULES ==========
    
    // Security at main gate
    if (_matchesPattern(lowerQuery, ['security', 'main gate', 'gate', 'security guard', 'security officer'])) {
      return 'Security is available at the main gate. You can contact them for any security-related concerns or assistance.';
    }

    // Main office at PIE block
    if (_matchesPattern(lowerQuery, ['main office', 'office', 'pie block', 'pie'])) {
      if (lowerQuery.contains('director') || lowerQuery.contains('director sir')) {
        if (_isWorkingDay()) {
          return 'The Director sir is available in PIE block, 3rd floor on working days. The main office is also located in PIE block.';
        } else {
          return 'The Director sir is available in PIE block, 3rd floor on working days. Today is a holiday, so the director may not be available. The main office is also located in PIE block.';
        }
      }
      return 'The main office is located in PIE block. You can visit there for administrative matters.';
    }

    // Medical services at H-Block
    if (_matchesPattern(lowerQuery, ['medical', 'hospital', 'clinic', 'doctor', 'health', 'h-block', 'h block'])) {
      return 'Medical services are available at H-Block. You can visit there for any health-related concerns or medical assistance.';
    }

    // Warden information
    if (_matchesPattern(lowerQuery, ['warden', 'hostel warden'])) {
      if (lowerQuery.contains('boys') || lowerQuery.contains('b-block') || lowerQuery.contains('b block')) {
        return 'The warden for Boys hostel is available at the Ground floor of B-Block. There is also a warden and security officer available in both Boys hostel (B-Block) and Girls hostel (G-Block).';
      } else if (lowerQuery.contains('girls') || lowerQuery.contains('g-block') || lowerQuery.contains('g block')) {
        return 'The warden for Girls hostel is available at G-Block. There is also a warden and security officer available in both Boys hostel (B-Block) and Girls hostel (G-Block).';
      }
      return 'Wardens are available in both Boys hostel (B-Block) and Girls hostel (G-Block). The Boys hostel warden is at the Ground floor of B-Block. There are also security officers available in both hostels.';
    }

    // AI Course Professor - Dr. Animesh Chaturvedi
    if (_matchesPattern(lowerQuery, ['ai professor', 'artificial intelligence professor', 'animesh', 'chaturvedi', 'ai course', 'ai teacher'])) {
      if (_isWorkingDay()) {
        return 'Dr. Animesh Chaturvedi is the Artificial Intelligence (AI) Course Professor. Professors are available in E-Block on working days. They are not available on Saturdays, Sundays, and public holidays.';
      } else {
        return 'Dr. Animesh Chaturvedi is the Artificial Intelligence (AI) Course Professor. However, today is a holiday (Saturday/Sunday), so professors are not available. They are available in E-Block on working days only.';
      }
    }

    // Bus schedule queries - check more patterns
    if (_matchesPattern(lowerQuery, ['bus', 'buses', 'bus timing', 'bus schedule', 'transport', 'transit', 'sattur', 'bus from', 'bus to', 'when is', 'what time', 'next bus', 'any bus'])) {
      return _getBusScheduleInfo(lowerQuery);
    }

    // Certificates and documents
    if (_matchesPattern(lowerQuery, ['certificate', 'certificates', 'document', 'documents', 'id card', 'id', 'transcript', 'marksheet'])) {
      return 'For certificates and other documents, please go to PIE block, second floor with your ID card. Make sure to carry your ID card for verification.';
    }

    // Professors and faculty
    if (_matchesPattern(lowerQuery, ['professor', 'professors', 'faculty', 'teacher', 'teachers', 'meet professor', 'see professor'])) {
      if (_isWorkingDay()) {
        return 'Professors are available in E-Block on working days. They are not available on Saturdays, Sundays, and public holidays. Please visit E-Block during working hours to meet your professors.';
      } else {
        return 'Today is a holiday (Saturday/Sunday), so professors are not available. They are available in E-Block on working days only. Please visit on a working day.';
      }
    }

    // College holidays
    if (_matchesPattern(lowerQuery, ['holiday', 'holidays', 'weekend', 'saturday', 'sunday', 'working day', 'working days'])) {
      return 'Our college has holidays on Saturday and Sunday. All administrative offices, professors, and most services are not available on these days. Working days are Monday through Friday.';
    }

    // Director
    if (_matchesPattern(lowerQuery, ['director', 'director sir'])) {
      if (_isWorkingDay()) {
        return 'The Director sir is available in PIE block, 3rd floor on working days. You can visit there during working hours.';
      } else {
        return 'The Director sir is available in PIE block, 3rd floor on working days. Today is a holiday, so the director may not be available. Please visit on a working day.';
      }
    }

    // KRC (Knowledge Resource Center)
    if (_matchesPattern(lowerQuery, ['krc', 'knowledge resource center', 'knowledge resource', 'study room', 'study area'])) {
      return 'KRC (Knowledge Resource Center) is located in PIE block, 1st floor. It\'s like a library for studying, but books are not available there. It\'s a great place for quiet study sessions.';
    }

    // Library
    if (_matchesPattern(lowerQuery, ['library', 'books', 'borrow book', 'library books'])) {
      return 'The library is located in E-Block, Upper Ground floor near the entrance. Books are available there for borrowing. You can visit the library to access books and study materials.';
    }

    // Indoor sports
    if (_matchesPattern(lowerQuery, ['sports', 'indoor sports', 'badminton', 'table tennis', 'basketball', 'volleyball', 'basket ball', 'volley ball', 'play', 'game'])) {
      return 'Indoor sports facilities are available in M-Block. You can play badminton, table tennis, basketball, and volleyball there. Visit M-Block for indoor sports activities.';
    }

    // Hostel security
    if (_matchesPattern(lowerQuery, ['hostel security', 'hostel security officer'])) {
      return 'Security officers are available in both Boys hostel (B-Block) and Girls hostel (G-Block). You can contact them for any security concerns in the hostel.';
    }

    // Block locations
    if (_matchesPattern(lowerQuery, ['e-block', 'e block', 'where is e'])) {
      return 'E-Block houses the professors\' offices, and the library is located in E-Block, Upper Ground floor near the entrance.';
    }

    if (_matchesPattern(lowerQuery, ['m-block', 'm block', 'where is m'])) {
      return 'M-Block has indoor sports facilities including badminton, table tennis, basketball, and volleyball courts.';
    }

    if (_matchesPattern(lowerQuery, ['h-block', 'h block', 'where is h'])) {
      return 'H-Block houses the medical services. You can visit there for any health-related concerns or medical assistance.';
    }

    if (_matchesPattern(lowerQuery, ['b-block', 'b block', 'where is b', 'boys hostel'])) {
      return 'B-Block is the Boys hostel. The warden is available at the Ground floor of B-Block. There is also a security officer available in the Boys hostel.';
    }

    if (_matchesPattern(lowerQuery, ['g-block', 'g block', 'where is g', 'girls hostel'])) {
      return 'G-Block is the Girls hostel. The warden and security officer are available in the Girls hostel.';
    }

    // Default responses with variations
    if (query.length < 3) {
      return 'Could you say that again? I want to make sure I understand you correctly.';
    }

    // Check conversation context for follow-up questions
    if (_conversationHistory.length >= 2) {
      final lastBotResponse = _conversationHistory[_conversationHistory.length - 2].toLowerCase();
      
      // Follow-up questions
      if (_matchesPattern(lowerQuery, ['what else', 'anything else', 'more', 'and', 'also'])) {
        if (lastBotResponse.contains('sos')) {
          return 'You can also manage your emergency contacts, view your SOS history, or update your profile. What would you like to do?';
        } else if (lastBotResponse.contains('contact')) {
          return 'You can view your SOS history, check your profile, or activate SOS if needed. What else can I help with?';
        }
      }
    }

    // Generic helpful responses
    final genericResponses = [
      'That\'s interesting! Can you tell me more about what you need?',
      'I understand. How can I help you with that?',
      'I\'m here to help! Could you rephrase that or be more specific?',
      'Let me help you with that. Could you give me more details?',
      'I want to make sure I help you correctly. Can you ask in a different way?',
      'That\'s a good question! For app features, you can say SOS, contacts, history, or profile. For safety advice, just ask!',
      'I can help you with SOS alerts, contacts, history, profile, and safety tips. What would you like to know?',
      'I\'m still learning, but I can help with app features and safety. Try saying SOS, contacts, or ask me a safety question!',
    ];
    return _getRandomResponse(genericResponses);
  }

  /// Helper: Check if query matches any patterns
  bool _matchesPattern(String query, List<String> patterns) {
    return patterns.any((pattern) => query.contains(pattern));
  }

  /// Helper: Get random response from list for variation
  String _getRandomResponse(List<String> responses) {
    final random = DateTime.now().millisecondsSinceEpoch % responses.length;
    return responses[random];
  }

  /// Helper: Get bus schedule information based on current time and route
  String _getBusScheduleInfo(String query) {
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;
    final currentTimeInMinutes = currentHour * 60 + currentMinute;
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    
    // Debug: Add current time info for troubleshooting
    // print('Current time: $currentHour:$currentMinute (${currentTimeInMinutes} minutes)');
    
    // Bus schedule data (from the image)
    // Format: [hour, minute, from, to, bus]
    final busSchedule = [
      [7, 30, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [7, 30, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [8, 0, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [8, 0, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [8, 25, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [8, 25, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [8, 45, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [8, 45, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [10, 0, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [10, 0, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [10, 40, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [10, 40, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [11, 20, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [11, 20, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [12, 0, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [12, 0, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [14, 0, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [14, 0, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [14, 40, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [14, 40, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [15, 20, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [15, 20, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [16, 0, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [16, 0, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      [17, 30, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [17, 30, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [17, 45, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [17, 45, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [18, 20, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [18, 20, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [19, 0, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [19, 0, 'Campus', 'Transit hostel', 'Institute Bus 2'],
      [19, 0, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [19, 40, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [19, 40, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [20, 20, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [20, 20, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [21, 0, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [21, 0, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [22, 0, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [22, 0, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [22, 30, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [22, 30, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [23, 15, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [23, 15, 'Transit hostel', 'Campus', 'Institute Bus 1'],
      [23, 40, 'Campus', 'Transit hostel', 'Institute Bus 1'],
      [23, 40, 'Transit hostel', 'Campus', 'Institute Bus 1'],
    ];

    // Special Sunday/holiday schedule
    if (isWeekend) {
      final sundaySchedule = [
        [10, 0, 'Campus', 'Transit hostel', 'Institute Bus 2'],
        [10, 0, 'Transit hostel', 'Campus', 'Institute Bus 2'],
      ];
      // Find next bus
      for (var bus in sundaySchedule) {
        final busTime = (bus[0] as int) * 60 + (bus[1] as int);
        if (busTime >= currentTimeInMinutes) {
          final timeStr = '${(bus[0] as int).toString().padLeft(2, '0')}:${(bus[1] as int).toString().padLeft(2, '0')}';
          return 'On Sundays and holidays, buses depart from campus at 10:00 AM. The next bus is at $timeStr ${bus[2]} to ${bus[3]} (${bus[4]}).';
        }
      }
      return 'On Sundays and holidays, buses depart from campus at 10:00 AM. The next bus will be tomorrow at 10:00 AM.';
    }

    // Determine route direction from query - more flexible matching
    bool isCampusToHostel = query.contains('campus to') || query.contains('campus to transit') || 
                            query.contains('campus to hostel') || query.contains('from campus') ||
                            query.contains('to hostel') || query.contains('to transit');
    bool isHostelToCampus = query.contains('hostel to') || query.contains('transit to') || 
                           query.contains('transit hostel to') || query.contains('from hostel') || 
                           query.contains('from transit') || query.contains('to campus');
    bool isSattur = query.contains('sattur');

    // Filter buses based on direction
    List<List<dynamic>> relevantBuses = [];
    if (isCampusToHostel && !isHostelToCampus) {
      relevantBuses = busSchedule.where((bus) => bus[2] == 'Campus').toList();
    } else if (isHostelToCampus && !isCampusToHostel) {
      relevantBuses = busSchedule.where((bus) => bus[2] == 'Transit hostel').toList();
    } else {
      // Both directions - show both if not specified
      relevantBuses = busSchedule;
    }

    // Sort buses by time
    relevantBuses.sort((a, b) {
      final timeA = (a[0] as int) * 60 + (a[1] as int);
      final timeB = (b[0] as int) * 60 + (b[1] as int);
      return timeA.compareTo(timeB);
    });

    // Find next buses (up to 3 per direction if showing both, or 3 total if one direction)
    List<String> nextBuses = [];
    Map<String, int> directionCount = {}; // Track buses per direction
    
    for (var bus in relevantBuses) {
      final busTime = (bus[0] as int) * 60 + (bus[1] as int);
      if (busTime >= currentTimeInMinutes) {
        final timeStr = '${(bus[0] as int).toString().padLeft(2, '0')}:${(bus[1] as int).toString().padLeft(2, '0')}';
        final direction = '${bus[2]} to ${bus[3]}';
        final busKey = direction;
        
        // If showing both directions, limit to 2 per direction
        // If showing one direction, limit to 3 total
        int maxPerDirection = relevantBuses.length == busSchedule.length ? 2 : 3;
        int currentCount = directionCount[busKey] ?? 0;
        
        if (currentCount < maxPerDirection) {
          final busInfo = '$timeStr - $direction (${bus[4]})';
          if (isSattur) {
            // Add note about Sattur stop
            nextBuses.add('$busInfo - Note: Bus stops at Sattur (Opp Chirayu) approximately 15 minutes after departure');
          } else {
            nextBuses.add(busInfo);
          }
          directionCount[busKey] = currentCount + 1;
          
          // Stop if we have enough buses
          if (relevantBuses.length == busSchedule.length) {
            // Both directions: need 2 from each = 4 total
            if (nextBuses.length >= 4) break;
          } else {
            // One direction: need 3 total
            if (nextBuses.length >= 3) break;
          }
        }
      }
    }

    // If no buses found for today, find first buses tomorrow
    if (nextBuses.isEmpty && relevantBuses.isNotEmpty) {
      // Sort to get earliest buses
      final sortedBuses = List<List<dynamic>>.from(relevantBuses);
      sortedBuses.sort((a, b) {
        final timeA = (a[0] as int) * 60 + (a[1] as int);
        final timeB = (b[0] as int) * 60 + (b[1] as int);
        return timeA.compareTo(timeB);
      });
      
      String response = 'No more buses today. ';
      
      // Show first bus from each direction if showing both
      if (relevantBuses.length == busSchedule.length) {
        final campusBus = sortedBuses.firstWhere((b) => b[2] == 'Campus', orElse: () => sortedBuses.first);
        final hostelBus = sortedBuses.firstWhere((b) => b[2] == 'Transit hostel', orElse: () => sortedBuses.first);
        
        final campusTime = '${(campusBus[0] as int).toString().padLeft(2, '0')}:${(campusBus[1] as int).toString().padLeft(2, '0')}';
        final hostelTime = '${(hostelBus[0] as int).toString().padLeft(2, '0')}:${(hostelBus[1] as int).toString().padLeft(2, '0')}';
        
        response += 'The next buses will be tomorrow:\n';
        response += '• $campusTime - ${campusBus[2]} to ${campusBus[3]} (${campusBus[4]})\n';
        response += '• $hostelTime - ${hostelBus[2]} to ${hostelBus[3]} (${hostelBus[4]})';
      } else {
        final firstBus = sortedBuses.first;
        final timeStr = '${(firstBus[0] as int).toString().padLeft(2, '0')}:${(firstBus[1] as int).toString().padLeft(2, '0')}';
        response += 'The next bus will be tomorrow at $timeStr from ${firstBus[2]} to ${firstBus[3]} (${firstBus[4]}).';
      }
      
      return response;
    }

    if (nextBuses.isEmpty) {
      return 'I couldn\'t find any upcoming buses in the schedule. Please check with the transport office or contact the main office in PIE block.';
    }

    // Sort nextBuses by time for better display
    nextBuses.sort((a, b) {
      // Extract time from string (format: "HH:MM - ...")
      final timeA = a.substring(0, 5);
      final timeB = b.substring(0, 5);
      return timeA.compareTo(timeB);
    });

    String response = 'Here are the upcoming bus timings:\n';
    for (int i = 0; i < nextBuses.length; i++) {
      response += '${i + 1}. ${nextBuses[i]}\n';
    }
    
    // Add additional notes
    if (isSattur) {
      response += '\nℹ️ Note: Buses stop at Sattur (Opp Chirayu) approximately 15 minutes after leaving the starting point.';
    } else {
      response += '\nℹ️ Note: Buses also stop at Sattur (Opp Chirayu) approximately 15 minutes after departure.';
    }
    response += '\nℹ️ Note: If there are more than 10 students, the bus may depart without waiting for the scheduled time.';
    
    // Add info about bus operators
    response += '\n\n📌 Bus 1 refers to ShreeTravels, and Bus 2 refers to Sushanth Travels.';
    
    return response;
  }

  /// Helper: Check if it's a working day
  bool _isWorkingDay() {
    final now = DateTime.now();
    return now.weekday != DateTime.saturday && now.weekday != DateTime.sunday;
  }

  Future<void> _speak(String text, {bool showInChat = true}) async {
    if (showInChat && mounted) {
      _addBotMessage(text);
    }
    if (mounted) {
      setState(() {
        _botState = BotState.processing;
      });
    }
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
    _textController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Build animated chatbot avatar (left side)
  Widget _buildChatbotAvatar() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.purple[300]!, Colors.purple[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(
                    Icons.smart_toy,
                    color: Colors.purple[700],
                    size: 20,
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Opacity(
                      opacity: 0.6 + (_scaleAnimation.value - 0.95) * 2,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build user avatar (right side)
  Widget _buildUserAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue[400],
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  // Build chat message bubble
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.type == MessageType.user;
    
    if (message.text == 'Chitti is thinking...') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChatbotAvatar(),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Chitti is thinking...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildChatbotAvatar(),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.purple[400] : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chitti Voice Assistant'),
        backgroundColor: Colors.purple,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildChatHistoryDrawer(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: <Widget>[
            // Chat messages list
            Expanded(
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.purple),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildChatbotAvatar(),
                              const SizedBox(height: 16),
                              Text(
                                'Chat with Chitti',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Type a message or use voice',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
            ),
            
            // Bottom input area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                    // Voice button
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _botState == BotState.listening ? _scaleAnimation.value : 1.0,
                          child: Material(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(25),
                            elevation: _botState == BotState.listening ? 8 : 4,
                            child: InkWell(
                              onTap: _toggleListening,
                              borderRadius: BorderRadius.circular(25),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _botState == BotState.listening 
                                      ? Colors.purple[400] 
                                      : Colors.purple,
                                ),
                                child: Icon(
                                  _botState == BotState.listening ? Icons.mic : Icons.mic_none,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    
                    // Text field
                  Expanded(
                    child: TextField(
                      controller: _textController,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                          hintText: 'Type your message...',
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _handleTextCommand(),
                    ),
                  ),
                  const SizedBox(width: 8),
                    
                    // Send button
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _textController.text.trim().isNotEmpty 
                            ? Colors.purple 
                            : Colors.grey[400],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_textController.text.trim().isNotEmpty 
                                ? Colors.purple 
                                : Colors.grey).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                  ),
                ],
              ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 22),
                        onPressed: _textController.text.trim().isNotEmpty 
                            ? _handleTextCommand 
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
