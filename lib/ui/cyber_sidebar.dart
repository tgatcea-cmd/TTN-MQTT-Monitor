import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/device.dart';
import '../design/cyber_theme.dart';

class CyberSidebar extends StatelessWidget {
  final List<Device> devices;
  final Device? selectedDevice;
  final Function(Device) onSelect;
  final VoidCallback onAdd;
  final Function(Device) onEdit;
  final Function(Device) onDelete;

  const CyberSidebar({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: CyberTheme.bgDeep.withValues(alpha: 0.95),
        border: Border(right: BorderSide(color: CyberTheme.neonSafe.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("NET_NODES", style: CyberTheme.theme.textTheme.labelSmall),
                Text("DISPOSITIVOS", style: CyberTheme.theme.textTheme.displayMedium?.copyWith(fontSize: 24)),
              ],
            ),
          ),
          Divider(color: CyberTheme.neonSafe.withValues(alpha: 0.1)),
          
          // Lista de Dispositivos
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isSelected = selectedDevice?.id == device.id;
                
                return InkWell(
                  onTap: () => onSelect(device),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? CyberTheme.neonSafe.withValues(alpha: 0.1) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected 
                          ? Border.all(color: CyberTheme.neonSafe.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.hexagon_outlined, 
                          color: isSelected ? CyberTheme.neonSafe : CyberTheme.textDim,
                          size: 18
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name.toUpperCase(),
                                style: CyberTheme.theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 14,
                                  color: isSelected ? Colors.white : CyberTheme.textDim,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                ),
                              ),
                              Text(
                                device.deviceEui,
                                style: CyberTheme.theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton(
                          icon: Icon(Icons.more_vert, size: 16, color: CyberTheme.textDim),
                          color: CyberTheme.bgSlate,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('MODIFICAR', style: CyberTheme.theme.textTheme.bodyMedium),
                              onTap: () => Future.delayed(Duration.zero, () => onEdit(device)),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('ELIMINAR', style: CyberTheme.theme.textTheme.bodyMedium?.copyWith(color: CyberTheme.neonCrit)),
                              onTap: () => onDelete(device),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Botón Añadir Estilizado
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onAdd();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: CyberTheme.neonSafe),
                  color: CyberTheme.neonSafe.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Text(
                    "+ AÑADIR NODO",
                    style: CyberTheme.theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}