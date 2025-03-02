# Pixeloid

An interactive photo canvas app that allows users to capture, edit, and share photos on Instagram Stories.

## Features

- **Camera Integration**: Capture photos directly from the app or select from gallery
- **Interactive Canvas**: Draw on photos with customizable brush color and size
- **Sticker Support**: Add SVG stickers with intuitive gesture controls:
  - Drag to position
  - Pinch to resize
  - Rotate gestures to rotate
  - Long-press and drag to delete zone to remove
- **Caption Input**: Add text captions to your photos
- **Instagram Sharing**: Share edited photos directly to Instagram Stories

## Prerequisites

- Flutter SDK (latest stable version)
- Android Studio or Xcode
- A physical device for testing camera functionality

## Usage

1. Launch the app
2. Capture a photo using the camera or select one from your gallery
3. Edit the photo:
   - Draw on it using the brush tool
   - Add stickers from the sticker picker
   - Use intuitive gestures to manipulate stickers:
     - Tap to select/deselect
     - Drag to position
     - Pinch to resize
     - Rotate with two fingers
     - Long-press and drag to the delete zone to remove
4. Add a caption
5. Share to Instagram Stories

## Implementation Details

The app uses the following packages for various functionalities:

- `camera`: For camera integration and photo capture
- `flutter_painter_v2`: For drawing on images with advanced features
- `flutter_svg`: For rendering SVG stickers
- `provider`: For state management
- `path_provider`: For file system access
- `url_launcher`: For launching Instagram

### Stickers

The app includes 80 SVG stickers that are stored in the `assets/stickers` directory. The stickers are named numerically (1.svg, 2.svg, etc.) and can be selected from the sticker picker in the editor screen.

### Gesture Controls

The app implements intuitive gesture controls for sticker manipulation:

- **Tap**: Select or deselect a sticker
- **Drag**: Move a sticker around the canvas
- **Pinch**: Resize a sticker (zoom in/out)
- **Rotation**: Rotate a sticker with a two-finger rotation gesture
- **Long-press and drag**: Activate delete mode, allowing you to drag the sticker to a delete zone at the bottom of the screen

## License

This project is licensed under the MIT License.
