import 'package:flutter/material.dart';
import '../../../../core/base/base_view_model.dart';
import '../data/cubit/clinic_cubit.dart';

class ClinicViewModel extends BaseViewModel {
  final ClinicCubit clinicCubit;

  ClinicViewModel(super.reLoad, this.clinicCubit);

  // Search & Text Controllers
  final TextEditingController patientSearchController = TextEditingController();
  final TextEditingController apptDateController = TextEditingController();

  // Consultation Controllers
  final TextEditingController diagnosisController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  // New Prescription Item Form
  final TextEditingController medNameController = TextEditingController();
  final TextEditingController medDosageController = TextEditingController();
  final TextEditingController medFreqController = TextEditingController();
  final TextEditingController medDurationController = TextEditingController();
  final List<Map<String, String>> prescriptionItems = [];

  void addPrescriptionItem() {
    if (medNameController.text.isEmpty) return;
    prescriptionItems.add({
      'medicine_name': medNameController.text.trim(),
      'dosage': medDosageController.text.trim(),
      'frequency': medFreqController.text.trim(),
      'duration': medDurationController.text.trim(),
    });
    medNameController.clear();
    medDosageController.clear();
    medFreqController.clear();
    medDurationController.clear();
    notifyListeners();
  }

  void removePrescriptionItem(int index) {
    if (index >= 0 && index < prescriptionItems.length) {
      prescriptionItems.removeAt(index);
      notifyListeners();
    }
  }

  void clearPrescriptionForm() {
    diagnosisController.clear();
    notesController.clear();
    prescriptionItems.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    patientSearchController.dispose();
    apptDateController.dispose();
    diagnosisController.dispose();
    notesController.dispose();
    medNameController.dispose();
    medDosageController.dispose();
    medFreqController.dispose();
    medDurationController.dispose();
    super.dispose();
  }
}
