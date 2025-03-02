Implementation Plan:

1. Capture a Photo using the Camera
   Use the camera package to capture images from the device's camera.
2. Load the Captured Photo onto a Canvas
   Use the image_painter package to allow freehand drawing.
   Add a layer for stickers that users can move and resize.
3. Sticker Integration
   Download the Project Status Stickers from the provided Figma link.
   Store them as assets or provide a URL-based sticker library.
   Use the Stack widget to allow users to place, resize, and remove stickers.
4. Export or Discard the Edited Photo
   Convert the final image (drawing + stickers) into a single file using RepaintBoundary and RenderRepaintBoundary.
5. Add a Caption Input
   Provide a simple TextField for the user to add a caption.
6. Share Directly to Instagram Stories
   Use Instagram's deep linking URL scheme for Android and iOS.
