class VideoItem {
  final String id;
  final String title;
  final String path;
  final String folderName;
  final Duration duration;
  final String? thumbnailPath;

  VideoItem({
    required this.id,
    required this.title,
    required this.path,
    required this.folderName,
    required this.duration,
    this.thumbnailPath,
  });
}
