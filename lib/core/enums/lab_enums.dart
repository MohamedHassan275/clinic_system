enum LabOrderStatus {
  pending('pending', 'قيد الانتظار'),
  inProgress('in_progress', 'قيد التنفيذ'),
  completed('completed', 'مكتمل'),
  cancelled('cancelled', 'ملغى');

  final String dbValue;
  final String displayName;

  const LabOrderStatus(this.dbValue, this.displayName);

  static LabOrderStatus fromString(String? val) {
    if (val == null || val.isEmpty) return LabOrderStatus.pending;
    final v = val.trim().toLowerCase();
    if (v == 'in_progress' || v == 'قيد التنفيذ') return LabOrderStatus.inProgress;
    if (v == 'completed' || v == 'مكتمل' || v == 'طبيعي') return LabOrderStatus.completed;
    if (v == 'cancelled' || v == 'canceled' || v == 'ملغى') return LabOrderStatus.cancelled;
    return LabOrderStatus.pending;
  }
}

enum LabOrderPriority {
  normal('normal', 'عادي'),
  urgent('urgent', 'عاجل'),
  stat('stat', 'طارئ (STAT)');

  final String dbValue;
  final String displayName;

  const LabOrderPriority(this.dbValue, this.displayName);

  static LabOrderPriority fromString(String? val) {
    if (val == null || val.isEmpty) return LabOrderPriority.normal;
    final v = val.trim().toLowerCase();
    if (v == 'urgent' || v == 'عاجل') return LabOrderPriority.urgent;
    if (v == 'stat' || v == 'طارئ') return LabOrderPriority.stat;
    return LabOrderPriority.normal;
  }
}
