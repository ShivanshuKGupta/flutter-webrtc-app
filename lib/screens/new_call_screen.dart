import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc_app/screens/my_screen.dart';

class NewCallScreen extends StatefulWidget {
  final String userId;
  final String roomId;
  const NewCallScreen({super.key, required this.userId, required this.roomId});

  @override
  State<NewCallScreen> createState() => _NewCallScreenState();
}

class _NewCallScreenState extends State<NewCallScreen> {
  final _localRTCVideoRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> peers = {};
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;

  final Map<String, RTCVideoRenderer> _remoteRTCVideoRenderers = {};

  @override
  void initState() {
    _localRTCVideoRenderer.initialize().then((value) => initLocalStream());
    // TODO: add a listener for disconnect event
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: peers.isEmpty
          ? Center(
              child: RTCVideoView(
                _localRTCVideoRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: math.sqrt(peers.length).toInt(),
                  childAspectRatio: 2 / 3,
                  children: [
                    for (final peer in _remoteRTCVideoRenderers.entries)
                      // Text(peer.key),
                      Container(
                        child: RTCVideoView(
                          _remoteRTCVideoRenderers[peer.key]!,
                          objectFit: RTCVideoViewObjectFit
                              .RTCVideoViewObjectFitContain,
                        ),
                      )
                  ],
                ),
                Wrap(
                  children: [
                    IconButton(
                      icon: Icon(
                        isVideoOn ? Icons.videocam : Icons.videocam_off,
                      ),
                      onPressed: () {
                        _toggleCamera();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        isAudioOn ? Icons.mic : Icons.mic_off,
                      ),
                      onPressed: () {
                        _toggleMic();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        isFrontCameraSelected
                            ? Icons.camera_front
                            : Icons.camera_rear,
                      ),
                      onPressed: () {
                        _switchCamera();
                      },
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          socket!.disconnect();
                          socket!.close();
                          Navigator.of(context).pop();
                        });
                      },
                      icon: Icon(Icons.call_end_rounded),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> initLocalStream() async {
    log("Initializing local stream");
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': isAudioOn,
      'video': isVideoOn
          ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
          : false,
    });
    _localRTCVideoRenderer.srcObject = _localStream;
    // setState(() {});
    await join();
    log("Joining Complete!");
    socket!.on(
      'addPeer',
      (config) {
        try {
          addPeer(
            peerId: config['peer_id'],
            should_create_offer: config['should_create_offer'],
          );
        } catch (e) {
          print("ERRRROOOORRRR: addPeer");
        }
      },
    );
    socket!.on(
      'sessionDescription',
      (config) {
        try {
          sessionDescription(
            peerId: config['peer_id'],
            session_description: config['session_description'],
          );
        } catch (e) {
          print("ERRRROOOORRRR: sessionDescription");
        }
      },
    );
    socket!.on(
      'iceCandidate',
      (config) {
        try {
          iceCandidate(
            config['peer_id'],
            config['ice_candidate'],
          );
        } catch (e) {
          print("ERRRROOOORRRR: iceCandidate");
        }
      },
    );
    socket!.on(
      'removePeer',
      (config) {
        try {
          removePeer(
            config['peer_id'],
          );
        } catch (e) {
          print("ERRRROOOORRRR: removePeer");
        }
      },
    );
  }

  Future<void> join() async {
    log("Emiting Join room ${widget.roomId}");
    socket!.emit('join', {
      'userdata': widget.userId,
      'channel': widget.roomId,
    });
  }

