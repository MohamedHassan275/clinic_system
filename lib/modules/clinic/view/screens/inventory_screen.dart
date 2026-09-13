import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/common/widgets/app_dialog.dart';
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
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Page Header
            if (isMobile) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مخزن المستلزمات والكواشف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('تتبع الجرد وأرقام التشغيلات (Lot No)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        if (ShiftGuard.checkShiftOrWarn(context)) {
                          _showAddItemDialog(context);
                        }
                      },
                      icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                      label: const Text('إضافة صنف جديد +', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مخزن المستلزمات والكواشف الطبية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('مركز عمليات الجرد، تتبع أرقام التشغيلات (Lot No)، وتنبيهات نفاذ وصلاحية المحاليل', style: TextStyle(color: AppColors.textSecondary)),
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
            ],
            const SizedBox(height: 16),

            // Top 4 Metric KPI Summary Cards
            BlockBuilderWidget<ClinicCubit, ClinicApiType>(
              types: const [ClinicApiType.getInventory],
              body: (_) => _buildKpiMetricsRow(isMobile),
              loading: (_) => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            ),
            const SizedBox(height: 16),

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
                const SizedBox(width: 10),
                FilterChip(
                  selected: _showOnlyLowStock,
                  selectedColor: Colors.amber[100],
                  label: const Text('النواقص ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildKpiMetricsRow(bool isMobile) {
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

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard('إجمالي قيمة المخزون', '${totalValuation.toStringAsFixed(0)} ج.م', Icons.account_balance_wallet, AppColors.primary, 150),
            const SizedBox(width: 10),
            _buildKpiCard('أصناف نفاذ أو حرجة', '$lowStockCount صنف', Icons.warning_amber_rounded, AppColors.error, 150),
            const SizedBox(width: 10),
            _buildKpiCard('تنتهي خلال 60 يوم', '$expiringSoonCount صنف', Icons.event_busy, Colors.amber[800]!, 150),
            const SizedBox(width: 10),
            _buildKpiCard('منتهية الكلية (0)', '$outOfStockCount صنف', Icons.block, Colors.grey[700]!, 150),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: _buildKpiCard('إجمالي قيمة المخزون', '${totalValuation.toStringAsFixed(0)} ج.م', Icons.account_balance_wallet, AppColors.primary, null)),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCard('أصناف حرجة / نواقص', '$lowStockCount صنف', Icons.warning_amber_rounded, AppColors.error, null)),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCard('تنتهي خلال 60 يوم', '$expiringSoonCount صنف', Icons.event_busy, Colors.amber[800]!, null)),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCard('منتهية بالكامل (0)', '$outOfStockCount صنف', Icons.block, Colors.grey[700]!, null)),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, double? width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTable() {
    var items = _viewModel.clinicCubit.inventoryItems;

    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        final name = (item['item_name'] ?? '').toString().toLowerCase();
        final barcode = (item['barcode'] ?? '').toString().toLowerCase();
        final lot = (item['lot_number'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return name.contains(q) || barcode.contains(q) || lot.contains(q);
      }).toList();
    }

    if (_showOnlyLowStock) {
      items = items.where((item) {
        final int qty = item['quantity'] as int? ?? 0;
        final int minThresh = item['min_threshold'] as int? ?? 10;
        return qty <= minThresh;
      }).toList();
    }

    if (items.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('لا توجد أصناف مطابقة حتى الآن')),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final int id = item['id'] as int;
          final int qty = item['quantity'] as int? ?? 0;
          final int minThreshold = item['min_threshold'] as int? ?? 10;
          final double price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
          final bool isLowStock = qty <= minThreshold;

          final String category = item['category'] ?? 'عام';
          final String lot = item['lot_number'] ?? 'N/A';
          final String expiryDate = item['expiry_date'] ?? 'N/A';
          final String unitMeasure = item['unit_measure'] ?? 'عبوة';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: isLowStock ? AppColors.error.withValues(alpha: 0.15) : AppColors.primaryLight,
              child: Icon(isLowStock ? Icons.warning : Icons.inventory_2, color: isLowStock ? AppColors.error : AppColors.primary, size: 20),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(item['item_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(6)),
                  child: Text(category, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            subtitle: Text(
              'Lot: $lot | الصلاحية: $expiryDate | السعر: $price ج.م',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$qty $unitMeasure', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isLowStock ? AppColors.error : AppColors.textPrimary)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 20),
                  tooltip: 'إضافة توريد بكمية',
                  onPressed: () => _updateQuantityDialog(context, id, qty + 10),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.amber, size: 20),
                  tooltip: 'إذن صرف كمية',
                  onPressed: () {
                    if (qty > 0) _updateQuantityDialog(context, id, qty - 1);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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

  void _confirmDeleteItem(BuildContext context, int id, String name) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'تأكيد حذف الصنف',
      message: 'هل أنت تأكد من رغبتك في حذف الصنف "$name" من المخزن نهائياً؟',
      confirmText: 'حذف الصنف',
      confirmColor: AppColors.error,
      icon: Icons.delete_forever,
    );

    if (confirm) {
      await _viewModel.clinicCubit.deleteInventoryItem(id);
    }
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
        builder: (ctx, setModalState) => AppDialog(
          title: 'إضافة صنف جديد للمخزون',
          subtitle: 'أدخل بيانات الصنف، رقم التشغيلة، شروط التخزين، والكميات',
          icon: Icons.inventory_2_rounded,
          iconColor: AppColors.primary,
          maxWidth: 580,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Item Identification
              const Text('1. بيانات الصنف والباركود:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم المستلزم / الكاشف *', prefixIcon: Icon(Icons.inventory)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: barcodeCtrl,
                      decoration: const InputDecoration(labelText: 'الباركود', prefixIcon: Icon(Icons.qr_code)),
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
              const Text('2. التشغيلة والجودة (Quality Control):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
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
                        decoration: const InputDecoration(labelText: 'تاريخ الصلاحية *', prefixIcon: Icon(Icons.event_note)),
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
                      decoration: const InputDecoration(labelText: 'الكمية *'),
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
                      decoration: const InputDecoration(labelText: 'حد الأمان *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'سعر التكلفة (ج.م) *'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: supplierCtrl,
                decoration: const InputDecoration(labelText: 'اسم المورد / الشركة (اختياري)', prefixIcon: Icon(Icons.business)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ),
    );
  }
}
