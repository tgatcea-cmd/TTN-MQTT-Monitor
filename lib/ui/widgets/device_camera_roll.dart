import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models.dart';

class DeviceCameraRoll extends StatefulWidget {
  final List<Device> devices;
  final Device? selectedDevice;
  final Function(Device) onDeviceChanged;
  final Widget Function(Device device) deviceViewBuilder;

  const DeviceCameraRoll({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.onDeviceChanged,
    required this.deviceViewBuilder,
  });

  @override
  State<DeviceCameraRoll> createState() => _DeviceCameraRollState();
}

class _DeviceCameraRollState extends State<DeviceCameraRoll> {
  late PageController _pageController;
  int _currentIndex = 0;
  DateTime _lastScrollTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentIndex = _calculateInitialIndex();
    _pageController = PageController(initialPage: _currentIndex);
  }

  int _calculateInitialIndex() {
    if (widget.selectedDevice == null || widget.devices.isEmpty) return 0;
    final index = widget.devices.indexWhere((d) => d.id == widget.selectedDevice!.id);
    return index != -1 ? index : 0;
  }

  @override
  void didUpdateWidget(DeviceCameraRoll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDevice?.id != oldWidget.selectedDevice?.id) {
      final newIndex = _calculateInitialIndex();
      if (newIndex != _currentIndex && _pageController.hasClients) {
        _currentIndex = newIndex;
        _pageController.animateToPage(
          newIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final now = DateTime.now();
      if (now.difference(_lastScrollTime).inMilliseconds < 200) return;

      if (event.scrollDelta.dy > 0 && _currentIndex < widget.devices.length - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        _lastScrollTime = now;
      } else if (event.scrollDelta.dy < 0 && _currentIndex > 0) {
        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        _lastScrollTime = now;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.devices.isEmpty) return const SizedBox();

    return Column(
      children: [
        // Content Area
        Expanded(
          child: Listener(
            onPointerSignal: _handleScroll,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                if (index >= 0 && index < widget.devices.length) {
                  widget.onDeviceChanged(widget.devices[index]);
                }
              },
              itemCount: widget.devices.length,
              itemBuilder: (context, index) => widget.deviceViewBuilder(widget.devices[index]),
            ),
          ),
        ),

        // Minimal Footer Control
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentIndex > 0 
                  ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease)
                  : null,
                icon: const Icon(LucideIcons.chevronLeft, size: 16),
              ),
              const SizedBox(width: 16),
              Text(
                "${_currentIndex + 1} / ${widget.devices.length}",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: Colors.grey
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _currentIndex < widget.devices.length - 1
                  ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease)
                  : null,
                icon: const Icon(LucideIcons.chevronRight, size: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }
}