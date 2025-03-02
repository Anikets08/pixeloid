import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StickerPicker extends StatelessWidget {
  final Function(String) onStickerSelected;

  const StickerPicker({
    super.key,
    required this.onStickerSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Generate paths for all 80 stickers using the new naming convention
    final List<String> stickerPaths = List.generate(
      80,
      (index) => 'assets/stickers/${index + 1}.svg',
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: stickerPaths.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => onStickerSelected(stickerPaths[index]),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SvgPicture.asset(
                      stickerPaths[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
