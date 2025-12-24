import 'dart:io';
import 'package:flutter/material.dart';
import '../models/part.dart';

class PartsTrackerSheet extends StatefulWidget {
  final List<AssemblyPart> parts;
  final VoidCallback onUpdate;

  const PartsTrackerSheet({
    super.key,
    required this.parts,
    required this.onUpdate,
  });

  @override
  State<PartsTrackerSheet> createState() => _PartsTrackerSheetState();
}

class _PartsTrackerSheetState extends State<PartsTrackerSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          const BoxShadow(
            blurRadius: 15,
            color: Colors.black26,
            offset: Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handyman, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                "Hardware Tray",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.parts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final part = widget.parts[index];
                return _buildPartCard(part);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartCard(AssemblyPart part) {
    bool isDone = part.isComplete;

    // DECIDE WHICH IMAGE TO SHOW
    Widget imageWidget;
    if (part.isFileBased && part.fileOnDisk!.existsSync()) {
      // Show from File
      imageWidget = Image.file(
        part.fileOnDisk!,
        fit: BoxFit.contain,
        width: double.infinity,
      );
    } else if (part.memoryBytes != null) {
      // Show from Memory (Base64)
      imageWidget = Image.memory(
        part.memoryBytes!,
        fit: BoxFit.contain,
        width: double.infinity,
      );
    } else {
      // Fallback
      imageWidget = const Icon(Icons.broken_image, color: Colors.grey);
    }

    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? Colors.green : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // IMAGE HEADER
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageWidget,
              ),
            ),
          ),

          // CONTROLS
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    "ID: ${part.id}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${part.usedQuantity}/${part.totalQuantity}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: isDone ? Colors.green : Colors.blue,
                        ),
                      ),

                      // USE BUTTON
                      InkWell(
                        onTap: isDone
                            ? null
                            : () {
                                setState(() {
                                  part.usedQuantity++;
                                  widget.onUpdate();
                                });
                              },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDone ? Colors.grey : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
