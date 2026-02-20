import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class ImageUploadSection extends StatefulWidget {
  final List<File> selectedImages;
  final Function(List<File>) onImagesChanged;
  final List<String>? existingImageUrls;
  final TextEditingController? textController;

  const ImageUploadSection({
    super.key,
    required this.selectedImages,
    required this.onImagesChanged,
    this.existingImageUrls,
    this.textController,
  });

  @override
  State<ImageUploadSection> createState() => _ImageUploadSectionState();
}

class _ImageUploadSectionState extends State<ImageUploadSection> {
  @override
  Widget build(BuildContext context) {
    final totalImages = (widget.existingImageUrls?.length ?? 0) + widget.selectedImages.length;
    final hasImages = totalImages > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Chapter Images',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              '(optional)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const Spacer(),
            if (widget.textController != null && hasImages)
              TextButton.icon(
                onPressed: _showInsertMarkerDialog,
                icon: const Icon(Icons.add_location, size: 18),
                label: const Text('Insert Marker'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('Add Images'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Help text
        if (widget.textController != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use [Image 1], [Image 2], etc. in your text to mark where images should appear',
                    style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 12),
        
        if (!hasImages)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.image, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No images added',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Existing images from server
              if (widget.existingImageUrls != null)
                ...List.generate(
                  widget.existingImageUrls!.length,
                  (index) => _buildExistingImageThumbnail(
                    widget.existingImageUrls![index],
                    index + 1,
                  ),
                ),
              
              // Newly selected images
              ...List.generate(
                widget.selectedImages.length,
                (index) => _buildImageThumbnail(
                  widget.selectedImages[index],
                  (widget.existingImageUrls?.length ?? 0) + index + 1,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildImageThumbnail(File file, int imageNumber) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              // Image number badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'Image $imageNumber',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Image preview
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(file),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 28,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
            onPressed: () => _removeImage(file),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
              minimumSize: const Size(24, 24),
            ),
          ),
        ),
        // Insert marker button
        if (widget.textController != null)
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: ElevatedButton.icon(
              onPressed: () => _insertImageMarker(imageNumber),
              icon: const Icon(Icons.add_location, size: 14),
              label: const Text('Insert', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExistingImageThumbnail(String url, int imageNumber) {
    return Container(
      width: 120,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Column(
        children: [
          // Image number badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              'Image $imageNumber',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Image preview
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(url),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Saved indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text(
              'Saved',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green[900],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      final files = result.files.map((file) => File(file.path!)).toList();
      final updatedList = [...widget.selectedImages, ...files];
      widget.onImagesChanged(updatedList);
      setState(() {});
    }
  }

  void _removeImage(File file) {
    final updatedList = widget.selectedImages.where((f) => f.path != file.path).toList();
    widget.onImagesChanged(updatedList);
    setState(() {});
  }

  void _insertImageMarker(int imageNumber) {
    if (widget.textController == null) return;

    final controller = widget.textController!;
    final marker = '[Image $imageNumber]';
    
    // Get current cursor position
    final selection = controller.selection;
    final currentText = controller.text;
    
    // Insert marker at cursor position
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      marker,
    );
    
    controller.text = newText;
    
    // Move cursor after the inserted marker
    controller.selection = TextSelection.collapsed(
      offset: selection.start + marker.length,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Inserted $marker at cursor position'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInsertMarkerDialog() {
    final totalImages = (widget.existingImageUrls?.length ?? 0) + widget.selectedImages.length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Image Marker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select which image to insert at cursor position:'),
            const SizedBox(height: 16),
            ...List.generate(totalImages, (index) {
              final imageNumber = index + 1;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    '$imageNumber',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text('Image $imageNumber'),
                trailing: const Icon(Icons.add_location),
                onTap: () {
                  _insertImageMarker(imageNumber);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}