// ui/widgets/device_camera_roll.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models.dart';
import '../theme.dart';

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
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart, // Smoother, more premium feel
        );
      }
    }
  }

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final now = DateTime.now();
      if (now.difference(_lastScrollTime).inMilliseconds < 200) return;

      if (event.scrollDelta.dy > 0 && _currentIndex < widget.devices.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400), 
          curve: Curves.easeOutQuart
        );
        _lastScrollTime = now;
      } else if (event.scrollDelta.dy < 0 && _currentIndex > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 400), 
          curve: Curves.easeOutQuart
        );
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
        // 1. Content Area (Expanded to fill available vertical space)
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
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) => widget.deviceViewBuilder(widget.devices[index]),
            ),
          ),
        ),

        // 2. Pagination / Navigation Footer
        // Only show if there is more than one device to reduce clutter
        if (widget.devices.length > 1)
          Container(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNavButton(
                  icon: LucideIcons.chevronLeft,
                  onTap: _currentIndex > 0 
                    ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 400), 
                        curve: Curves.easeOutQuart
                      )
                    : null,
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "${_currentIndex + 1} / ${widget.devices.length}",
                    style: AppTheme.theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.0,
                      color: AppTheme.tertiary,
                    ),
                  ),
                ),
                
                _buildNavButton(
                  icon: LucideIcons.chevronRight,
                  onTap: _currentIndex < widget.devices.length - 1
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 400), 
                        curve: Curves.easeOutQuart
                      )
                    : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNavButton({required IconData icon, VoidCallback? onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: AppTheme.primary,
      disabledColor: AppTheme.border, // Very subtle when disabled
      splashRadius: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}