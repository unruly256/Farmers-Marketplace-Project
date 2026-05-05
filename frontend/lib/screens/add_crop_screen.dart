import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddCropScreen extends StatefulWidget {
  const AddCropScreen({super.key});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  
  String _selectedCrop = 'Maize';
  final List<String> _availableCrops = ['Maize', 'Beans', 'Tomatoes', 'Matooke', 'Cassava'];
  bool _isLoading = false;

  void _submitCrop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Hardcoding the phone number we used in registration for testing. 
      // Later, we will pull this dynamically from SharedPreferences!
      String testFarmerPhone = "0756534410"; 

      final response = await ApiService.addProduce(
        testFarmerPhone,
        _selectedCrop,
        _qtyController.text.trim(),
        _priceController.text.trim(),
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context); // Go back to dashboard on success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'An error occurred'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      // Catch any random UI crashes
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      // THIS GUARANTEES THE SPINNER STOPS NO MATTER WHAT
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('List New Produce', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.add_business_rounded, color: Colors.green.shade700, size: 32),
                ),
                const SizedBox(height: 24),
                
                const Text('Crop Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
                const SizedBox(height: 8),
                Text('Enter the details of the harvest you want to sell.', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 32),

                const Text('What are you selling?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCrop,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.eco_rounded, color: Colors.green.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.green.shade600, width: 2)),
                  ),
                  items: _availableCrops.map((crop) {
                    return DropdownMenuItem(value: crop, child: Text(crop, style: const TextStyle(fontWeight: FontWeight.w600)));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCrop = value!),
                ),
                
                const SizedBox(height: 24),

                const Text('Available Quantity (in kg/bunches)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Please enter a quantity' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g., 50',
                    prefixIcon: Icon(Icons.scale_rounded, color: Colors.green.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.green.shade600, width: 2)),
                  ),
                ),

                const SizedBox(height: 24),

                const Text('Price per Unit (UGX)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g., 3000',
                    prefixText: 'UGX ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    prefixIcon: Icon(Icons.payments_rounded, color: Colors.green.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.green.shade600, width: 2)),
                  ),
                ),

                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitCrop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('List Produce on Market', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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