import 'package:flutter/material.dart';
import 'package:doctor_computer/services/product_image_file_picker.dart';
import 'package:doctor_computer/services/product_image_storage_service.dart';
import 'package:doctor_computer/widgets/common/app_toast.dart';

class ProductImagePicker extends StatefulWidget {
  final String productId;
  final String? initialImageUrl;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool>? onUploadingChanged;
  final bool enabled;

  const ProductImagePicker({
    super.key,
    required this.productId,
    required this.onChanged,
    this.initialImageUrl,
    this.onUploadingChanged,
    this.enabled = true,
  });

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  String? _imageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
  }

  Future<void> _pickImage() async {
    try {
      final file = await pickProductImage();
      if (file == null) return;

      setState(() => _isUploading = true);
      widget.onUploadingChanged?.call(true);
      final uploadedUrl = await ProductImageStorageService.uploadProductImage(
        file,
        widget.productId,
      );
      if (!mounted) return;
      setState(() {
        _imageUrl = uploadedUrl;
        _isUploading = false;
      });
      widget.onUploadingChanged?.call(false);
      widget.onChanged(uploadedUrl);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      widget.onUploadingChanged?.call(false);
      AppToast.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih atau mengunggah gambar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.enabled
                ? 'Foto Produk (JPG, JPEG, PNG, WEBP; maks. 10 MB). '
                      'Pilih file untuk mengunggah ke Storage, lalu tekan Simpan '
                      'agar URL foto terhubung ke produk.'
                : 'Unggah foto memerlukan koneksi. Data produk tanpa perubahan '
                      'gambar tetap dapat disimpan offline.',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageUrl == null
                  ? const Icon(Icons.image_outlined, size: 34)
                  : Image.network(
                      _imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isUploading || !widget.enabled
                        ? null
                        : _pickImage,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_isUploading ? 'Mengunggah...' : 'Pilih file'),
                  ),
                  if (_imageUrl != null)
                    TextButton.icon(
                      onPressed: _isUploading || !widget.enabled
                          ? null
                          : () {
                              setState(() => _imageUrl = null);
                              widget.onChanged(null);
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus foto'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
