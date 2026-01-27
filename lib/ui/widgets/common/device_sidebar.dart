import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models.dart';
import '../dialogs/database_config_dialog.dart';

class DeviceSidebar extends StatelessWidget {
  final List<Device> devices;
  final Device? selectedDevice;
  final Function(Device) onDeviceSelected;
  final VoidCallback onAddDevice;
  final Function(Device) onEditDevice;
  final Function(Device) onDeleteDevice;
  final Function(Device) onExportDevice;
  final VoidCallback onImportDevices;
  final bool Function(Device) isDeviceOffline;
  final Map<String, bool> alarmStatus;

  const DeviceSidebar({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.onDeviceSelected,
    required this.onAddDevice,
    required this.onEditDevice,
    required this.onDeleteDevice,
    required this.onExportDevice,
    required this.onImportDevices,
    required this.isDeviceOffline,
    required this.alarmStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Row(
            children: [
              const Icon(LucideIcons.shieldCheck, size: 20),
              const SizedBox(width: 12),
              Text(
                'MONITOR',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),

        Divider(height: 1, color: Theme.of(context).dividerColor),

        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: devices.length,
            separatorBuilder: (c, i) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final device = devices[index];
              final isSelected = selectedDevice?.id == device.id;
              final isOffline = isDeviceOffline(device);
              final hasAlarm = alarmStatus[device.id] ?? false;

              return InkWell(
                onTap: () => onDeviceSelected(device),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.grey.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Theme.of(context).dividerColor)
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      // Status Dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOffline
                              ? Theme.of(context).colorScheme.error
                              : (hasAlarm
                                    ? Colors.orange
                                    : const Color(0xFF10B981)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              device.deviceEui,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.secondary,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Builder(
                          builder: (btnContext) {
                            return IconButton(
                              icon: const Icon(
                                LucideIcons.moreHorizontal,
                                size: 16,
                              ),
                              onPressed: () => _showOptions(btnContext, device),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: Theme.of(context).colorScheme.secondary,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Footer
        Divider(height: 1, color: Theme.of(context).dividerColor),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // "Export / Import" Row (Optional enhancement for future import)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAddDevice,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('New Device'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onImportDevices,
                  icon: const Icon(LucideIcons.download, size: 18),
                  label: const Text('Import Backup'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          DatabaseConfigDialog(onSaved: () {}),
                    );
                  },
                  icon: const Icon(LucideIcons.database, size: 16),
                  label: const Text('Database Config'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showOptions(BuildContext context, Device device) {
    // Now 'context' corresponds to the Builder wrapping the IconButton,
    // so findRenderObject() returns the button's RenderBox, not the SliverList.
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(
          onTap: () => Future.delayed(Duration.zero, () => onExportDevice(device)),
          child: const Row(
            children: [
              Icon(LucideIcons.share2, size: 16), // Share/Export Icon
              SizedBox(width: 12),
              Text('Export Configuration', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () =>
              Future.delayed(Duration.zero, () => onEditDevice(device)),
          child: const Row(
            children: [
              Icon(LucideIcons.pencil, size: 16),
              SizedBox(width: 12),
              Text('Edit Configuration', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () =>
              Future.delayed(Duration.zero, () => onDeleteDevice(device)),
          child: const Row(
            children: [
              Icon(LucideIcons.trash2, size: 16, color: Colors.red),
              SizedBox(width: 12),
              Text(
                'Remove Device',
                style: TextStyle(fontSize: 13, color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
