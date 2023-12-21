import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc_app/screens/loading_elevated_button.dart';
import 'package:flutter_webrtc_app/screens/new_call_screen.dart';
import 'package:socket_io_client/socket_io_client.dart';

const String websocketUrl = "https://192.168.9.64:8080";
Socket? socket;

class WebRTCScreen extends StatefulWidget {
  const WebRTCScreen({super.key});

  @override
  State<WebRTCScreen> createState() => _WebRTCScreenState();
}

class _WebRTCScreenState extends State<WebRTCScreen> {
  String roomId = "";
  String email = "";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("P2P Call App"),
      ),
      body: Column(
        children: [
          TextField(
            decoration: InputDecoration(hintText: 'Enter Your Email'),
            onChanged: (value) {
              email = value;
            },
          ),
          TextField(
            decoration: InputDecoration(hintText: 'Enter Room Id'),
            onChanged: (value) {
              roomId = value;
            },
          ),
          LoadingElevatedButton(
            onPressed: () async {
              assert(email.isNotEmpty);
              assert(roomId.isNotEmpty);
              log("Connecting to socket on $websocketUrl");
              socket = io(
                  websocketUrl,
                  OptionBuilder()
                      .setTransports(['websocket'])
                      // .setExtraHeaders({'Content-Type': 'application/json'})
                      .disableAutoConnect()
                      .build());

              // listen onConnect event
              socket!.onConnect((data) {
                log("Socket connected !!");
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return NewCallScreen(
                        userId: email,
                        roomId: roomId,
                      );
                    },
                  ),
                );
              });

              socket!.onConnectError((data) {
                log("Connect Error $data");
              });

              socket!.connect();
            },
            icon: Icon(Icons.connect_without_contact),
            label: Text('Join'),
          ),
        ],
      ),
    );
  }
}
