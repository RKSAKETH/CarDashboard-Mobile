import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class MusicPlayerView extends StatefulWidget {
  final Color accent;
  final Color bg;
  final Color textPri;
  final Color textSec;

  const MusicPlayerView({
    super.key,
    required this.accent,
    required this.bg,
    required this.textPri,
    required this.textSec,
  });

  @override
  State<MusicPlayerView> createState() => _MusicPlayerViewState();
}

class _MusicPlayerViewState extends State<MusicPlayerView> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 0.5;

  final String _audioUrl =
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });

    await _audioPlayer.setVolume(_volume);
    await _audioPlayer.setSourceUrl(_audioUrl);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(_audioUrl));
    }
  }

  void _seekForward() async {
    final newPosition = _position + const Duration(seconds: 15);
    await _audioPlayer
        .seek(newPosition < _duration ? newPosition : _duration);
  }

  void _seekBackward() async {
    final newPosition = _position - const Duration(seconds: 15);
    await _audioPlayer
        .seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  void _increaseVolume() async {
    if (_volume < 1.0) {
      setState(() => _volume = (_volume + 0.1).clamp(0.0, 1.0));
      await _audioPlayer.setVolume(_volume);
    }
  }

  void _decreaseVolume() async {
    if (_volume > 0.0) {
      setState(() => _volume = (_volume - 0.1).clamp(0.0, 1.0));
      await _audioPlayer.setVolume(_volume);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.bg,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Album art ────────────────────────────────────────────────────
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accent.withAlpha(160),
                      const Color(0xFF1A1A2E),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withAlpha(80),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 80,
                  color: Colors.white.withAlpha(80),
                ),
              ),
              const SizedBox(height: 30),

              // ── Track info ───────────────────────────────────────────────────
              Text(
                _isPlaying ? 'Playing Sample Track' : 'Music Paused',
                style: TextStyle(
                  color: widget.textPri,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'SoundHelix Song 1',
                style: TextStyle(color: widget.textSec, fontSize: 13),
              ),

              const SizedBox(height: 36),

              // ── Playback controls ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.volume_down_rounded, color: widget.textSec),
                    iconSize: 28,
                    onPressed: _decreaseVolume,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.replay_10_rounded, color: widget.textSec),
                    iconSize: 36,
                    onPressed: _seekBackward,
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.accent,
                            widget.accent.withAlpha(180),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.accent.withAlpha(100),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.forward_10_rounded, color: widget.textSec),
                    iconSize: 36,
                    onPressed: _seekForward,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.volume_up_rounded, color: widget.textSec),
                    iconSize: 28,
                    onPressed: _increaseVolume,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Progress bar ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbColor: widget.accent,
                        activeTrackColor: widget.accent,
                        inactiveTrackColor: widget.textSec.withAlpha(60),
                        overlayColor: widget.accent.withAlpha(30),
                      ),
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        min: 0.0,
                        max: _duration.inSeconds.toDouble() > 0
                            ? _duration.inSeconds.toDouble()
                            : 1.0,
                        onChanged: (value) async {
                          await _audioPlayer
                              .seek(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style:
                              TextStyle(color: widget.textSec, fontSize: 11),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style:
                              TextStyle(color: widget.textSec, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Volume indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.volume_up_outlined,
                          size: 14,
                          color: widget.textSec,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(_volume * 100).toInt()}%',
                          style: TextStyle(
                              color: widget.textSec, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ], // Column.children
          ),   // Column
        ),     // ConstrainedBox
      ),       // SingleChildScrollView
    );         // Container
  }
}
