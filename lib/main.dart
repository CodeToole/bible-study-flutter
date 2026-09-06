import 'package:flutter/material.dart';
import 'models/verse.dart';
import 'services/bible_service.dart';
import 'services/storage_service.dart';
import 'screens/reader_screen.dart';
import 'screens/study_notes_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BibleStudyApp());
}

class BibleStudyApp extends StatelessWidget {
  const BibleStudyApp({super.key});

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkContainer = Color(0xFF2A2A2A);
  static const Color goldAccent = Color(0xFFFFC107);
  static const Color crimsonRed = Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bible Study App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        primaryColor: goldAccent,
        canvasColor: darkBackground,
        cardColor: darkSurface,
        dialogTheme: const DialogThemeData(backgroundColor: darkSurface),
        colorScheme: const ColorScheme.dark(
          primary: goldAccent,
          secondary: goldAccent,
          surface: darkSurface,
          error: crimsonRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181818),
          elevation: 0,
          iconTheme: IconThemeData(color: goldAccent),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF181818),
          selectedItemColor: goldAccent,
          unselectedItemColor: Colors.white54,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
        ),
        useMaterial3: true,
      ),
      home: const AppRootContainer(),
    );
  }
}

class AppRootContainer extends StatefulWidget {
  const AppRootContainer({super.key});

  @override
  State<AppRootContainer> createState() => _AppRootContainerState();
}

class _AppRootContainerState extends State<AppRootContainer> {
  bool _isLoading = true;
  String _loadingMessage = 'Loading King James Version dataset in background isolate...';

  int _currentIndex = 0;
  int _activeBookId = 1; // Default: Genesis
  int _activeChapter = 1;

  // Global key to interact with Reader and StudyNotes screens
  final GlobalKey<ReaderScreenState> _readerKey = GlobalKey<ReaderScreenState>();
  final GlobalKey<StudyNotesScreenState> _notesKey = GlobalKey<StudyNotesScreenState>();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await StorageService.instance.init();
      setState(() => _loadingMessage = 'Decoding canonical scriptures...');
      await BibleService.instance.load();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _loadingMessage = 'Error loading dataset: $e';
      });
    }
  }

  void _navigateToScripture(int bookId, int chapter) {
    setState(() {
      _activeBookId = bookId;
      _activeChapter = chapter;
      _currentIndex = 0; // Switch to Reader tab
    });
    _readerKey.currentState?.jumpTo(bookId, chapter);
  }

  void _handleSendToNotes(List<Verse> verses) {
    setState(() {
      _currentIndex = 1; // Switch to Study Notes tab
    });
    // Insert into notes composer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notesKey.currentState?.publicInsertVerses(verses);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: BibleStudyApp.darkBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFC107), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC107).withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_stories,
                    color: Color(0xFFFFC107),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Bible Study Universal',
                  style: TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _loadingMessage,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 160,
                  child: LinearProgressIndicator(
                    color: Color(0xFFFFC107),
                    backgroundColor: Color(0xFF2A2A2A),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ReaderScreen(
            key: _readerKey,
            initialBookId: _activeBookId,
            initialChapter: _activeChapter,
            onSendToNotes: _handleSendToNotes,
          ),
          StudyNotesScreen(
            key: _notesKey,
            onNavigateToScripture: _navigateToScripture,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFFFFC107).withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'Scripture',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note_rounded),
              label: 'Study Notes',
            ),
          ],
        ),
      ),
    );
  }
}
