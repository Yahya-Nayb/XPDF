/// An image selected by the user for PDF conversion.
///
/// Ephemeral — only lives in [ImageToPdfProvider] state during the feature
/// session. Not persisted to disk or shared with other providers.
class SelectedImage {
  final String id;
  final String path;

  const SelectedImage({required this.id, required this.path});
}
