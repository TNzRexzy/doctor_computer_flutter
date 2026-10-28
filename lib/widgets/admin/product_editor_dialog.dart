import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/product_model.dart';
import 'package:doctor_computer/widgets/common/product_image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_computer/widgets/common/app_toast.dart';

class ProductEditorDialog extends StatefulWidget {
  final ProductModel? product;

  const ProductEditorDialog({super.key, this.product});

  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _description;
  late final String _productId;
  String? _category;
  List<Map<String, String>> _categories = [];
  bool _isLoadingCategories = true;
  String? _categoryLoadError;
  String? _imageUrl;
  bool _imageWasChanged = false;
  bool _isUploadingImage = false;
  bool _isOnSale = false;
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _productId =
        product?.id ?? 'product-${DateTime.now().microsecondsSinceEpoch}';
    _name = TextEditingController(text: product?.name ?? '');
    _brand = TextEditingController(text: product?.brand ?? '');
    _price = TextEditingController(
      text: product?.price.toStringAsFixed(0) ?? '',
    );
    _stock = TextEditingController(text: product?.stock.toString() ?? '0');
    _description = TextEditingController(text: product?.description ?? '');
    _category = product?.categoryId;
    _imageUrl = product?.images.isNotEmpty == true
        ? product!.images.first
        : null;
    _isOnSale = product?.isOnSale ?? false;
    _isNew = product?.isNew ?? true;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('name');
      if (!mounted) return;

      final categories = rows
          .map(
            (row) => {
              'id': row['id']?.toString() ?? '',
              'name': row['name']?.toString() ?? '',
            },
          )
          .where((category) => category['id']!.isNotEmpty)
          .toList();

      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        if (!_categories.any((category) => category['id'] == _category)) {
          _category = _categories.isEmpty ? null : _categories.first['id'];
        }
        _categoryLoadError = _categories.isEmpty
            ? 'Belum ada kategori di database. Jalankan migration kategori produk.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
        _categoryLoadError = 'Gagal memuat kategori dari database: $error';
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _price.dispose();
    _stock.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final brand = _brand.text.trim();
    final price = double.tryParse(_price.text.trim());
    final stock = int.tryParse(_stock.text.trim());
    if (name.isEmpty ||
        brand.isEmpty ||
        price == null ||
        price <= 0 ||
        stock == null ||
        stock < 0 ||
        _category == null ||
        !_categories.any((category) => category['id'] == _category)) {
      AppToast.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Periksa nama, brand, harga, stok, dan pilih kategori yang tersedia.',
          ),
        ),
      );
      return;
    }

    final product = widget.product;
    final images = _imageWasChanged
        ? (_imageUrl == null ? <String>[] : <String>[_imageUrl!])
        : (product?.images ?? const <String>[]);
    Navigator.of(context).pop(
      ProductModel(
        id: _productId,
        name: name,
        description: _description.text.trim().isEmpty
            ? name
            : _description.text.trim(),
        descriptionId: _description.text.trim().isEmpty
            ? name
            : _description.text.trim(),
        price: price,
        originalPrice: product?.originalPrice,
        categoryId: _category!,
        brand: brand,
        images: images,
        specs: product?.specs ?? const {},
        rating: product?.rating ?? 0,
        reviewCount: product?.reviewCount ?? 0,
        stock: stock,
        isNew: _isNew,
        isOnSale: _isOnSale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null ? 'Tambah Produk' : 'Edit Produk',
        style: AppTextStyles.titleMedium,
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nama Produk',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _brand,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingCategories)
                const LinearProgressIndicator()
              else if (_categoryLoadError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _categoryLoadError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category['id'],
                          child: Text(category['name']!),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _category = value),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga (Rp)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stok',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ProductImagePicker(
                productId: _productId,
                initialImageUrl: _imageUrl,
                onChanged: (url) {
                  _imageUrl = url;
                  _imageWasChanged = true;
                },
                onUploadingChanged: (uploading) {
                  setState(() => _isUploadingImage = uploading);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Produk Baru'),
                value: _isNew,
                onChanged: (value) => setState(() => _isNew = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Flash Sale'),
                value: _isOnSale,
                onChanged: (value) => setState(() => _isOnSale = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed:
              _isLoadingCategories ||
                  _categoryLoadError != null ||
                  _isUploadingImage
              ? null
              : _save,
          child: Text(_isUploadingImage ? 'Mengunggah foto...' : 'Simpan'),
        ),
      ],
    );
  }
}
