import 'package:flutter/material.dart';
import 'session_manager.dart';

class SessionAwareWidget extends StatefulWidget {
  final Widget child;

  const SessionAwareWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<SessionAwareWidget> createState() => _SessionAwareWidgetState();
}

class _SessionAwareWidgetState extends State<SessionAwareWidget> with WidgetsBindingObserver {
  final SessionManager _sessionManager = SessionManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionManager.initialize(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionManager.resetTimer();
    } else if (state == AppLifecycleState.paused) {
      _sessionManager.updateActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _sessionManager.updateActivity(),
      onPanDown: (_) => _sessionManager.updateActivity(),
      behavior: HitTestBehavior.translucent,
      child: Listener(
        onPointerDown: (_) => _sessionManager.updateActivity(),
        onPointerMove: (_) => _sessionManager.updateActivity(),
        child: widget.child,
      ),
    );
  }
}