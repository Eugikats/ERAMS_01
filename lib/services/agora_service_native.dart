import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import 'supabase_service.dart';

/// Full Agora RTC implementation used on Android / iOS / desktop.
class AgoraService {
  static const _appId = String.fromEnvironment('AGORA_APP_ID');

  RtcEngine? _engine;
  bool _localJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _videoEnabled = true;
  bool _speakerEnabled = true;

  // Callbacks — set by the call screen
  void Function(int uid)? onUserJoined;
  void Function(int uid)? onUserOffline;
  void Function()? onJoined;
  void Function(int code, String msg)? onError;

  bool get isInitialized => _engine != null;
  bool get localJoined => _localJoined;
  int? get remoteUid => _remoteUid;
  bool get isMuted => _muted;
  bool get isVideoEnabled => _videoEnabled;
  bool get isSpeakerEnabled => _speakerEnabled;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize({bool withVideo = true}) async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: _appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
      audioScenario: AudioScenarioType.audioScenarioDefault,
    ));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        _localJoined = true;
        onJoined?.call();
      },
      onUserJoined: (RtcConnection connection, int uid, int elapsed) {
        _remoteUid = uid;
        onUserJoined?.call(uid);
      },
      onUserOffline: (RtcConnection connection, int uid,
          UserOfflineReasonType reason) {
        if (_remoteUid == uid) _remoteUid = null;
        onUserOffline?.call(uid);
      },
      onError: (ErrorCodeType code, String msg) {
        onError?.call(code.index, msg);
      },
    ));

    if (withVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.disableVideo();
    }
    await _engine!.setEnableSpeakerphone(true);
  }

  Future<void> joinChannel(String channelId, {bool withVideo = true}) async {
    if (_engine == null) await initialize(withVideo: withVideo);

    final token = await _fetchToken(channelId);

    await _engine!.joinChannel(
      token: token ?? '',
      channelId: channelId,
      uid: 0,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: withVideo,
        autoSubscribeAudio: true,
        autoSubscribeVideo: withVideo,
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
  }

  Future<void> toggleVideo() async {
    _videoEnabled = !_videoEnabled;
    await _engine?.muteLocalVideoStream(!_videoEnabled);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> toggleSpeaker() async {
    _speakerEnabled = !_speakerEnabled;
    await _engine?.setEnableSpeakerphone(_speakerEnabled);
  }

  Future<void> leave() async {
    await _engine?.leaveChannel();
    _localJoined = false;
    _remoteUid = null;
    _muted = false;
    _videoEnabled = true;
  }

  Future<void> dispose() async {
    await _engine?.release();
    _engine = null;
  }

  // ── Video view builders (called by call_screen.dart) ──────────────────────

  Widget localVideoView() {
    if (_engine == null) return const SizedBox.shrink();
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget remoteVideoView(int uid, String channelId) {
    if (_engine == null) return const SizedBox.shrink();
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: channelId),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _fetchToken(String channelName) async {
    try {
      final resp = await supabaseClient.functions.invoke(
        'generate_agora_token',
        body: {'channelName': channelName, 'uid': 0},
      );
      return resp.data?['token'] as String?;
    } catch (_) {
      // Falls back to empty token — requires Agora console Test Mode enabled.
      return null;
    }
  }
}
