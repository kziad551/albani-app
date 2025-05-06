import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

void main() async {
  // We'll run this separately as a utility to generate proper icons
  // This is just template code - run this from a separate project if needed
  
  // Load original icon
  final bytes = await File('assets/images/app_logo.png').readAsBytes();
  final originalImage = img.decodeImage(bytes);
  
  if (originalImage == null) {
    print('Failed to load image');
    return;
  }
  
  // Create foreground image with padding (for adaptive icon)
  final foregroundImage = img.copyResize(
    originalImage,
    width: 768, // 75% of 1024
    height: 768, // 75% of 1024
  );
  
  // Create new 1024x1024 transparent image
  final paddedImage = img.Image(
    width: 1024,
    height: 1024,
  );
  
  // Paste the resized image in the center
  img.compositeImage(
    paddedImage,
    foregroundImage,
    dstX: (1024 - 768) ~/ 2,
    dstY: (1024 - 768) ~/ 2,
  );
  
  // Save as foreground.png
  final tempDir = await getTemporaryDirectory();
  final foregroundFile = File('${tempDir.path}/foreground.png');
  await foregroundFile.writeAsBytes(img.encodePng(paddedImage));
  print('Foreground saved to: ${foregroundFile.path}');
} 