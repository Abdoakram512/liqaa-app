import 'package:flutter/material.dart';

import '../../../world/presentation/views/child_world_shell_view.dart';

/// Child & Parent World Hub entry point delegating seamlessly to the
/// personalized living world shell (`عالمي` / `مغامرتي` / `ألعابي` / `كنوزي`).
class ChildHomeView extends StatelessWidget {
  const ChildHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChildWorldShellView();
  }
}
