// ui/widgets/common/device_sidebar.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models.dart';
import '../../theme.dart'; // Access the central design system
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Area (Minimalist)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
          child: Text(
            'DEVICES',
            style: AppTheme.theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.tertiary,
            ),
          ),
        ),

        // 2. Scrollable Device List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: devices.length,
            separatorBuilder: (c, i) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final device = devices[index];
              final isSelected = selectedDevice?.id == device.id;
              final isOffline = isDeviceOffline(device);
              final hasAlarm = alarmStatus[device.id] ?? false;

              // Determine status color based on priority
              Color statusColor = AppTheme.success;
              if (isOffline) statusColor = AppTheme.secondary; // Offline is grey/muted
              if (hasAlarm) statusColor = AppTheme.warning;    // Alarm is amber

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onDeviceSelected(device),
                  borderRadius: BorderRadius.circular(8),
                  hoverColor: AppTheme.surfaceSubtle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.surfaceSubtle : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected 
                          ? Border.all(color: AppTheme.border) 
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        // Status Indicator (Tiny, crisp)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Device Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                style: AppTheme.theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? AppTheme.primary : AppTheme.secondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                device.deviceEui,
                                style: AppTheme.theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: AppTheme.tertiary, 
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.normal
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Context Menu (Only visible on selection or hover ideally, 
                        // but here we keep it simple)
                        if (isSelected)
                          Builder(
                            builder: (btnContext) => IconButton(
                              icon: const Icon(LucideIcons.moreHorizontal, size: 16),
                              color: AppTheme.secondary,
                              onPressed: () => _showOptions(btnContext, device),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 3. Footer / Actions (Separated by subtle line)
        Divider(height: 1, color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddDevice,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add Device'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onImportDevices,
                      icon: const Icon(LucideIcons.download, size: 14),
                      label: const Text('Import'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.secondary,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  Container(width: 1, height: 16, color: AppTheme.border),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => DatabaseConfigDialog(onSaved: () {}),
                        );
                      },
                      icon: const Icon(LucideIcons.database, size: 14),
                      label: const Text('Config'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.secondary,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  void _showOptions(BuildContext context, Device device) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      items: [
        _buildMenuItem(LucideIcons.share2, 'Export Config', () => onExportDevice(device)),
        _buildMenuItem(LucideIcons.pencil, 'Edit Settings', () => onEditDevice(device)),
        _buildMenuItem(LucideIcons.trash2, 'Remove Device', () => onDeleteDevice(device), isDestructive: true),
      ],
    );
  }

  PopupMenuItem _buildMenuItem(IconData icon, String text, VoidCallback onTap, {bool isDestructive = false}) {
    return PopupMenuItem(
      onTap: () => Future.delayed(Duration.zero, onTap),
      height: 40,
      child: Row(
        children: [
          Icon(
            icon, 
            size: 16, 
            color: isDestructive ? AppTheme.error : AppTheme.secondary
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDestructive ? AppTheme.error : AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}