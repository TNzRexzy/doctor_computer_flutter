import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/theme/app_text_styles.dart';
import 'package:doctor_computer/data/models/order_model.dart';
import 'package:doctor_computer/providers/order_provider.dart';
import 'package:doctor_computer/providers/auth_provider.dart';
import 'package:doctor_computer/services/pos_local_database_helper.dart';
import 'package:doctor_computer/services/pos_sync_service.dart';

/// Quick-fill suggestions for the courier field.
const List<String> _kCourierSuggestions = [
  'JNE',
  'J&T Express',
  'SiCepat',
  'AnterAja',
  'Pos Indonesia',
  'Ninja Xpress',
  'GoSend',
  'Grab Express',
];

/// Shows the "Update Pesanan" dialog (status + courier + resi) for an order map
/// coming from the `orders` table. Used by both the admin and cashier dashboards.
///
/// Returns a map with the fields that were actually saved
/// (`status`, `tracking_number`, `courier`), or `null`/empty when nothing changed,
/// so the caller can refresh its local list.
Future<Map<String, dynamic>?> showOrderUpdateDialog(
  BuildContext context,
  Map<String, dynamic> order,
) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OrderUpdateDialog(order: order),
  );
}

class _OrderUpdateDialog extends StatefulWidget {
  final Map<String, dynamic> order;

  const _OrderUpdateDialog({required this.order});

  @override
  State<_OrderUpdateDialog> createState() => _OrderUpdateDialogState();
}

class _OrderUpdateDialogState extends State<_OrderUpdateDialog> {
  late String _selectedStatus;
  late String _savedStatus;
  late String _savedCourier;
  late String _savedResi;
  late final TextEditingController _courierCtrl;
  late final TextEditingController _resiCtrl;

  final Map<String, dynamic> _result = {};
  bool _isSubmitting = false;
  String? _resiError;
  String? _submitError;

  String get _orderId => widget.order['id']?.toString() ?? '';

  bool get _isPos =>
      (widget.order['channel']?.toString().toLowerCase() ?? 'online') == 'pos';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order['status']?.toString() ?? 'processing';
    _savedStatus = _selectedStatus;
    _savedCourier = widget.order['courier']?.toString() ?? '';
    _savedResi = widget.order['tracking_number']?.toString() ?? '';
    _courierCtrl = TextEditingController(text: _savedCourier);
    _resiCtrl = TextEditingController(text: _savedResi);
  }

  @override
  void dispose() {
    _courierCtrl.dispose();
    _resiCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final provider = context.read<OrderProvider>();
    final syncService = context.read<PosSyncService>();
    final isOfflineSession = context.read<AuthProvider>().isOfflineSession;
    final nav = Navigator.of(context);
    final hasNetwork = await syncService.hasNetworkConnection();
    final queueOffline = isOfflineSession || !hasNetwork;
    final resi = _resiCtrl.text.trim();
    final courier = _courierCtrl.text.trim();

    if (!_isPos && _selectedStatus == 'shipped' && resi.isEmpty) {
      setState(() => _resiError = 'Nomor resi wajib diisi saat status SHIPPED');
      return;
    }

    setState(() {
      _resiError = null;
      _submitError = null;
      _isSubmitting = true;
    });

    // 1. Save courier + resi first (so a "shipped" order always has its resi).
    if (!_isPos &&
        resi.isNotEmpty &&
        (resi != _savedResi || courier != _savedCourier)) {
      final ok = queueOffline
          ? await _queueOrderChange(
              operation: 'order_tracking',
              payload: {
                ...widget.order,
                'courier': courier,
                'tracking_number': resi,
              },
            )
          : await provider.updateOrderTracking(
              _orderId,
              courier: courier,
              trackingNumber: resi,
            );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _isSubmitting = false;
          _submitError = provider.errorMessage ?? 'Nomor resi gagal disimpan.';
        });
        return;
      }
      _savedResi = resi;
      _result['tracking_number'] = resi;
      if (courier.isNotEmpty) {
        _savedCourier = courier;
        _result['courier'] = courier;
      }
    }

    // 2. Save the status if it changed.
    if (_selectedStatus != _savedStatus) {
      OrderStatus newStatus = OrderStatus.processing;
      for (final s in OrderStatus.values) {
        if (s.name.toLowerCase() == _selectedStatus.toLowerCase()) {
          newStatus = s;
          break;
        }
      }
      final ok = queueOffline
          ? await _queueOrderChange(
              operation: 'order_status',
              payload: {...widget.order, ..._result, 'status': _selectedStatus},
            )
          : await provider.updateOrderStatus(_orderId, newStatus);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _isSubmitting = false;
          _submitError =
              provider.errorMessage ?? 'Status pesanan gagal diperbarui.';
        });
        return;
      }
      _savedStatus = _selectedStatus;
      _result['status'] = _selectedStatus;
    }

    nav.pop(_result);
  }

  Future<bool> _queueOrderChange({
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final syncService = context.read<PosSyncService>();
    try {
      await PosLocalDatabaseHelper.instance.queueAdminChange(
        entity: 'orders',
        operation: operation,
        recordId: _orderId,
        payload: payload,
      );
      syncService.scheduleSync();
      return true;
    } catch (error) {
      setState(() {
        _isSubmitting = false;
        _submitError = 'Perubahan pesanan gagal disimpan lokal: $error';
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update Pesanan', style: AppTextStyles.titleMedium),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: $_orderId', style: AppTextStyles.bodySmall),
            const SizedBox(height: 12),
            ...['processing', 'shipped', 'delivered', 'cancelled'].map(
              (status) => RadioListTile<String>(
                value: status,
                groupValue: _selectedStatus,
                title: Text(status.toUpperCase()),
                activeColor: AppColors.primary,
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                        }
                      },
              ),
            ),
            if (!_isPos) ...[
              const Divider(height: 24),
              Text(
                'Pengiriman',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _courierCtrl,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Kurir / Ekspedisi',
                  hintText: 'Misal: JNE Reguler',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: _kCourierSuggestions
                    .map(
                      (c) => ActionChip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _courierCtrl.text = c),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _resiCtrl,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.characters,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: _selectedStatus == 'shipped'
                      ? 'Nomor Resi *'
                      : 'Nomor Resi',
                  hintText: 'Masukkan nomor resi pengiriman',
                  prefixIcon: const Icon(Icons.local_shipping_outlined),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                  errorText: _resiError,
                ),
                onChanged: (_) {
                  if (_resiError != null) setState(() => _resiError = null);
                },
              ),
            ],
            if (_submitError != null) ...[
              const SizedBox(height: 10),
              Text(
                _submitError!,
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.pop(context, _result),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Menyimpan...' : 'Update'),
        ),
      ],
    );
  }
}
