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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'application_state.dart';
import 'authentication.dart';

class Header extends StatelessWidget {
  const Header(this.heading, {Key? key}) : super(key: key);
  final String heading;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          heading,
          style: const TextStyle(fontSize: 24),
        ),
      );
}

class StyledButton extends StatelessWidget {
  const StyledButton({required this.child, required this.onPressed, Key? key})
      : super(key: key);
  final Widget child;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.deepPurple)),
        onPressed: onPressed,
        child: child,
      );
}

class ActiveControllerText extends StatelessWidget {
  const ActiveControllerText({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ApplicationState>(
      builder: (context, appState, child) {
        return Text(
          appState.leadDeviceType ?? 'None',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

class AppBarMenuButton extends StatelessWidget {
  const AppBarMenuButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ApplicationState>(
      builder: (context, appState, child) {
        if (appState.loginState == ApplicationLoginState.loggedIn) {
          return SignedInMenuButton(buildContext: context);
        }
        return SignInMenuButton(buildContext: context);
      },
    );
  }
}

class SignedInMenuButton extends StatelessWidget {
  const SignedInMenuButton({Key? key, required this.buildContext})
      : super(key: key);
  final BuildContext buildContext;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: _handleSignedInMenu,
      color: Colors.deepPurple.shade300,
      itemBuilder: (context) => _getMenuItemBuilder(),
    );
  }

  List<PopupMenuEntry<String>> _getMenuItemBuilder() {
    return [
      const PopupMenuItem<String>(
        value: 'Sign out',
        child: Text(
          'Sign out',
          style: TextStyle(color: Colors.white),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'Controller',
        child: Text(
          'Set as controller',
          style: TextStyle(color: Colors.white),
        ),
      )
    ];
  }

  Future<void> _handleSignedInMenu(String value) async {
    switch (value) {
      case 'Sign out':
        Provider.of<ApplicationState>(buildContext, listen: false).signOut();
        break;
      case 'Controller':
        Provider.of<ApplicationState>(buildContext, listen: false)
            .setLeadDevice();
    }
  }
}

class SignInMenuButton extends StatelessWidget {
  const SignInMenuButton({Key? key, required this.buildContext})
      : super(key: key);
  final BuildContext buildContext;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: _signIn,
      color: Colors.deepPurple.shade300,
      itemBuilder: (context) => _getMenuItemBuilder(context),
    );
  }

  Future<void> _signIn(String value) async {
    return showDialog<void>(
      context: buildContext,
      builder: (context) => const SignInDialog(),
    );
  }

  List<PopupMenuEntry<String>> _getMenuItemBuilder(BuildContext context) {
    return [
      const PopupMenuItem<String>(
        value: 'Sign in',
        child: Text(
          'Sign in',
          style: TextStyle(color: Colors.white),
        ),
      ),
    ];
  }
}

class SignInDialog extends AlertDialog {
  const SignInDialog({Key? key}) : super(key: key);

  @override
  AlertDialog build(BuildContext context) {
    return AlertDialog(
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Consumer<ApplicationState>(
          builder: (context, appState, _) => Authentication(
            email: appState.email,
            loginState: appState.loginState,
            startLoginFlow: appState.startLoginFlow,
            verifyEmail: appState.verifyEmail,
            signInWithEmailAndPassword: appState.signInWithEmailAndPassword,
            cancelRegistration: appState.cancelRegistration,
            registerAccount: appState.registerAccount,
            signOut: appState.signOut,
          ),
        ),
      ]),
    );
  }
}
