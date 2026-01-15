import 'package:flutter/material.dart';
import '../models/device.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _setInitialPage();
  }

  @override
  void didUpdateWidget(DeviceCameraRoll oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update when either selected device changes OR device list changes
    if (widget.selectedDevice?.id != oldWidget.selectedDevice?.id ||
        widget.devices.length != oldWidget.devices.length) {
      _setInitialPage();
    }
  }

  void _setInitialPage() {
    if (widget.selectedDevice == null || widget.devices.isEmpty) {
      _currentIndex = 0;
    } else {
      _currentIndex = widget.devices.indexWhere(
        (d) => d.id == widget.selectedDevice!.id,
      );
      if (_currentIndex == -1) _currentIndex = 0;

      // Animate to the selected device if needed
      if (mounted && _pageController.hasClients) {
        _pageController.animateToPage(
          _currentIndex,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No devices configured',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text(
              'Add a device from the menu to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Page View (Camera Roll)
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.onDeviceChanged(widget.devices[index]);
            },
            itemCount: widget.devices.length,
            itemBuilder: (context, index) =>
                widget.deviceViewBuilder(widget.devices[index]),
          ),
        ),
        
        // Indicator and device info
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Device name and current reading indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.devices[_currentIndex].deviceEui,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.devices.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Dot indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.devices.length,
                  (index) => GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
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
