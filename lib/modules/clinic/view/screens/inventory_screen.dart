import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final ClinicViewModel _viewModel;
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  bool _showOnlyLowStock = false;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchInventory();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مخزن المستلزمات والكواشف الطبية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('مركز عمليات الجرد، تتبع أرقام التشغيلات (Lot No)، وتنبهات نفاذ وصلاحية المحاليل', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (ShiftGuard.checkShiftOrWarn(context)) {
                      _showAddItemDialog(context);
                    }
                  },
                  icon: const Icon(Icons.add_box_outlined, color: Colors.white),
                  label: const Text('إضافة صنف جديد +', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top 4 Metric KPI Summary Cards
            BlockBuilderWidget<ClinicCubit, ClinicApiType>(
              types: const [ClinicApiType.getInventory],
              body: (_) => _buildKpiMetricsRow(),
              loading: (_) => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
            ),
            const SizedBox(height: 20),

            // Filter & Search Toolbar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'البحث باسم الصنف، كود الباركود، أو رقم التشغيلة (Lot No)...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  selected: _showOnlyLowStock,
                  selectedColor: Colors.amber[100],
                  label: const Text('النواقص فقط ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
                  onSelected: (val) => setState(() => _showOnlyLowStock = val),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main Inventory Table
            Expanded(
              child: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
                types: const [ClinicApiType.getInventory],
                body: (_) => _buildInventoryTable(),
                loading: (_) => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiMetricsRow() {
    final list = _viewModel.clinicCubit.inventoryItems;

    double totalValuation = 0.0;
    int lowStockCount = 0;
    int expiringSoonCount = 0;
    int outOfStockCount = 0;

    final now = DateTime.now();

    for (var item in list) {
      final int qty = item['quantity'] as int? ?? 0;
      final double price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final int minThresh = item['min_threshold'] as int? ?? 10;

      totalValuation += (qty * price);

      if (qty <= minThresh) lowStockCount++;
      if (qty == 0) outOfStockCount++;

      final expStr = item['expiry_date'];
      if (expStr != null && expStr.toString().isNotEmpty) {
        final expDate = DateTime.tryParse(expStr);
        if (expDate != null) {
          final diff = expDate.difference(now).inDays;
          if (diff >= 0 && diff <= 60) expiringSoonCount++;
        }
      }
    }

    return Row(
      children: [
        Expanded(child: _buildMetricCard('إجمالي قيمة المخزون', '${totalValuation.toStringAsFixed(1)} ج.م', Icons.account_balance_wallet, AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('تنبيهات النواقص', '$lowStockCount أصناف', Icons.warning_amber_rounded, Colors.amber[800]!)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('أوشكت على الانتهاء', '$expiringSoonCount أصناف', Icons.hourglass_bottom_rounded, Colors.orange[800]!)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('منفذة / بدون رصيد', '$outOfStockCount أصناف', Icons.remove_shopping_cart, AppColors.error)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTable() {
    var list = _viewModel.clinicCubit.inventoryItems;

    // Filter Query & Toggles
    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        final name = (item['item_name'] ?? '').toString().toLowerCase();
        final barcode = (item['barcode'] ?? '').toString().toLowerCase();
        final lot = (item['lot_number'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || barcode.contains(_searchQuery) || lot.contains(_searchQuery);
      }).toList();
    }

    if (_selectedCategory != 'الكل') {
      list = list.where((item) => (item['category'] ?? '') == _selectedCategory).toList();
    }

    if (_showOnlyLowStock) {
      list = list.where((item) {
        final int qty = item['quantity'] as int? ?? 0;
        final int minThresh = item['min_threshold'] as int? ?? 10;
        return qty <= minThresh;
      }).toList();
    }

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.textLight),
              SizedBox(height: 12),
              Text('لا توجد أصناف مطابقة لنتائج البحث والجرد الحالي', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = list[index];
          final int id = item['id'] as int;
          final int qty = item['quantity'] as int? ?? 0;
          final int minThreshold = item['min_threshold'] as int? ?? 10;
          final double price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
          final bool isLowStock = qty <= minThreshold;

          final String category = item['category'] ?? 'مستلزمات عامة';
          final String lot = item['lot_number'] ?? 'LOT-2026-X';
          final String unitMeasure = item['unit_measure'] ?? 'عبوة';
          final String expiryDate = item['expiry_date'] ?? '2028-12-31';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: isLowStock ? AppColors.error.withOpacity(0.15) : AppColors.primaryLight,
              child: Icon(
                isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2,
                color: isLowStock ? AppColors.error : AppColors.primary,
              ),
            ),
            title: Row(
              children: [
                Text(item['item_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(8)),
                  child: Text(category, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                  child: Text('Lot: $lot', style: const TextStyle(color: Colors.black87, fontSize: 11)),
                ),
              ],
            ),
            subtitle: Text(
              'تاريخ الصلاحية: $expiryDate | التكلفة: $price ج.م / $unitMeasure | حد الأمان: $minThreshold',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('الرصيد: $qty $unitMeasure', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isLowStock ? AppColors.error : AppColors.textPrimary)),
                    Text('إجمالي القيمة: ${(qty * price).toStringAsFixed(1)} ج.م', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(width: 16),
                // Restock Button (+)
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  tooltip: 'إضافة توريد بكمية',
                  onPressed: () => _updateQuantityDialog(context, id, qty + 10),
                ),
                // Dispense Button (-)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.amber),
                  tooltip: 'إذن صرف كمية',
                  onPressed: () {
                    if (qty > 0) _updateQuantityDialog(context, id, qty - 1);
                  },
                ),
                // Delete Item Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'حذف الصنف',
                  onPressed: () => _confirmDeleteItem(context, id, item['item_name'] ?? ''),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateQuantityDialog(BuildContext context, int id, int newQty) async {
    await _viewModel.clinicCubit.updateInventoryItem(id, newQty);
  }

  void _confirmDeleteItem(BuildContext context, int id, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد حذف الصنف'),
        content: Text('هل أنت تأكد من رغبتك في حذف الصنف "$name" من المخزن نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await _viewModel.clinicCubit.deleteInventoryItem(id);
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('حذف الصنف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController(text: 'BAR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final lotCtrl = TextEditingController(text: 'LOT-2026-01');
    final qtyCtrl = TextEditingController(text: '50');
    final minCtrl = TextEditingController(text: '10');
    final priceCtrl = TextEditingController(text: '25.0');
    final supplierCtrl = TextEditingController();

    String selectedCategory = 'كواشف ومحاليل كيمياء';
    String storageCondition = 'درجة حرارة الغرفة 20-25°C';
    String unitMeasure = 'عبوة';
    DateTime expiryDate = DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Title matching Image 2
                  const Center(
                    child: Text(
                      'إضافة صنف جديد للمخزون (الكواشف والمستلزمات)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 1: Item Identification
                  const Text('1. بيانات الصنف والباركود:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم المستلزم / الكاشف / المحلول *', prefixIcon: Icon(Icons.inventory)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: barcodeCtrl,
                          decoration: const InputDecoration(labelText: 'كود الصنف / الباركود', prefixIcon: Icon(Icons.qr_code)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(labelText: 'التصنيف *'),
                          items: const [
                            DropdownMenuItem(value: 'كواشف ومحاليل كيمياء', child: Text('كواشف ومحاليل كيمياء')),
                            DropdownMenuItem(value: 'أدوات سحب وأنابيب', child: Text('أدوات سحب وأنابيب')),
                            DropdownMenuItem(value: 'مستهلكات وقاية وتعقيم', child: Text('مستهلكات وقاية وتعقيم')),
                            DropdownMenuItem(value: 'أدوية ومستلزمات عامة', child: Text('أدوية ومستلزمات عامة')),
                          ],
                          onChanged: (val) => setModalState(() => selectedCategory = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Batch & Expiry Tracking
                  const Text('2. رقم التشغيلة والصلاحية والجودة (Quality Control):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lotCtrl,
                          decoration: const InputDecoration(labelText: 'رقم التشغيلة / Lot No. *', prefixIcon: Icon(Icons.pin)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expiryDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) {
                              setModalState(() => expiryDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'تاريخ انتهاء الصلاحية *', prefixIcon: Icon(Icons.event_note)),
                            child: Text(DateFormat('yyyy-MM-dd').format(expiryDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: storageCondition,
                    decoration: const InputDecoration(labelText: 'شروط التخزين *'),
                    items: const [
                      DropdownMenuItem(value: 'درجة حرارة الغرفة 20-25°C', child: Text('درجة حرارة الغرفة 20-25°C')),
                      DropdownMenuItem(value: 'تبريد ثلاجة 2-8°C', child: Text('تبريد ثلاجة 2-8°C')),
                      DropdownMenuItem(value: 'تجميد فريزر -20°C', child: Text('تجميد فريزر -20°C')),
                    ],
                    onChanged: (val) => setModalState(() => storageCondition = val!),
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Stock Quantities & Pricing
                  const Text('3. الكمية، حد الأمان، واسم المورد:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'الكمية المتاحة *'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: unitMeasure,
                          decoration: const InputDecoration(labelText: 'وحدة القياس *'),
                          items: const [
                            DropdownMenuItem(value: 'عبوة', child: Text('عبوة')),
                            DropdownMenuItem(value: 'شريط', child: Text('شريط')),
                            DropdownMenuItem(value: 'اختبار/Test', child: Text('اختبار/Test')),
                            DropdownMenuItem(value: 'زجاجة', child: Text('زجاجة')),
                            DropdownMenuItem(value: 'كرتونة', child: Text('كرتونة')),
                            DropdownMenuItem(value: 'قلم', child: Text('قلم')),
                          ],
                          onChanged: (val) => setModalState(() => unitMeasure = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'حد الأمان / الإنذار *'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'سعر الشراء والتكلفة (ج.م) *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: supplierCtrl,
                    decoration: const InputDecoration(labelText: 'اسم المورد / الشركة المصنعة (اختياري)', prefixIcon: Icon(Icons.business)),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty) return;

                          await _viewModel.clinicCubit.addInventoryItem({
                            'item_name': nameCtrl.text.trim(),
                            'barcode': barcodeCtrl.text.trim(),
                            'category': selectedCategory,
                            'lot_number': lotCtrl.text.trim(),
                            'quantity': int.tryParse(qtyCtrl.text) ?? 10,
                            'min_threshold': int.tryParse(minCtrl.text) ?? 5,
                            'unit_price': double.tryParse(priceCtrl.text) ?? 10.0,
                            'expiry_date': DateFormat('yyyy-MM-dd').format(expiryDate),
                            'storage_condition': storageCondition,
                            'unit_measure': unitMeasure,
                            'supplier_name': supplierCtrl.text.trim(),
                          });

                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          _viewModel.clinicCubit.fetchInventory();
                        },
                        child: const Text('حفظ وإضافة للمخزون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
