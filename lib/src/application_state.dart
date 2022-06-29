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

import 'dart:io';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'authentication.dart';

typedef OnLeadDeviceChangeCallback = void Function(
    Map<dynamic, dynamic> snapshot);

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }

  Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        _loginState = ApplicationLoginState.loggedIn;
        _uid = user.uid;
        _addUserDevice().then((_) => listenToLeadDeviceChange());
      } else {
        _loginState = ApplicationLoginState.loggedOut;
      }
      notifyListeners();
    });
  }

  ApplicationLoginState _loginState = ApplicationLoginState.loggedOut;
  ApplicationLoginState get loginState => _loginState;

  String? _email;
  String? get email => _email;

  String? _deviceId;
  String? _uid;

  bool _isLeadDevice = false;
  String? leadDeviceType;

  OnLeadDeviceChangeCallback? onLeadDeviceChangeCallback;

  void startLoginFlow() {
    _loginState = ApplicationLoginState.emailAddress;
    notifyListeners();
  }

  Future<void> verifyEmail(
    String email,
    void Function(FirebaseAuthException e) errorCallback,
  ) async {
    try {
      var methods =
          await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.contains('password')) {
        _loginState = ApplicationLoginState.password;
      } else {
        _loginState = ApplicationLoginState.register;
      }
      _email = email;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  Future<void> signInWithEmailAndPassword(
    String email,
    String password,
    void Function(FirebaseAuthException e) errorCallback,
  ) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  void cancelRegistration() {
    _loginState = ApplicationLoginState.emailAddress;
    notifyListeners();
  }

  Future<void> registerAccount(
      String email,
      String displayName,
      String password,
      void Function(FirebaseAuthException e) errorCallback) async {
    try {
      var credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user!.updateDisplayName(displayName);
    } on FirebaseAuthException catch (e) {
      errorCallback(e);
    }
  }

  void signOut() {
    FirebaseAuth.instance.signOut();
    _isLeadDevice = false;
    leadDeviceType = 'Disconnected';
    // Remove oneself from the device list
  }

  Future<void> setLeadDevice() async {
    if (_uid != null && _deviceId != null) {
      var playerRef =
          FirebaseDatabase.instance.ref().child('/users/$_uid/active_device');
      await playerRef
          .update({'id': _deviceId, 'type': _getDevicePlatform()}).then((_) {
        _isLeadDevice = true;
      });
    }
  }

  Future<void> setLeadDeviceState(
      int playerState, double sliderPosition) async {
    if (_isLeadDevice && _uid != null && _deviceId != null) {
      var leadDeviceStateRef =
          FirebaseDatabase.instance.ref().child('/users/$_uid/active_device');
      try {
        var playerSnapshot = {
          'id': _deviceId,
          'state': playerState,
          'type': _getDevicePlatform(),
          'slider_position': sliderPosition
        };
        await leadDeviceStateRef.set(playerSnapshot);
      } catch (e) {
        throw Exception('updated playerState with error');
      }
    }
  }

  Future<void> listenToLeadDeviceChange() async {
    if (_uid != null) {
      var activeDeviceRef =
          FirebaseDatabase.instance.ref().child('/users/$_uid/active_device');
      activeDeviceRef.onValue.listen((event) {
        final activeDeviceState = event.snapshot.value as Map<dynamic, dynamic>;
        String activeDeviceKey = activeDeviceState['id'] as String;
        _isLeadDevice = _deviceId == activeDeviceKey;
        leadDeviceType = activeDeviceState['type'] as String;
        if (!_isLeadDevice) {
          onLeadDeviceChangeCallback?.call(activeDeviceState);
        }
        notifyListeners();
      });
    }
  }

  Future<void> _addUserDevice() async {
    _uid = FirebaseAuth.instance.currentUser?.uid;

    String deviceType = _getDevicePlatform();
    // Create two objects which we will write to the
    // Realtime database when this device is offline or online
    var isOfflineForDatabase = {
      'type': deviceType,
      'state': 'offline',
      'last_changed': ServerValue.timestamp,
    };
    var isOnlineForDatabase = {
      'type': deviceType,
      'state': 'online',
      'last_changed': ServerValue.timestamp,
    };

    var devicesRef =
        FirebaseDatabase.instance.ref().child('/users/$_uid/devices');

    FirebaseInstallations.instance
        .getId()
        .then((fid) => _deviceId = fid)
        .then((_) {
      // Use the semi-persistent Firebase Installation Id to key devices
      var deviceStatusRef = devicesRef.child('$_deviceId');

      // RTDB Presence API
      FirebaseDatabase.instance
          .ref()
          .child('.info/connected')
          .onValue
          .listen((data) {
        if (data.snapshot.value == false) {
          return;
        }

        deviceStatusRef.onDisconnect().set(isOfflineForDatabase).then((_) {
          deviceStatusRef.set(isOnlineForDatabase);
        });
      });
    });
  }

  String _getDevicePlatform() {
    if (kIsWeb) {
      return 'Web';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isAndroid) {
      return 'Android';
    }
    return 'Unknown';
  }
}
