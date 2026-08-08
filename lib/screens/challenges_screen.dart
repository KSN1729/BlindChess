import 'dart:async';
import 'package:flutter/material.dart';
import '../services/lichess_service.dart';
import '../models/lichess_online_models.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final LichessService _lichessService = LichessService.instance;
  StreamSubscription<LichessEvent>? _eventSubscription;
  List<LichessChallenge> _incoming = [];
  List<LichessChallenge> _outgoing = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _lichessService.fetchChallenges();
      if (!mounted) return;
      setState(() {
        _incoming = data['in'] ?? [];
        _outgoing = data['out'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = LichessService.formatError(e);
        _isLoading = false;
      });
    }
  }

  void _subscribeToEvents() {
    try {
      _eventSubscription = _lichessService.streamEvents().listen(
        (event) {
          if (event.type == 'challenge' ||
              event.type == 'challengeCanceled' ||
              event.type == 'challengeDeclined' ||
              event.type == 'gameStart') {
            _loadChallenges();
          }
        },
        onError: (e) {
          debugPrint('Error in challenges stream: $e');
        },
      );
    } catch (e) {
      debugPrint('Could not listen to event stream: $e');
    }
  }

  void _accept(String challengeId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accepting challenge...'), duration: Duration(seconds: 1)),
      );
      await _lichessService.acceptChallenge(challengeId);
      _loadChallenges();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LichessService.formatError(e))),
      );
    }
  }

  void _decline(String challengeId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Declining challenge...'), duration: Duration(seconds: 1)),
      );
      await _lichessService.declineChallenge(challengeId);
      _loadChallenges();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LichessService.formatError(e))),
      );
    }
  }

  void _cancel(String challengeId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancelling challenge...'), duration: Duration(seconds: 1)),
      );
      await _lichessService.cancelChallenge(challengeId);
      _loadChallenges();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LichessService.formatError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1B29),
        appBar: AppBar(
          title: const Text('Challenges Inbox'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Incoming'),
              Tab(text: 'Outgoing'),
            ],
            indicatorColor: Colors.deepPurpleAccent,
            labelColor: Colors.deepPurpleAccent,
            unselectedLabelColor: Colors.white60,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.white70, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadChallenges,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                            child: const Text('Retry'),
                          )
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _buildChallengeList(
                        challenges: _incoming,
                        isIncoming: true,
                        emptyMessage: 'No incoming challenges.',
                      ),
                      _buildChallengeList(
                        challenges: _outgoing,
                        isIncoming: false,
                        emptyMessage: 'No pending outgoing challenges.',
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildChallengeList({
    required List<LichessChallenge> challenges,
    required bool isIncoming,
    required String emptyMessage,
  }) {
    if (challenges.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Colors.white38, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: challenges.length,
      itemBuilder: (context, index) {
        final chal = challenges[index];
        final opponentName = isIncoming ? chal.challengerName : (chal.destUserName ?? 'Open Invite Link');
        final opponentRating = isIncoming ? chal.challengerRating : chal.destUserRating;
        final ratingStr = opponentRating != null ? '($opponentRating)' : '';
        final mode = chal.rated ? 'Rated' : 'Casual';
        final limitMin = chal.clockLimit ~/ 60;
        final incSec = chal.clockIncrement;
        final timeStr = '${limitMin}m + ${incSec}s';

        return Card(
          color: const Color(0xFF2C243E),
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.1), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opponentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$mode • $timeStr',
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (ratingStr.isNotEmpty)
                      Text(
                        ratingStr,
                        style: const TextStyle(color: Colors.white30, fontSize: 14),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: isIncoming
                      ? [
                          TextButton.icon(
                            onPressed: () => _decline(chal.id),
                            icon: const Icon(Icons.close, color: Colors.red, size: 18),
                            label: const Text('Decline', style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _accept(chal.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Accept'),
                          ),
                        ]
                      : [
                          TextButton.icon(
                            onPressed: () => _cancel(chal.id),
                            icon: const Icon(Icons.delete_outline, color: Colors.white60, size: 18),
                            label: const Text('Cancel Invite', style: TextStyle(color: Colors.white60)),
                          ),
                        ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
