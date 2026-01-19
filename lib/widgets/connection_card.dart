import 'package:flutter/material.dart';
import '../models.dart';
import '../config.dart';

class ConnectionCard extends StatefulWidget {
  final TTNProfile? selectedProfile;
  final bool isConnected;
  final String lastLog;
  final TextEditingController deviceIdController;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final Function(TTNProfile?)? onProfileChanged;
  final Function(TTNProfile)? onShowKeyDialog;

  const ConnectionCard({
    super.key,
    required this.selectedProfile,
    required this.isConnected,
    required this.lastLog,
    required this.deviceIdController,
    required this.onConnect,
    required this.onDisconnect,
    this.onProfileChanged,
    this.onShowKeyDialog,
  });

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  widget.isConnected ? Icons.cloud_sync : Icons.cloud_off,
                  color: widget.isConnected ? Colors.green : Colors.grey,
                ),
                SizedBox(width: 10),
                Text(
                  widget.isConnected
                      ? "SYSTEM MONITORING ACTIVE"
                      : "SYSTEM IDLE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.isConnected ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            Divider(height: 20),

            DropdownButtonFormField<TTNProfile>(
              decoration: InputDecoration(
                labelText: "View Device Dashboard",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                prefixIcon: Icon(Icons.visibility),
              ),
              initialValue: widget.selectedProfile,
              isExpanded: true,
              onChanged: widget.onProfileChanged,
              items: ttnProfiles
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
            ),
            SizedBox(height: 10),

            if (widget.selectedProfile?.canControl == true ||
                widget.selectedProfile?.defaultDeviceId != null)
              TextField(
                controller: widget.deviceIdController,
                readOnly: widget.selectedProfile?.canControl != true,
                decoration: InputDecoration(
                  labelText: widget.selectedProfile?.canControl == true
                      ? 'Target Device EUI (for commands)'
                      : 'Device EUI',
                  border: OutlineInputBorder(),
                  helperText: widget.selectedProfile?.canControl == true
                      ? "Control allowed for this device"
                      : "Monitoring this specific ID",
                ),
              ),

            SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !widget.isConnected ? widget.onConnect : null,
                    icon: Icon(Icons.play_arrow),
                    label: Text('START MONITORING'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 10),

                OutlinedButton(
                  onPressed: widget.selectedProfile == null
                      ? null
                      : () => widget.onShowKeyDialog?.call(
                          widget.selectedProfile!,
                        ),
                  child: Icon(
                    Icons.vpn_key,
                    color: (widget.selectedProfile?.accessKey != null)
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
                SizedBox(width: 10),

                if (widget.isConnected)
                  IconButton(
                    onPressed: widget.onDisconnect,
                    icon: Icon(
                      Icons.stop_circle_outlined,
                      color: Colors.red,
                      size: 32,
                    ),
                    tooltip: "Stop Monitoring",
                  ),
              ],
            ),
            SizedBox(height: 5),
            Text(
              widget.lastLog,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
