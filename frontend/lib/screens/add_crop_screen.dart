import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AddCropScreen extends StatefulWidget {
  const AddCropScreen({super.key});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _qtyController   = TextEditingController();
  final _priceController = TextEditingController();
  final _descController  = TextEditingController();
  final _picker          = ImagePicker();

  String _selectedCrop = 'Maize';
  
  final List<String> _crops = [
    'Maize', 'Millet', 'Sorghum', 'Rice', 'Wheat',
    'Beans', 'Soya Beans', 'Groundnuts', 'Peas', 'Simsim (Sesame)',
    'Cassava', 'Sweet Potatoes', 'Irish Potatoes', 'Yams',
    'Matooke', 'Bananas (Bogoya)', 'Mangoes', 'Pineapples', 'Watermelon', 'Avocado', 'Passion Fruits',
    'Tomatoes', 'Onions', 'Cabbage', 'Dodo (Amaranth)', 'Eggplants', 'Green Pepper', 'Carrots'
  ];
  
  bool  _isLoading = false;
  List<File> _cropImages = [];  // ✅ Changed to list

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ✅ Updated to pick multiple images
  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _cropImages = pickedFiles.map((xFile) => File(xFile.path)).toList();
        });
      }
    } catch (e) {
      _showErrorDialog('Could not open gallery.\n$e');
    }
  }

  void _showImageSourceSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Add Produce Photos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 6),
            Text('Select multiple photos (up to 5 recommended).',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () { Navigator.pop(context); _pickImages(); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.green.shade600.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade600.withOpacity(0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.photo_library_rounded, color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  Text('Pick Images from Gallery',
                      style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.w600, fontSize: 16)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade600),
          const SizedBox(width: 10),
          Text('Something went wrong',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
        ]),
        content: Text(message, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, height: 1.5)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _submitCrop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final prefs       = await SharedPreferences.getInstance();
      final farmerPhone = prefs.getString('userPhone') ?? '';

      if (farmerPhone.isEmpty) {
        _showErrorDialog('Session expired. Please log out and log in again.');
        return;
      }

      // ✅ Pass the list of images
      final response = await ApiService.addProduce(
        farmerPhone,
        _selectedCrop,
        _qtyController.text.trim(),
        _priceController.text.trim(),
        _descController.text.trim(),
        imageFiles: _cropImages.isNotEmpty ? _cropImages : null,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(response['message'] ?? 'Listing added!')),
          ]),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.pop(context);
      } else {
        _showErrorDialog(response['message'] ?? 'An unknown error occurred.');
      }
    } catch (e) {
      _showErrorDialog('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    String? prefixText,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
      prefixText: prefixText,
      prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
      prefixIcon: Icon(icon, color: Colors.green.shade600),
      filled: true,
      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        title: Text('List New Produce',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50, 
                    shape: BoxShape.circle
                  ),
                  child: Icon(Icons.add_business_rounded, color: Colors.green.shade600, size: 32),
                ),
                const SizedBox(height: 24),
                Text('Crop Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                const SizedBox(height: 8),
                Text('Fill in the details of the harvest you want to sell.',
                    style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                const SizedBox(height: 32),

                // ── Multiple image picker ────────────────────────────
                Text('Produce Photos (optional, up to 5)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showImageSourceSheet,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _cropImages.isNotEmpty 
                            ? Colors.green.shade500 
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                        width: _cropImages.isNotEmpty ? 2 : 1,
                      ),
                    ),
                    child: _cropImages.isNotEmpty
                        ? Column(
                            children: [
                              SizedBox(
                                height: 180,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _cropImages.length,
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        Container(
                                          width: 180,
                                          margin: const EdgeInsets.all(4),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.file(_cropImages[index],
                                                fit: BoxFit.cover, width: 180),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8, right: 8,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _cropImages.removeAt(index);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                  color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.close_rounded,
                                                  color: Colors.white, size: 18),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _showImageSourceSheet,
                                icon: Icon(Icons.add_photo_alternate, size: 18),
                                label: Text('Add more photos'),
                                style: TextButton.styleFrom(foregroundColor: Colors.green.shade700),
                              ),
                              const SizedBox(height: 8),
                            ],
                          )
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(height: 40),
                            Icon(Icons.add_a_photo_rounded,
                                size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('Tap to add photos',
                                style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade500, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Select multiple images from gallery',
                                style: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, fontSize: 12)),
                            const SizedBox(height: 40),
                          ]),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Crop type ───────────────────────────────────
                Text('What are you selling?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCrop,
                  dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16),
                  decoration: _fieldDecoration(hint: '', icon: Icons.eco_rounded, isDark: isDark),
                  items: _crops.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedCrop = v!),
                ),
                const SizedBox(height: 24),

                // ── Quantity ────────────────────────────────────
                Text('Available Quantity (kg / bunches)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter a quantity.';
                    if ((double.tryParse(v.trim()) ?? 0) <= 0) return 'Must be greater than 0.';
                    return null;
                  },
                  decoration: _fieldDecoration(hint: 'e.g., 50', icon: Icons.scale_rounded, isDark: isDark),
                ),
                const SizedBox(height: 24),

                // ── Price ───────────────────────────────────────
                Text('Price per Unit (UGX)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter a price.';
                    if ((double.tryParse(v.trim()) ?? 0) <= 0) return 'Must be greater than 0.';
                    return null;
                  },
                  decoration: _fieldDecoration(
                    hint: 'e.g., 3000',
                    icon: Icons.payments_rounded,
                    prefixText: 'UGX ',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Description ─────────────────────────────────
                Text('Description / Caption (optional)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                  decoration: _fieldDecoration(
                    hint: 'e.g., Harvested this morning, ready for pickup in Kampala...',
                    icon: Icons.description_rounded,
                    isDark: isDark,
                  ),
                ),

                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitCrop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      disabledBackgroundColor: isDark ? Colors.green.shade900 : Colors.green.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('List Produce on Market',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}