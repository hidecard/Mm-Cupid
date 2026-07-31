import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/realtime_service.dart';
import 'chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<Match> _matches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMatches();
    });
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await auth.apiService.getMatches();

      if (response['success'] == true) {
        final List<dynamic> data = response['matches'] as List<dynamic>? ?? [];
        setState(() {
          _matches = data
              .map((json) => Match.fromJson(json as Map<String, dynamic>, auth.user!.id))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['error'] as String? ?? 'Failed to load matches';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load matches: $e';
        _isLoading = false;
      });
    }
  }

  void _openChat(Match match) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ChatProvider(
            auth.apiService,
            realtimeService,
            auth.user!.id,
          ),
          child: ChatScreen(
            roomId: match.roomId!,
            matchId: match.matchId,
            recipientName: match.user.name,
            recipientPic: match.user.profilePic,
            currentUserId: auth.user!.id,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadMatches,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE94560),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _matches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No matches yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Swipe more to find matches!',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMatches,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _matches.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final match = _matches[index];
                          return _MatchTile(
                            match: match,
                            onTap: () => _openChat(match),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final Match match;
  final VoidCallback onTap;

  const _MatchTile({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: match.user.profilePic != null
              ? NetworkImage(match.user.profilePic!)
              : null,
          child: match.user.profilePic == null
              ? const Icon(Icons.person, size: 32)
              : null,
        ),
        title: Text(
          match.user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Matched on ${match.matchedAt.day}/${match.matchedAt.month}/${match.matchedAt.year}',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
