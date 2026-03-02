import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class MusicPlayerView extends StatefulWidget {
  final Color accent;
  final Color bg;
  final Color textPri;
  final Color textSec;

  final double speed;
  final bool isOverLimit;

  const MusicPlayerView({
    super.key,
    required this.accent,
    required this.bg,
    required this.textPri,
    required this.textSec,
    required this.speed,
    this.isOverLimit = false,
  });

  @override
  State<MusicPlayerView> createState() => _MusicPlayerViewState();
}

class _MusicPlayerViewState extends State<MusicPlayerView> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _rotationController;

  // ── Reactive Notifiers ─────────────────────────────────────────────────────
  final ValueNotifier<bool>     _isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> _durationNotifier  = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> _positionNotifier  = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<double>   _volumeNotifier    = ValueNotifier<double>(0.5);

  final String _audioUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    _setupAudioPlayer();
  }

  Future<void> _setupAudioPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      _isPlayingNotifier.value = playing;
      if (playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });

    _audioPlayer.onDurationChanged.listen((d) => _durationNotifier.value = d);
    _audioPlayer.onPositionChanged.listen((p) => _positionNotifier.value = p);

    await _audioPlayer.setVolume(_volumeNotifier.value);
    await _audioPlayer.setSourceUrl(_audioUrl);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _audioPlayer.dispose();
    _isPlayingNotifier.dispose();
    _durationNotifier.dispose();
    _positionNotifier.dispose();
    _volumeNotifier.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _togglePlayPause() async {
    if (_isPlayingNotifier.value) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(_audioUrl));
    }
  }

  void _seekForward() async {
    final curPos = _positionNotifier.value;
    final total = _durationNotifier.value;
    final next = curPos + const Duration(seconds: 15);
    await _audioPlayer.seek(next < total ? next : total);
  }

  void _seekBackward() async {
    final curPos = _positionNotifier.value;
    final next = curPos - const Duration(seconds: 15);
    await _audioPlayer.seek(next > Duration.zero ? next : Duration.zero);
  }

  void _adjustVolume(double delta) async {
    final newVal = (_volumeNotifier.value + delta).clamp(0.0, 1.0);
    _volumeNotifier.value = newVal;
    await _audioPlayer.setVolume(newVal);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          Container(
            color: const Color(0xFF14151A),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // ── Album art ──
                  RepaintBoundary(
                    child: RotationTransition(
                      turns: _rotationController,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isPlayingNotifier,
                        builder: (context, playing, _) => Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [widget.accent.withAlpha(200), const Color(0xFF14151A)],
                            ),
                            boxShadow: [
                              BoxShadow(color: widget.accent.withAlpha(playing ? 140 : 80), blurRadius: playing ? 50 : 30, spreadRadius: playing ? 12 : 6),
                              BoxShadow(color: widget.accent.withAlpha(playing ? 70 : 30), blurRadius: 90, spreadRadius: 20),
                            ],
                          ),
                          child: Icon(Icons.music_note_rounded, size: 80, color: Colors.white.withAlpha(120)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ── Track info ──
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPlayingNotifier,
                    builder: (context, playing, _) => Text(
                      playing ? 'Playing Sample Track' : 'Music Paused',
                      style: TextStyle(color: widget.textPri, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('SoundHelix Song 1', style: TextStyle(color: widget.textSec, fontSize: 13)),

                  const SizedBox(height: 36),

                  // ── Controls ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(icon: Icon(Icons.volume_down_rounded, color: widget.textSec), iconSize: 28, onPressed: () => _adjustVolume(-0.1)),
                      const SizedBox(width: 8),
                      IconButton(icon: Icon(Icons.replay_10_rounded, color: widget.textSec), iconSize: 36, onPressed: _seekBackward),
                      const SizedBox(width: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: _isPlayingNotifier,
                        builder: (context, playing, _) => GestureDetector(
                          onTap: _togglePlayPause,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            width: 66, height: 66,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [widget.accent, widget.accent.withAlpha(180)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: widget.accent.withAlpha(playing ? 140 : 80), blurRadius: playing ? 24 : 16, spreadRadius: playing ? 4 : 0)],
                            ),
                            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 38),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(icon: Icon(Icons.forward_10_rounded, color: widget.textSec), iconSize: 36, onPressed: _seekForward),
                      const SizedBox(width: 8),
                      IconButton(icon: Icon(Icons.volume_up_rounded, color: widget.textSec), iconSize: 28, onPressed: () => _adjustVolume(0.1)),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Progress ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        ValueListenableBuilder2<Duration, Duration>(
                          _positionNotifier,
                          _durationNotifier,
                          (context, pos, dur) => Column(
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
                                  value: pos.inSeconds.toDouble(),
                                  min: 0.0,
                                  max: dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                                  onChanged: (v) async => await _audioPlayer.seek(Duration(seconds: v.toInt())),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(pos), style: TextStyle(color: widget.textSec, fontSize: 11)),
                                  Text(_formatDuration(dur), style: TextStyle(color: widget.textSec, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<double>(
                          valueListenable: _volumeNotifier,
                          builder: (context, vol, _) => Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volume_up_outlined, size: 14, color: widget.textSec),
                              const SizedBox(width: 6),
                              Text('${(vol * 100).toInt()}%', style: TextStyle(color: widget.textSec, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          
          // Speed Badge
          Positioned(
            top: 24,
            right: 24,
            child: RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isOverLimit ? const Color(0xFFFF3B3B).withValues(alpha: 0.15) : const Color(0xFF1E1F26).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: widget.isOverLimit ? const Color(0xFFFF3B3B) : Colors.white12),
                  boxShadow: [if (widget.isOverLimit) BoxShadow(color: const Color(0xFFFF3B3B).withValues(alpha: 0.4), blurRadius: 16)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.speed.toInt().toString(),
                      style: TextStyle(
                        color: widget.isOverLimit ? const Color(0xFFFF3B3B) : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                        shadows: [if (widget.isOverLimit) const Shadow(color: Color(0xFFFF3B3B), blurRadius: 10) else Shadow(color: Colors.white24, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('km/h', style: TextStyle(color: widget.isOverLimit ? const Color(0xFFFF3B3B).withAlpha(180) : Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2(this.first, this.second, this.builder, {super.key});
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext context, A a, B b) builder;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<A>(
    valueListenable: first,
    builder: (context, a, _) => ValueListenableBuilder<B>(
      valueListenable: second,
      builder: (context, b, _) => builder(context, a, b),
    ),
  );
}