  Future<void> addPeer(
      {required String peerId, required bool should_create_offer}) async {
    log("Adding peer: $peerId");
    if (peers.containsKey(peerId)) {
      log("Already have a connection with id: $peerId");
      return;
    }
    peers.addEntries(
      [
        MapEntry(
          peerId,
          (await createPeerConnection({
            'iceServers': [
              {
                'urls': [
                  'stun:stun1.l.google.com:19302',
                  // 'stun:stun2.l.google.com:19302'
                ]
              }
            ]
          })),
        ),
      ],
    );
    log("Created local peer connection object peerId: $peerId");
    peers[peerId]!.onIceCandidate = (RTCIceCandidate candidate) {
      socket!.emit('relayICECandidate', {
        'peer_id': peerId,
        'ice_candidate': {
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate
        }
      });
    };

    peers[peerId]!.onTrack = (event) async {
      log("onTrack Called from peerId: $peerId");
      if (!_remoteRTCVideoRenderers.containsKey(peerId)) {
        _remoteRTCVideoRenderers.addAll({
          peerId: RTCVideoRenderer(),
        });
        await _remoteRTCVideoRenderers[peerId]!.initialize().then((value) {
          _remoteRTCVideoRenderers[peerId]!.srcObject = event.streams[0];
        });
      } else {
        _remoteRTCVideoRenderers[peerId]!.srcObject = event.streams[0];
      }
      setState(() {});
    };

    _localStream!.getTracks().forEach((track) {
      peers[peerId]!.addTrack(track, _localStream!);
    });

    if (should_create_offer) {
      log("Creating RTC offer to $peerId");
      RTCSessionDescription offer = await peers[peerId]!.createOffer();
      log("Local offer description is: $offer");
      await peers[peerId]!.setLocalDescription(offer);
      log("sending this offer: ${offer.toMap()}");
      socket!.emit('relaySessionDescription',
          {'peer_id': peerId, 'session_description': offer.toMap()});
      log("Offer setLocalDescription succeeded");
    }
  }

  Future<void> sessionDescription(
      {required peerId, required dynamic session_description}) async {
    final peer_id = peerId;
    final peer = peers[peer_id]!;
    final remote_description = session_description;
    // log("got session_description = ${session_description} for $peer_id");
    final desc = RTCSessionDescription(
        remote_description['sdp'], remote_description['type']);
    var stuff = await peer.setRemoteDescription(desc);
    log("setRemoteDescription succeeded");

    if (remote_description['type'] == "offer") {
      log("Creating answer");
      RTCSessionDescription answer = await peer.createAnswer();
      log("Answer description is: $answer");
      await peer.setLocalDescription(answer);
      print("Sending SDP answer");
      socket!.emit('relaySessionDescription',
          {'peer_id': peer_id, 'session_description': answer.toMap()});
      log("Answer setLocalDescription succeeded");
    }
    log("Description Object: $desc");
    log("Session Description succeeded");
  }

  Future<void> iceCandidate(String peerId, ice_candidate) async {
    final peer = peers[peerId]!;
    log("sending ice_candidate = $ice_candidate");
    await peer.addCandidate(
      // Yahan hai error
      RTCIceCandidate(
        ice_candidate['candidate'],
        ice_candidate['sdpMid'],
        ice_candidate['sdpMLineIndex'],
      ),
    );
    log("addIceCandidate succeeded");
  }

  Future<void> removePeer(String peerId) async {
    log("Removing peer: $peerId");
    if (_remoteRTCVideoRenderers.containsKey(peerId)) {
      _remoteRTCVideoRenderers[peerId]!.dispose();
      _remoteRTCVideoRenderers.remove(peerId);
    }
    if (peers.containsKey(peerId)) {
      peers[peerId]!.close();
      peers.remove(peerId);
    }
    setState(() {});
    log("Removing peer succeeded");
  }

  _toggleMic() {
    // change status
    isAudioOn = !isAudioOn;
    // enable or disable audio track
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  _toggleCamera() {
    // change status
    isVideoOn = !isVideoOn;

    // enable or disable video track
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    setState(() {});
  }

  _switchCamera() {
    // change status
    isFrontCameraSelected = !isFrontCameraSelected;

    // switch camera
    _localStream?.getVideoTracks().forEach((track) {
      // ignore: deprecated_member_use
      track.switchCamera();
    });
    setState(() {});
  }
}
