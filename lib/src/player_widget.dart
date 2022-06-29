// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Adapted from https://github.com/bluefireteam/audioplayers/blob/master/packages/audioplayers/example/lib/player_widget.dart

import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'application_state.dart';

class PlayerWidget extends StatefulWidget {
  final String url;
  final PlayerMode mode;
  final BuildContext context;

  const PlayerWidget({
    Key? key,
    required this.url,
    this.mode = PlayerMode.MEDIA_PLAYER,
    required this.context,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PlayerWidgetState();
  }
}

class _PlayerWidgetState extends State<PlayerWidget> {
  static const skipIntervalInSec = 15;

  late AudioPlayer _audioPlayer;
  late AudioCache _audioCache;

  Duration _duration = const Duration();
  Duration _position = const Duration();

  PlayerState _playerState = PlayerState.STOPPED;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerErrorSubscription;
  StreamSubscription? _playerStateSubscription;

  String get _durationText => _durationToString(_duration);
  String get _positionText => _durationToString(_position);

  _PlayerWidgetState();

  late Slider _slider;
  double _sliderPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();

    Provider.of<ApplicationState>(context, listen: false)
        .onLeadDeviceChangeCallback = updatePlayer;
  }

  void updatePlayer(Map<dynamic, dynamic> snapshot) {
    _updatePlayer(snapshot['state'], snapshot['slider_position']);
  }

