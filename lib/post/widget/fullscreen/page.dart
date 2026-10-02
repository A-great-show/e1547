import 'package:e1547/post/post.dart';
import 'package:e1547/shared/shared.dart';
import 'package:flutter/material.dart';

class PostFullscreen extends StatelessWidget {
  const PostFullscreen({super.key, required this.post, this.pan});

  final Post post;
  final GalleryPanController? pan;

  @override
  Widget build(BuildContext context) {
    return PostHistoryConnector(
      post: post,
      child: PostVideoRoute(
        post: post,
        stopOnDispose: false,
        child: PostFullscreenFrame(
          post: post,
          child: PostImageOverlay(
            post: post,
            builder: (context) {
              switch (post.type) {
                case PostType.image:
                  return _PostFullscreenImage(post: post, pan: pan);
                case PostType.video:
                  VideoPlayer? player = post.getVideo(context);
                  return Center(
                    child: Hero(
                      tag: post.link,
                      child: player != null
                          ? VideoGestures(
                              player: player,
                              child: PostVideoWidget(post: post),
                            )
                          : PostVideoWidget(post: post),
                    ),
                  );
                case PostType.unsupported:
                  // this never occurs, ImageOverlay will display instead.
                  throw StateError(
                    'PostFullscreen received an unsupported image!',
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _PostFullscreenImage extends StatefulWidget {
  const _PostFullscreenImage({required this.post, this.pan});

  final Post post;
  final GalleryPanController? pan;

  @override
  State<_PostFullscreenImage> createState() => _PostFullscreenImageState();
}

class _PostFullscreenImageState extends State<_PostFullscreenImage> {
  final ZoomController zoom = ZoomController();
  final ImageLoadController load = ImageLoadController();

  @override
  void initState() {
    super.initState();
    zoom.addListener(onZoom);
  }

  @override
  void dispose() {
    final GalleryPanController? pan = widget.pan;
    if (pan != null && zoom.isZoomed) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => pan.locked.value = false,
      );
    }
    zoom.dispose();
    load.dispose();
    super.dispose();
  }

  void onZoom() => widget.pan?.locked.value = zoom.isZoomed;

  void onSpare(Offset spare) =>
      DismissController.maybeOf(context)?.push(spare.dy);

  void onSpareEnd(Velocity velocity) {
    final DismissController? dismiss = DismissController.maybeOf(context);
    if (dismiss != null && dismiss.release(velocity.pixelsPerSecond.dy)) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Post post = widget.post;
    final Size content = Size(post.width.toDouble(), post.height.toDouble());
    return Stack(
      fit: StackFit.expand,
      children: [
        DismissPointers(
          child: DismissTransform(
            child: Zoomable(
              controller: zoom,
              content: content,
              pan: widget.pan,
              onSpare: onSpare,
              onSpareEnd: onSpareEnd,
              onSpareCancel: () => DismissController.maybeOf(context)?.settle(),
              child: Center(
                child: AspectRatio(
                  aspectRatio: content.aspectRatio,
                  child: Hero(
                    tag: post.link,
                    child: PostImageWidget(
                      post: post,
                      fit: BoxFit.cover,
                      size: PostImageSize.file,
                      lowResCacheSize: context.watch<ImageCacheSize?>()?.size,
                      load: load,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        DismissFade(
          child: ImageLoadOverlay(
            load: load,
            moves: zoom.transformation,
            locate: (size) => switch (containedRect(content, size)) {
              final Rect image => MatrixUtils.transformRect(
                zoom.transformation.value,
                image,
              ),
              null => null,
            },
          ),
        ),
      ],
    );
  }
}
