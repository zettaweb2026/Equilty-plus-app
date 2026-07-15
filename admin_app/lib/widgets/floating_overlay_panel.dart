import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/admin_hierarchy_provider.dart';
import '../screens/hierarchy/canvas_tree_view.dart';
import '../core/theme/app_theme.dart';

enum OverlayStateMode { closed, minimized, expanded }

class FloatingOverlayPanel extends StatefulWidget {
  final OverlayStateMode initialMode;
  final VoidCallback onClose;
  final Function(OverlayStateMode) onModeChanged;

  const FloatingOverlayPanel({
    super.key,
    required this.initialMode,
    required this.onClose,
    required this.onModeChanged,
  });

  @override
  State<FloatingOverlayPanel> createState() => _FloatingOverlayPanelState();
}

class _FloatingOverlayPanelState extends State<FloatingOverlayPanel> with SingleTickerProviderStateMixin {
  OverlayStateMode _currentMode = OverlayStateMode.closed;
  Offset _minimizedPosition = const Offset(-1, -1); // Uninitialized
  bool _isDragging = false;

  // Minimized size constants
  final double _minWidth = 170.0;
  final double _minHeight = 120.0;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    if (_currentMode == OverlayStateMode.expanded) {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant FloatingOverlayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMode != oldWidget.initialMode) {
      setState(() {
        _currentMode = widget.initialMode;
      });
      if (_currentMode == OverlayStateMode.expanded) {
        _loadData();
      }
    }
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminHierarchyProvider>(context, listen: false).fetchGlobalHierarchy();
    });
  }

  void _setMode(OverlayStateMode mode) {
    setState(() {
      _currentMode = mode;
    });
    widget.onModeChanged(mode);
    if (mode == OverlayStateMode.expanded) {
      _loadData();
    }
  }

  void _snapToEdge(Size screenSize) {
    final double midX = screenSize.width / 2;
    double targetX = 16.0; // Left snap position
    if (_minimizedPosition.dx + _minWidth / 2 > midX) {
      targetX = screenSize.width - _minWidth - 16.0; // Right snap position
    }

    // Keep Y within screen bounds
    double targetY = _minimizedPosition.dy;
    const double topMargin = 80.0;
    final double bottomMargin = screenSize.height - _minHeight - 100.0;
    targetY = max(topMargin, min(targetY, bottomMargin));

    setState(() {
      _minimizedPosition = Offset(targetX, targetY);
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMode == OverlayStateMode.closed) {
      return const SizedBox();
    }

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    // Initialize position at bottom right if uninitialized
    if (_minimizedPosition.dx == -1 && _minimizedPosition.dy == -1) {
      _minimizedPosition = Offset(
        screenSize.width - _minWidth - 16.0,
        screenSize.height - _minHeight - 120.0,
      );
    }

    if (_currentMode == OverlayStateMode.expanded) {
      return _buildExpandedView(screenSize);
    } else {
      return _buildMinimizedView(screenSize);
    }
  }

  // Renders the full expanded Canvas View hierarchy tree inside a glassmorphic overlay
  Widget _buildExpandedView(Size screenSize) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Semi-transparent backdrop blur
          GestureDetector(
            onTap: () => _setMode(OverlayStateMode.minimized),
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: screenSize.width * 0.9,
              height: screenSize.height * 0.75,
              decoration: AppTheme.glassCardDecoration().copyWith(
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    // Header Bar
                    _buildExpandedHeader(),
                    // Canvas / Loader
                    Expanded(
                      child: Consumer<AdminHierarchyProvider>(
                        builder: (context, provider, child) {
                          if (provider.isLoading) {
                            return const Center(
                              child: SpinKitFadingCube(
                                color: AppTheme.primaryPurple,
                                size: 40.0,
                              ),
                            );
                          }
                          if (provider.errorMessage != null) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      provider.errorMessage!,
                                      style: GoogleFonts.outfit(color: AppTheme.softGrey),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _loadData,
                                      child: const Text('Try Again'),
                                    )
                                  ],
                                ),
                              ),
                            );
                          }
                          if (provider.globalTree.isEmpty) {
                            return Center(
                              child: Text(
                                'No nodes available in the tree.',
                                style: GoogleFonts.outfit(color: AppTheme.softGrey),
                              ),
                            );
                          }
                          return CanvasTreeView(
                            tree: provider.globalTree,
                            onNodeTap: (node) {
                              // Display node info dialog
                              _showNodeDetails(node);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withOpacity(0.85),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderGrey.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: AppTheme.primaryPurple),
              const SizedBox(width: 12),
              Text(
                'Live Tree Monitor',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.lightText,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_fullscreen, color: AppTheme.softGrey),
                tooltip: 'Minimize',
                onPressed: () => _setMode(OverlayStateMode.minimized),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                tooltip: 'Close Monitor',
                onPressed: widget.onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Renders a floating, draggable glassmorphic card representing the minimized state
  Widget _buildMinimizedView(Size screenSize) {
    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      left: _minimizedPosition.dx,
      top: _minimizedPosition.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _minimizedPosition = Offset(
              _minimizedPosition.dx + details.delta.dx,
              _minimizedPosition.dy + details.delta.dy,
            );
          });
        },
        onPanEnd: (details) {
          _snapToEdge(screenSize);
        },
        onTap: () => _setMode(OverlayStateMode.expanded),
        child: Container(
          width: _minWidth,
          height: _minHeight,
          decoration: AppTheme.glassCardDecoration().copyWith(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryPurple.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: Column(
            children: [
              // Minimized Drag Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg.withOpacity(0.7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.neonGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tree PiP',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.lightText,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _setMode(OverlayStateMode.expanded),
                          child: const Icon(Icons.open_in_full, size: 12, color: AppTheme.softGrey),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: widget.onClose,
                          child: const Icon(Icons.close, size: 12, color: Colors.redAccent),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              // Body/Preview
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hub_outlined, color: AppTheme.primaryPurple, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to View Map',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.lightText,
                        ),
                      ),
                      Text(
                        'Drag to reposition',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: AppTheme.softGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNodeDetails(dynamic node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryPurple.withOpacity(0.2),
              child: Text(
                node.name.isNotEmpty ? node.name[0].toUpperCase() : 'U',
                style: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                node.name,
                style: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', node.email),
            _buildDetailRow('Level', 'Level ${node.level}'),
            _buildDetailRow('Parent Code', node.parentId ?? 'NONE'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.lightText),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.softGrey)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