  void _updatePlayer(dynamic state, dynamic sliderPosition) {
    if (state is int && sliderPosition is double) {
      try {
        _updateSlider(sliderPosition);
        final PlayerState newState = PlayerState.values[state];
        if (newState != _playerState) {
          switch (newState) {
            case PlayerState.PLAYING:
              _play();
              break;
            case PlayerState.PAUSED:
              _pause();
              break;
            case PlayerState.STOPPED:
            case PlayerState.COMPLETED:
              _stop();
              break;
          }
          _playerState = newState;
        }
      } catch (e) {
        if (kDebugMode) {
          print('sync player failed');
        }
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerErrorSubscription?.cancel();
    _playerStateSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _slider = Slider(
      onChanged: _onSliderChangeHandler,
      value: _sliderPosition,
      divisions: 100,
      activeColor: Colors.purple.shade400,
      inactiveColor: Colors.purple.shade100,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _positionText,
                    style: const TextStyle(fontSize: 18.0),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2,
                    child: _slider,
                  ),
                  _duration.inSeconds == 0
                      ? getLocalFileDuration()
                      : Text(_durationText,
                          style: const TextStyle(fontSize: 18.0))
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('rewind_button'),
                    onPressed: _rewind,
                    iconSize: 48.0,
                    icon: const Icon(Icons.fast_rewind),
                    color: Colors.purple.shade400,
                  ),
                  IconButton(
                    key: const Key('play_button'),
                    onPressed:
                        _playerState == PlayerState.PLAYING ? _pause : _play,
                    iconSize: 48.0,
                    icon: _playerState == PlayerState.PLAYING
                        ? const Icon(Icons.pause)
                        : const Icon(Icons.play_arrow),
                    color: Colors.purple.shade400,
                  ),
                  IconButton(
                    key: const Key('fastforward_button'),
                    onPressed: _forward,
                    iconSize: 48.0,
                    icon: const Icon(Icons.fast_forward),
                    color: Colors.purple.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onSliderChangeHandler(double v) {
    if (kIsWeb && (v >= 1 || v == 0)) {
      // Avoid a bug in web player where extra tap gesture is bound.
      return;
    }
    _updateSlider(v);
    // update RTDB if device is the leader.
    Provider.of<ApplicationState>(context, listen: false)
        .setLeadDeviceState(_playerState.index, _sliderPosition);
  }

  void _updateSlider(double v) {
    _sliderPosition = v;
    _setPlaybackPositionWithSlider();

    // Avoid a bug in web where position is set to zero on pause.
    // Has to happen after playback position is set.
    if (kIsWeb && _playerState == PlayerState.PAUSED) {
      _audioPlayer.pause();
    }
  }

  void _setPlaybackPositionWithSlider() {
    final position = _sliderPosition * _duration.inMilliseconds;
    _position = Duration(milliseconds: position.round());
    _seek(_position);
  }

  Future<int> _getDuration() async {
    if (kIsWeb) {
      await _audioPlayer.setUrl(widget.url);
      return Future.delayed(
        const Duration(milliseconds: 300),
        () => _audioPlayer.getDuration(),
      );
    } else {
      await _audioCache
          .load(widget.url)
          .then((uri) => _audioPlayer.setUrl(uri.toString()));
      return Future.delayed(
          const Duration(milliseconds: 300), () => _audioPlayer.getDuration());
    }
  }

  FutureBuilder<int> getLocalFileDuration() {
    return FutureBuilder<int>(
      future: _getDuration(),
      initialData: 0,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.active:
          case ConnectionState.waiting:
            return const Text('...');
          case ConnectionState.done:
            if (snapshot.hasError) {
              if (kDebugMode) {
                print('Error: ${snapshot.error}');
              }
            } else if (snapshot.data != null) {
              _duration = Duration(milliseconds: snapshot.data!);
              return Text(_durationToString(_duration),
                  style: const TextStyle(fontSize: 18.0));
            }
            return const Text('...');
        }
      },
    );
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer(mode: widget.mode);
    _audioPlayer.setVolume(0.005);
    if (kIsWeb) {
      // Web only. Avoid recreating player.
      _audioPlayer.setReleaseMode(ReleaseMode.LOOP);
    }

    _audioCache = AudioCache(fixedPlayer: _audioPlayer);

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _positionSubscription = _audioPlayer.onAudioPositionChanged.listen((p) {
      if (kIsWeb) {
        if (p.inMilliseconds == 0 ||
            p.inMilliseconds >= _duration.inMilliseconds) {
          return;
        }
      }
      setState(() {
        _position = p;
        _setSliderWithPlaybackPosition();
      });
    });

    _playerCompleteSubscription =
        _audioPlayer.onPlayerCompletion.listen((event) {
      _stop();
    });

    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _playerState = state);
    });

    _playerErrorSubscription = _audioPlayer.onPlayerError.listen((msg) {
      setState(() {
        _playerState = PlayerState.STOPPED;
        _position = const Duration();
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
        });
      }
    });

    _audioPlayer.onNotificationPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
      }
    });
  }

  Future<int> _play() async {
    var result = 0;

    // update DB if device is active
    Provider.of<ApplicationState>(context, listen: false)
        .setLeadDeviceState(PlayerState.PLAYING.index, _sliderPosition);

    if (_playerState == PlayerState.PAUSED) {
      result = await _audioPlayer.resume();
      return result;
    }
    if (kIsWeb) {
      // Web does not have audioCache
      result = await _audioPlayer.play(widget.url, position: _position);
      if (result == 1) {
        setState(() => _playerState = PlayerState.PLAYING);
      }
    } else {
      _audioCache.play(widget.url);
      _playerState = PlayerState.PLAYING;
    }

    return result;
  }

  Future<int> _pause() async {
    final result = await _audioPlayer.pause();
    if (result == 1) {
      setState(() => {_playerState = PlayerState.PAUSED});
    }

    // update DB if device is active
    Provider.of<ApplicationState>(context, listen: false)
        .setLeadDeviceState(_playerState.index, _sliderPosition);
    return result;
  }

  Future<int> _seek(Duration _tempPosition) async {
    final result = await _audioPlayer.seek(_tempPosition);
    if (result == 1) {
      setState(() => _position = _tempPosition);
    }
    return result;
  }

  Future<int> _forward() async {
    return _updatePositionAndSlider(Duration(
        seconds:
            min(_duration.inSeconds, _position.inSeconds + skipIntervalInSec)));
  }

  Future<int> _rewind() async {
    return _updatePositionAndSlider(
        Duration(seconds: max(0, _position.inSeconds - skipIntervalInSec)));
  }

  Future<int> _updatePositionAndSlider(Duration tempPosition) async {
    final result = await _audioPlayer.seek(tempPosition);
    if (result == 1) {
      setState(() {
        _position = tempPosition;
        _setSliderWithPlaybackPosition();
      });
    }
    // update DB if device is active
    Provider.of<ApplicationState>(context, listen: false)
        .setLeadDeviceState(_playerState.index, _sliderPosition);
    return result;
  }

  void _setSliderWithPlaybackPosition() {
    final position = _position.inSeconds / _duration.inSeconds;
    _sliderPosition = position.isNaN ? 0 : position;
  }

  Future<int> _stop() async {
    final result = await _audioPlayer.stop();
    if (result == 1) {
      setState(() {
        _playerState = PlayerState.STOPPED;
        _position = const Duration();
        _setSliderWithPlaybackPosition();
      });
    }
    return result;
  }

  // Convert duration to [HH:]mm:ss format
  String _durationToString(Duration? duration) {
    String twoDigits(int? n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration?.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration?.inSeconds.remainder(60));
    if (duration?.inHours == 0) {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
    return '${twoDigits(duration?.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
}
