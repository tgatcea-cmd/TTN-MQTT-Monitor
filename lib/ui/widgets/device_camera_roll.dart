import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
    final index = widget.devices.indexWhere(
      (d) => d.id == widget.selectedDevice!.id,
    );
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

  // REMOVED: Unused _setInitialPage method

  void _handleScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final now = DateTime.now();
      if (now.difference(_lastScrollTime).inMilliseconds < 200) return;

      if (event.scrollDelta.dy > 0) {
        if (_currentIndex < widget.devices.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          _lastScrollTime = now;
        }
      } else if (event.scrollDelta.dy < 0) {
        if (_currentIndex > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          _lastScrollTime = now;
        }
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
    if (widget.devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No devices configured'),
          ],
        ),
      );
    }

    return Column(
      children: [
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
              itemBuilder: (context, index) =>
                  widget.deviceViewBuilder(widget.devices[index]),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.devices[_currentIndex].name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.devices[_currentIndex].deviceEui,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.devices.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.devices.length,
                  (index) => GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentIndex == index ? 12 : 8,
                      height: _currentIndex == index ? 12 : 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == index
                            ? Colors.indigo
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
