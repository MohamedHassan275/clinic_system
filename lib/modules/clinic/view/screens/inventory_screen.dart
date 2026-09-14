import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/common/widgets/app_dialog.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/security/shift_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/cubit/block_builder_widget.dart';
import '../../data/cubit/clinic_cubit.dart';
import '../clinic_view_model.dart';

enum ExpiryStatus { expired, critical, warning, safe, unknown }
enum StockMovementType { inwardSupply, outwardIssue, adjustment }

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
  bool _showOnlyExpiring = false;

  List<String> get _categories {
    final dbCats = _viewModel.clinicCubit.categories.map((c) => c['name'] as String).toList();
    if (dbCats.isEmpty) {
      return [
        'الكل',
        'كواشف ومحاليل كيمياء',
        'أدوات سحب وأنابيب',
        'مستهلكات وقاية وتعقيم',
        'أدوية ومستلزمات عامة',
      ];
    }
    return ['الكل', ...dbCats];
  }

  @override
  void initState() {
    super.initState();
    _viewModel = sl<ClinicViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
    _viewModel.clinicCubit.fetchInventory();
    _viewModel.clinicCubit.fetchCategories(type: 'inventory');
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onAddItemClick() {
    final hasShift = ShiftGuard.checkShiftOrWarn(context);
    if (hasShift) {
      _showAddItemDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlockBuilderWidget<ClinicCubit, ClinicApiType>(
        types: const [ClinicApiType.getInventory, ClinicApiType.addInventoryItem, ClinicApiType.updateInventoryItem],
        loading: (_) => const Center(child: CircularProgressIndicator()),
        body: (_) => ResponsiveLayout(
          mobile: _buildMobileLayout(),
          tablet: _buildTabletLayout(),
          desktop: _buildDesktopLayout(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Desktop Layout (>= 1024px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    final rawItems = _viewModel.clinicCubit.inventoryItems;
    final filteredItems = _filterItems(rawItems);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مخزن المستلزمات والكواشف الطبية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('إدارة الجرد، تتبع أرقام التشغيلات (Lot No)، وتنبيهات نفاذ وصلاحية المحاليل', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _onAddItemClick,
                icon: const Icon(Icons.add_box_outlined, color: Colors.white),
                label: const Text('إضافة صنف جديد +', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // KPI Metrics Bar
          _buildKpiMetricsRow(isMobile: false, isTablet: false),
          const SizedBox(height: 16),

          // Toolbar (Search & Filters)
          _buildDesktopToolbar(),
          const SizedBox(height: 16),

          // Main Inventory Data Table
          Expanded(
            child: _buildDesktopDataTable(filteredItems),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Tablet Layout (600px - 1023px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletLayout() {
    final rawItems = _viewModel.clinicCubit.inventoryItems;
    final filteredItems = _filterItems(rawItems);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إدارة المخزن والجرد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('تتبع الأصناف والصلاحيات', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _onAddItemClick,
                icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 18),
                label: const Text('صنف جديد +', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // KPI Summary Row
          _buildKpiMetricsRow(isMobile: false, isTablet: true),
          const SizedBox(height: 12),

          // Filter Toolbar
          _buildTabletToolbar(),
          const SizedBox(height: 12),

          // Items Grid View (2 Columns)
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) => _buildTabletItemCard(filteredItems[index]),
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Mobile Layout (< 600px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    final rawItems = _viewModel.clinicCubit.inventoryItems;
    final filteredItems = _filterItems(rawItems);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مخزن المستلزمات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              const Text('الجرد وأرقام التشغيلات (Lot No)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _onAddItemClick,
                  icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 18),
                  label: const Text('إضافة صنف جديد +', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // KPI Horizontal Scroll
          _buildKpiMetricsRow(isMobile: true, isTablet: false),
          const SizedBox(height: 10),

          // Mobile Toolbar
          _buildMobileToolbar(),
          const SizedBox(height: 10),

          // Mobile Item List
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    itemCount: filteredItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildMobileItemCard(filteredItems[index]),
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KPI Metrics Section
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildKpiMetricsRow({required bool isMobile, required bool isTablet}) {
    final list = _viewModel.clinicCubit.inventoryItems;

    double totalValuation = 0.0;
    int lowStockCount = 0;
    int expiringSoonCount = 0;
    int outOfStockCount = 0;

    for (var item in list) {
      final int qty = item['quantity'] as int? ?? 0;
      final double price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final int minThresh = item['min_threshold'] as int? ?? 10;

      totalValuation += (qty * price);

      if (qty <= minThresh) lowStockCount++;
      if (qty == 0) outOfStockCount++;

      final expStatus = _calculateExpiryStatus(item['expiry_date']);
      if (expStatus == ExpiryStatus.critical || expStatus == ExpiryStatus.warning || expStatus == ExpiryStatus.expired) {
        expiringSoonCount++;
      }
    }

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard('قيمة المخزون', '${totalValuation.toStringAsFixed(0)} ج.م', Icons.account_balance_wallet, AppColors.primary, 140),
            const SizedBox(width: 8),
            _buildKpiCard('نواقص حرجة', '$lowStockCount صنف', Icons.warning_amber_rounded, AppColors.error, 130),
            const SizedBox(width: 8),
            _buildKpiCard('تنتهي قريباً', '$expiringSoonCount صنف', Icons.event_busy, Colors.amber[800]!, 130),
            const SizedBox(width: 8),
            _buildKpiCard('منتهية (0)', '$outOfStockCount صنف', Icons.block, Colors.grey[700]!, 120),
          ],
        ),
      );
    }

    if (isTablet) {
      return Row(
        children: [
          Expanded(child: _buildKpiCard('قيمة المخزون', '${totalValuation.toStringAsFixed(0)} ج.م', Icons.account_balance_wallet, AppColors.primary, null)),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('نواقص / حرج', '$lowStockCount صنف', Icons.warning_amber_rounded, AppColors.error, null)),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('تنتهي قريباً', '$expiringSoonCount صنف', Icons.event_busy, Colors.amber[800]!, null)),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('منتهية (0)', '$outOfStockCount صنف', Icons.block, Colors.grey[700]!, null)),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Toolbars
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopToolbar() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'البحث باسم الصنف، الباركود، رقم التشغيلة (Lot No)، أو المورد...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              icon: const Icon(Icons.category, color: AppColors.primary, size: 18),
              items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilterChip(
          selected: _showOnlyLowStock,
          selectedColor: Colors.red[100],
          checkmarkColor: AppColors.error,
          label: const Text('النواقص ⚠️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onSelected: (val) => setState(() => _showOnlyLowStock = val),
        ),
        const SizedBox(width: 8),
        FilterChip(
          selected: _showOnlyExpiring,
          selectedColor: Colors.amber[100],
          checkmarkColor: Colors.amber[900],
          label: const Text('تنتهي قريباً ⏳', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onSelected: (val) => setState(() => _showOnlyExpiring = val),
        ),
      ],
    );
  }

  Widget _buildTabletToolbar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'بحث باسم الصنف أو Lot No...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            FilterChip(
              selected: _showOnlyLowStock,
              selectedColor: Colors.red[100],
              label: const Text('النواقص ⚠️', style: TextStyle(fontSize: 11)),
              onSelected: (val) => setState(() => _showOnlyLowStock = val),
            ),
            const SizedBox(width: 6),
            FilterChip(
              selected: _showOnlyExpiring,
              selectedColor: Colors.amber[100],
              label: const Text('تنتهي قريباً ⏳', style: TextStyle(fontSize: 11)),
              onSelected: (val) => setState(() => _showOnlyExpiring = val),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileToolbar() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'بحث باسم الصنف، الباركود، أو Lot No...',
            prefixIcon: const Icon(Icons.search, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                selected: _selectedCategory == 'الكل',
                label: const Text('الكل', style: TextStyle(fontSize: 11)),
                onSelected: (_) => setState(() => _selectedCategory = 'الكل'),
              ),
              const SizedBox(width: 4),
              FilterChip(
                selected: _showOnlyLowStock,
                selectedColor: Colors.red[100],
                label: const Text('النواقص ⚠️', style: TextStyle(fontSize: 11)),
                onSelected: (val) => setState(() => _showOnlyLowStock = val),
              ),
              const SizedBox(width: 4),
              FilterChip(
                selected: _showOnlyExpiring,
                selectedColor: Colors.amber[100],
                label: const Text('الصلاحية ⏳', style: TextStyle(fontSize: 11)),
                onSelected: (val) => setState(() => _showOnlyExpiring = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Desktop Data Table
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopDataTable(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _buildEmptyState();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.primaryLight.withValues(alpha: 0.5)),
            columnSpacing: 16,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('الصنف والباركود', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('التصنيف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('التشغيلة (Lot)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('تاريخ الصلاحية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('الكمية المتاحة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('السعر والقيمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
            rows: items.map((item) {
              final int id = item['id'] as int;
              final int qty = item['quantity'] as int? ?? 0;
              final int minThresh = item['min_threshold'] as int? ?? 10;
              final double unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
              final double valuation = qty * unitPrice;

              final String name = item['item_name'] ?? 'بدون اسم';
              final String category = item['category'] ?? 'عام';
              final String lot = item['lot_number'] ?? 'N/A';
              final String expiryDate = item['expiry_date'] ?? 'N/A';
              final String unitMeasure = item['unit_measure'] ?? 'عبوة';
              final String barcode = item['barcode'] ?? '';

              final isLowStock = qty <= minThresh;
              final expStatus = _calculateExpiryStatus(expiryDate);

              return DataRow(
                cells: [
                  // 1. Item Name & Barcode
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isLowStock ? AppColors.error.withValues(alpha: 0.15) : AppColors.primaryLight,
                          child: Icon(isLowStock ? Icons.warning : Icons.inventory_2, color: isLowStock ? AppColors.error : AppColors.primary, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (barcode.isNotEmpty)
                              Text('كود: $barcode', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 2. Category
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(6)),
                      child: Text(category, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  // 3. Lot Number
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(6)),
                      child: Text('LOT: $lot', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    ),
                  ),
                  // 4. Expiry Date & Status Badge
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(expiryDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        _buildExpiryBadge(expStatus),
                      ],
                    ),
                  ),
                  // 5. Quantity & Threshold
                  DataCell(
                    Row(
                      children: [
                        Text('$qty $unitMeasure', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isLowStock ? AppColors.error : AppColors.textPrimary)),
                        const SizedBox(width: 6),
                        if (isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                            child: const Text('نفاذ وشيك', style: TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  // 6. Unit Price & Valuation
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${unitPrice.toStringAsFixed(1)} ج.م/وحدة', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('${valuation.toStringAsFixed(0)} ج.م', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  // 7. Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 20),
                          tooltip: 'إذن توريد كمية (+)',
                          onPressed: () => _showStockAdjustmentDialog(context, item, StockMovementType.inwardSupply),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.amber, size: 20),
                          tooltip: 'إذن صرف كمية (-)',
                          onPressed: () => _showStockAdjustmentDialog(context, item, StockMovementType.outwardIssue),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: 'حذف الصنف',
                          onPressed: () => _confirmDeleteItem(context, id, name),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Tablet Item Card
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletItemCard(Map<String, dynamic> item) {
    final int id = item['id'] as int;
    final int qty = item['quantity'] as int? ?? 0;
    final int minThresh = item['min_threshold'] as int? ?? 10;
    final double price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
    final String name = item['item_name'] ?? '';
    final String lot = item['lot_number'] ?? 'N/A';
    final String expiry = item['expiry_date'] ?? 'N/A';
    final String unit = item['unit_measure'] ?? 'عبوة';
    final isLowStock = qty <= minThresh;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLowStock ? AppColors.error.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
              ),
              if (isLowStock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                  child: const Text('نواقص', style: TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Lot: $lot | expiry: $expiry', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$qty $unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isLowStock ? AppColors.error : AppColors.textPrimary)),
                  Text('${price.toStringAsFixed(1)} ج.م', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 22),
                    onPressed: () => _showStockAdjustmentDialog(context, item, StockMovementType.inwardSupply),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.amber, size: 22),
                    onPressed: () => _showStockAdjustmentDialog(context, item, StockMovementType.outwardIssue),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _confirmDeleteItem(context, id, name),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Mobile Item Card
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileItemCard(Map<String, dynamic> item) {
    final int id = item['id'] as int;
    final int qty = item['quantity'] as int? ?? 0;
    final int minThresh = item['min_threshold'] as int? ?? 10;
    final double price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
    final String name = item['item_name'] ?? '';
    final String lot = item['lot_number'] ?? 'N/A';
    final String expiry = item['expiry_date'] ?? 'N/A';
    final String unit = item['unit_measure'] ?? 'عبوة';
    final isLowStock = qty <= minThresh;
    final expStatus = _calculateExpiryStatus(expiry);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: isLowStock ? AppColors.error : AppColors.primary, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
                _buildExpiryBadge(expStatus),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('LOT: $lot', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(width: 8),
                Text('صلاحية: $expiry', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('الرصيد: ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('$qty $unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isLowStock ? AppColors.error : AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Text('(${price.toStringAsFixed(1)} ج.م)', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _showStockAdjustmentDialog(context, item, StockMovementType.inwardSupply),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                        child: const Text('+ توريد', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showStockAdjustmentDialog(context, item, StockMovementType.outwardIssue),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(6)),
                        child: Text('- صرف', style: TextStyle(color: Colors.amber[900], fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      onPressed: () => _confirmDeleteItem(context, id, name),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Widgets & Dialogs
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text('لا توجد أصناف مطابقة لفلترة البحث حتى الآن', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryBadge(ExpiryStatus status) {
    switch (status) {
      case ExpiryStatus.expired:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
          child: const Text('منتهي ⛔', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
        );
      case ExpiryStatus.critical:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
          child: Text('تنتهي خلال 30 يوم ⚠️', style: TextStyle(color: Colors.orange[900], fontSize: 10, fontWeight: FontWeight.bold)),
        );
      case ExpiryStatus.warning:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(4)),
          child: Text('تنتهي خلال 60 يوم ⏳', style: TextStyle(color: Colors.amber[900], fontSize: 10, fontWeight: FontWeight.bold)),
        );
      case ExpiryStatus.safe:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
          child: Text('صالح 🍏', style: TextStyle(color: Colors.green[800], fontSize: 10, fontWeight: FontWeight.bold)),
        );
      case ExpiryStatus.unknown:
        return const SizedBox.shrink();
    }
  }

  ExpiryStatus _calculateExpiryStatus(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return ExpiryStatus.unknown;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return ExpiryStatus.unknown;
    final diff = date.difference(DateTime.now()).inDays;
    if (diff < 0) return ExpiryStatus.expired;
    if (diff <= 30) return ExpiryStatus.critical;
    if (diff <= 60) return ExpiryStatus.warning;
    return ExpiryStatus.safe;
  }

  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items) {
    return items.where((item) {
      if (_selectedCategory != 'الكل') {
        final cat = (item['category'] ?? '').toString();
        if (cat != _selectedCategory) return false;
      }

      final int qty = item['quantity'] as int? ?? 0;
      final int minThresh = item['min_threshold'] as int? ?? 10;

      if (_showOnlyLowStock && qty > minThresh) {
        return false;
      }

      if (_showOnlyExpiring) {
        final status = _calculateExpiryStatus(item['expiry_date']);
        if (status != ExpiryStatus.critical && status != ExpiryStatus.warning && status != ExpiryStatus.expired) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (item['item_name'] ?? '').toString().toLowerCase();
        final barcode = (item['barcode'] ?? '').toString().toLowerCase();
        final lot = (item['lot_number'] ?? '').toString().toLowerCase();
        final supplier = (item['supplier_name'] ?? '').toString().toLowerCase();
        return name.contains(q) || barcode.contains(q) || lot.contains(q) || supplier.contains(q);
      }

      return true;
    }).toList();
  }

  void _showStockAdjustmentDialog(BuildContext context, Map<String, dynamic> item, StockMovementType type) {
    final int id = item['id'] as int;
    final int currentQty = item['quantity'] as int? ?? 0;
    final String name = item['item_name'] ?? '';
    final qtyCtrl = TextEditingController(text: '10');
    final noteCtrl = TextEditingController();

    final isSupply = type == StockMovementType.inwardSupply;

    showDialog(
      context: context,
      builder: (dialogCtx) => AppDialog(
        title: isSupply ? 'إذن توريد كمية جديدة (+)' : 'إذن صرف / استهلاك كمية (-)',
        subtitle: 'الصنف: $name | الرصيد الحالي: $currentQty',
        icon: isSupply ? Icons.add_circle : Icons.remove_circle,
        iconColor: isSupply ? AppColors.primary : Colors.amber[900]!,
        maxWidth: 450,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isSupply ? 'الكمية الموردة *' : 'الكمية المصروفة *',
                prefixIcon: const Icon(Icons.pin),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: isSupply ? 'رقم فاتورة المورد / ملاحظات' : 'القسم / سبب الصرف',
                prefixIcon: const Icon(Icons.note),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isSupply ? AppColors.primary : Colors.amber[900]),
            onPressed: () async {
              final changeQty = int.tryParse(qtyCtrl.text) ?? 0;
              if (changeQty <= 0) return;

              final newQty = isSupply ? (currentQty + changeQty) : (currentQty - changeQty).clamp(0, 999999);
              await _viewModel.clinicCubit.updateInventoryItem(id, newQty);

              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            },
            child: Text(isSupply ? 'حفظ التوريد' : 'حفظ الصرف', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
