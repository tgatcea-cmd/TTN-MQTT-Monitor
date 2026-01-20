import 'package:flutter/material.dart';
import '../models.dart'; // Corrected import
import 'database_config_dialog.dart';

class DeviceSidebar extends StatelessWidget {
  final List<Device> devices;
  final Device? selectedDevice;
  final Function(Device) onDeviceSelected;
  final VoidCallback onAddDevice;
  final Function(Device) onEditDevice;
  final Function(Device) onDeleteDevice;
  // ... rest of the file stays exactly the same ...
  const DeviceSidebar({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.onDeviceSelected,
    required this.onAddDevice,
    required this.onEditDevice,
    required this.onDeleteDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitored Devices',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8),
                Text(
                  '${devices.length} device${devices.length != 1 ? 's' : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...devices.map((device) {
                  final isSelected = selectedDevice?.id == device.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: ListTile(
                      title: Text(
                        device.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Colors.indigo : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        device.deviceEui,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: isSelected,
                      tileColor: isSelected
                          ? Colors.indigo.withValues(alpha: 0.1)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: () {
                        onDeviceSelected(device);
                      },
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 12),
                                Text('Edit'),
                              ],
                            ),
                            onTap: () {
                              Future.delayed(
                                Duration.zero,
                                () => onEditDevice(device),
                              );
                            },
                          ),
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 12),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                            onTap: () =>
                                _showDeleteConfirmation(context, device),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: onAddDevice,
                  icon: Icon(Icons.add),
                  label: Text('Add Device'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
                SizedBox(height: 8),

                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          DatabaseConfigDialog(onSaved: () {}),
                    );
                  },
                  icon: Icon(Icons.settings_applications),
                  label: Text('DB Config'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Device?'),
        content: Text(
          'Are you sure you want to remove "${device.name}" from monitoring? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onDeleteDevice(device);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}
