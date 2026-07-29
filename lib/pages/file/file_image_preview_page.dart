import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../models/file_item.dart';
import '../../providers/file_image_provider.dart';

/// 图片预览画廊（借鉴 nbox PhotoGalleryPage：PageController + "n/total" + 黑底）
class FileImagePreviewPage extends ConsumerStatefulWidget {
  final List<FileItem> images;
  final int initialIndex;

  const FileImagePreviewPage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  ConsumerState<FileImagePreviewPage> createState() =>
      _FileImagePreviewPageState();
}

class _FileImagePreviewPageState extends ConsumerState<FileImagePreviewPage> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.images.length}'),
      ),
      body: PhotoViewGallery(
        pageController: _pageController,
        onPageChanged: _onPageChanged,
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        pageOptions: widget.images.map<PhotoViewGalleryPageOptions>((img) {
          return PhotoViewGalleryPageOptions.customChild(
            heroAttributes: PhotoViewHeroAttributes(tag: img.path),
            child: Consumer(
              builder: (ctx, ref, _) {
                final asyncFile = ref.watch(fileImageProvider(img.path));
                return asyncFile.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      '加载失败: $e',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  data: (file) => Image.file(file, fit: BoxFit.contain),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
