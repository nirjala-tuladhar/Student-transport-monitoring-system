import 'package:flutter/material.dart';
import '../../services/parent_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/common_widgets.dart';

class EditBusStopScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final double? currentLat;
  final double? currentLng;
  final String? currentArea;
  final String? currentCity;
  final String? currentCountry;

  const EditBusStopScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.currentLat,
    this.currentLng,
    this.currentArea,
    this.currentCity,
    this.currentCountry,
  });

  @override
  State<EditBusStopScreen> createState() => _EditBusStopScreenState();
}

class _EditBusStopScreenState extends State<EditBusStopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _service = ParentService();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current values
    if (widget.currentLat != null) {
      _latController.text = widget.currentLat.toString();
    }
    if (widget.currentLng != null) {
      _lngController.text = widget.currentLng.toString();
    }
    if (widget.currentArea != null) {
      _areaController.text = widget.currentArea!;
    }
    if (widget.currentCity != null) {
      _cityController.text = widget.currentCity!;
    }
    if (widget.currentCountry != null) {
      _countryController.text = widget.currentCountry!;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());
      final area = _areaController.text.trim();
      final city = _cityController.text.trim();
      final country = _countryController.text.trim();

      // Update bus stop location
      await _service.persistHomeCoords(
        studentId: widget.studentId,
        lat: lat,
        lng: lng,
      );

      // Also update the address fields
      await _service.updateBusStopAddress(
        studentId: widget.studentId,
        area: area,
        city: city,
        country: country,
      );

      if (!mounted) return;

      setState(() {
        _success = 'Bus stop location updated successfully!';
      });

      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to update location: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_location_rounded, size: 24, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Edit Bus Stop',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: FadeInAnimation(
                child: AnimatedCard(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.studentName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Update bus stop location',
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'GPS Coordinates',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ModernTextField(
                          controller: _latController,
                          label: 'Latitude',
                          hint: 'e.g., 27.7172',
                          prefixIcon: Icons.my_location_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Latitude is required';
                            final val = double.tryParse(v);
                            if (val == null) return 'Enter a valid number';
                            if (val < -90 || val > 90) return 'Latitude must be between -90 and 90';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        ModernTextField(
                          controller: _lngController,
                          label: 'Longitude',
                          hint: 'e.g., 85.3240',
                          prefixIcon: Icons.place_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Longitude is required';
                            final val = double.tryParse(v);
                            if (val == null) return 'Enter a valid number';
                            if (val < -180 || val > 180) return 'Longitude must be between -180 and 180';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Address Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ModernTextField(
                          controller: _areaController,
                          label: 'Area',
                          hint: 'e.g., Kalimati, Balaju',
                          prefixIcon: Icons.location_on_rounded,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Area is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        ModernTextField(
                          controller: _cityController,
                          label: 'City',
                          hint: 'e.g., Kathmandu',
                          prefixIcon: Icons.location_city_rounded,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'City is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        ModernTextField(
                          controller: _countryController,
                          label: 'Country',
                          hint: 'e.g., Nepal',
                          prefixIcon: Icons.flag_rounded,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Country is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: AppTheme.error,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_success != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _success!,
                                    style: TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        AnimatedButton(
                          text: 'Update Location',
                          icon: Icons.save_rounded,
                          onPressed: _loading ? null : _submit,
                          isLoading: _loading,
                          backgroundColor: AppTheme.success,
                          width: double.infinity,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
