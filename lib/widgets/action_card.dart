// lib/widgets/action_card.dart

import 'package:flutter/material.dart';

// A 'StatelessWidget' is perfect here because the card just displays data
// and doesn't need to change itself.
class ActionCard extends StatelessWidget {
  // These 'final' variables are the parameters that will be passed in
  // when we create this widget.
  final String title;
  final String imagePath;
  final VoidCallback
  onTap; // 'VoidCallback' is just a function that takes no arguments.

  // This is the *constructor*. It requires you to provide a title, imagePath,
  // and onTap function whenever you create an 'ActionCard'.
  const ActionCard({
    super.key,
    required this.title,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 'Card' is a widget that creates a Material Design card
    // with rounded corners and a shadow.
    return Card(
      clipBehavior:
          Clip.antiAlias, // This makes the image round to the card's corners.
      elevation: 2.0, // This controls the shadow.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),

      // 'InkWell' is a widget that makes its child (the 'Column' in this case)
      // tappable and shows a ripple "splash" effect on tap.
      child: InkWell(
        onTap: onTap, // We assign the function that was passed in.
        // 'Column' is a widget that stacks its children *vertically*.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 'Expanded' is a layout widget. It tells its child (the 'Image')
            // to fill all *available* vertical space within the 'Column'.
            Expanded(
              // 'Image.asset' is how you load an image from your project's assets folder.
              child: Image.asset(
                imagePath,
                fit: BoxFit
                    .cover, // This makes the image cover the space, cropping if needed.
              ),
            ),

            // 'Padding' is a simple widget that adds space around its child.
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
