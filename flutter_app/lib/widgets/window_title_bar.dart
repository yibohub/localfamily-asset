import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 自定义标题栏（带窗口控制按钮）
class WindowTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;

  const WindowTitleBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: AppBar(
        title: Text(title),
        centerTitle: true,
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leading,
        actions: [
          // 左侧自定义操作
          if (actions != null) ...actions!,
          const Spacer(),
          // 窗口控制按钮
          _WindowControls(),
        ],
      ),
    );
  }
}

class _WindowControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight + 10,
      child: Row(
        children: [
          _WindowButton(
            icon: Icons.remove,
    onPressed: () async {
              await windowManager.minimize();
            },
          ),
          _WindowButton(
            icon: Icons.check_box_outline_blank,
            onPressed: () async {
              bool isMaximized = await windowManager.isMaximized();
              if (isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowButton(
            icon: Icons.close,
            isClose: true,
            onPressed: () async {
              await windowManager.close();
            },
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor = Colors.transparent;
    if (_isHovering) {
      if (widget.isClose) {
        backgroundColor = const Color(0xFFE81123); // Windows 红色关闭按钮
      } else {
        backgroundColor = isDark ? Colors.white12 : Colors.black12;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: kToolbarHeight + 10,
          color: backgroundColor,
          child: Icon(
            widget.icon,
            size: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
