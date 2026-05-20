import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoadingProfile = true;
  bool _isSavingData = false;
  bool _isUploadingPhoto = false;
  bool _isDetectingLocation = false;

  String _userRole = 'Farmer';
  String _themeMode = 'system';
  String? _profileUrl;
  String? _locationStatus;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
    _loadProfile().then((_) => _detectCurrentLocationSilently());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _hasValidProfileUrl {
    final url = _profileUrl?.trim() ?? '';
    return url.isNotEmpty && url.toLowerCase() != 'null';
  }

  Future<void> _recoverLostImage() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return;

      final XFile? recoveredFile = response.file;
      if (recoveredFile == null) return;

      final File? croppedFile = await _cropImage(recoveredFile.path);
      if (croppedFile == null) return;

      final phone = _phoneController.text.trim();
      if (phone.isEmpty) return;

      if (mounted) {
        setState(() => _isUploadingPhoto = true);
      }

      final res = await ApiService.uploadProfilePicture(phone, croppedFile);

      if (!mounted) return;

      if (res['status'] == 'success') {
        final dynamic data = res['data'];
        if (data is Map) {
          final newUrl = data['profile_url']?.toString().trim();
          if (newUrl != null &&
              newUrl.isNotEmpty &&
              newUrl.toLowerCase() != 'null') {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userProfileUrl', newUrl);
            setState(() => _profileUrl = newUrl);
          }
        }

        await _loadProfile();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone') ?? '';

      if (mounted) {
        setState(() {
          _nameController.text = prefs.getString('userName') ?? '';
          _phoneController.text = phone;
          _locationController.text = prefs.getString('userLocation') ?? '';
          _userRole = prefs.getString('userRole') ?? 'Farmer';
          _themeMode = prefs.getString('themeMode') ?? 'system';

          final savedProfileUrl = prefs.getString('userProfileUrl') ?? '';
          if (savedProfileUrl.trim().isNotEmpty &&
              savedProfileUrl.trim().toLowerCase() != 'null') {
            _profileUrl = savedProfileUrl;
          }
        });
      }

      if (phone.isNotEmpty) {
        final res = await ApiService.fetchUserProfile(phone);

        if (res['status'] == 'success' && res['data'] is Map) {
          final data = res['data'] as Map;

          final freshName = data['full_name']?.toString().trim() ?? '';
          final freshLocation = data['location']?.toString().trim() ?? '';
          final freshRole = data['role']?.toString().trim() ?? '';
          final freshProfileUrl = data['profile_url']?.toString().trim() ?? '';

          if (freshName.isNotEmpty) {
            await prefs.setString('userName', freshName);
          }
          if (freshLocation.isNotEmpty) {
            await prefs.setString('userLocation', freshLocation);
          }
          if (freshRole.isNotEmpty) {
            await prefs.setString('userRole', freshRole);
          }
          if (freshProfileUrl.isNotEmpty &&
              freshProfileUrl.toLowerCase() != 'null') {
            await prefs.setString('userProfileUrl', freshProfileUrl);
          }

          if (mounted) {
            setState(() {
              if (freshName.isNotEmpty) {
                _nameController.text = freshName;
              }
              if (freshLocation.isNotEmpty) {
                _locationController.text = freshLocation;
              }
              if (freshRole.isNotEmpty) {
                _userRole = freshRole;
              }
              if (freshProfileUrl.isNotEmpty &&
                  freshProfileUrl.toLowerCase() != 'null') {
                _profileUrl = freshProfileUrl;
              }
            });
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not load profile right now.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _detectCurrentLocationSilently() async {
    if (_isDetectingLocation) return;

    try {
      if (mounted) {
        setState(() {
          _isDetectingLocation = true;
          _locationStatus = 'Refreshing current location...';
        });
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationStatus = 'Location services are turned off.';
            _isDetectingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationStatus = 'Location access not granted.';
            _isDetectingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String resolvedLocation = _locationController.text.trim().isEmpty
          ? 'Unknown location'
          : _locationController.text.trim();

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          if ((p.administrativeArea ?? '').trim().isNotEmpty)
            p.administrativeArea!.trim(),
        ];

        if (parts.isNotEmpty) {
          resolvedLocation = parts.join(', ');
        } else if ((p.country ?? '').trim().isNotEmpty) {
          resolvedLocation = p.country!.trim();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userLocation', resolvedLocation);

      if (mounted) {
        setState(() {
          _locationController.text = resolvedLocation;
          _locationStatus = 'Location synced automatically.';
          _isDetectingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationStatus = 'Could not refresh location.';
          _isDetectingLocation = false;
        });
      }
    }
  }

  Future<File?> _cropImage(String path) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        maxWidth: 900,
        maxHeight: 900,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: Colors.green.shade700,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: Colors.green.shade700,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (cropped == null) return null;
      return File(cropped.path);
    } catch (_) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open image cropper.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }
  }

  Future<bool> _showPermissionExplainer(ImageSource source) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = source == ImageSource.camera
        ? 'Camera permission'
        : 'Gallery permission';

    final message = source == ImageSource.camera
        ? 'SAMS Market needs your permission to open the camera so you can take and upload a new profile photo.'
        : 'SAMS Market needs your permission to open your photo library so you can choose and upload a new profile photo.';

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111B15),
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Not now',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isUploadingPhoto) return;

    final consent = await _showPermissionExplainer(source);
    if (!consent) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1400,
      );

      if (picked == null) return;

      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Phone number not found for this account.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final File? croppedFile = await _cropImage(picked.path);
      if (croppedFile == null) return;

      if (mounted) {
        setState(() => _isUploadingPhoto = true);
      }

      final res = await ApiService.uploadProfilePicture(phone, croppedFile);

      if (!mounted) return;

      if (res['status'] == 'success') {
        final dynamic data = res['data'];
        if (data is Map) {
          final newUrl = data['profile_url']?.toString().trim();
          if (newUrl != null &&
              newUrl.isNotEmpty &&
              newUrl.toLowerCase() != 'null') {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userProfileUrl', newUrl);

            setState(() {
              _profileUrl = newUrl;
            });
          }
        }

        await _loadProfile();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Profile photo updated!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to upload photo.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image upload failed. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showImageSourceSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Update Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111B15),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose an image source. You will be asked for permission before the app opens your camera or gallery.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _sourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: Colors.green.shade700,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _sourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: Colors.orange.shade600,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmationSheet() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color sheetColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF111B15);
    final Color subColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color mutedButtonBg =
        isDark ? const Color(0xFF232323) : const Color(0xFFF4F6F5);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.32 : 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.orange.shade600.withOpacity(0.12)
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.orange.shade600,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign out of your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You will need to log in again to continue using SAMS Market.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Stay Signed In',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleLogout();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: mutedButtonBg,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    try {
      setState(() => _isSavingData = true);

      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone') ?? '';
      final newName = _nameController.text.trim();
      final newLocation = _locationController.text.trim();

      await prefs.setString('userName', newName);
      await prefs.setString('userLocation', newLocation);

      if (phone.isNotEmpty) {
        final res = await ApiService.updateUserProfile(
          phone,
          newName,
          newLocation,
        );

        if (!mounted) return;

        if (res['status'] != 'success') {
          setState(() => _isSavingData = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to update profile.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      if (mounted) {
        setState(() => _isSavingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Profile updated globally!')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSavingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save profile changes.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _setThemeMode(String mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode);

    if (mode == 'dark') {
      themeNotifier.value = ThemeMode.dark;
    } else if (mode == 'light') {
      themeNotifier.value = ThemeMode.light;
    } else {
      themeNotifier.value = ThemeMode.system;
    }
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool readOnly = false,
    String? hintText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF111B15),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111B15),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(icon, color: Colors.green.shade700),
              filled: true,
              fillColor: readOnly
                  ? (isDark ? const Color(0xFF171717) : Colors.grey.shade100)
                  : (isDark ? const Color(0xFF232323) : Colors.grey.shade50),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.green.shade700,
                  width: 1.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeOption(
    String mode,
    IconData icon,
    String label,
    bool isDark,
  ) {
    final isSelected = _themeMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => _setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.shade700 : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.green.shade700
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05)),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.green.shade700.withOpacity(
                        isDark ? 0.24 : 0.14,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                size: 21,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.28)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF111B15),
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232323) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF111B15),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.green.shade700.withOpacity(0.85),
            Colors.orange.shade600.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CircleAvatar(
        radius: 46,
        backgroundColor: isDark ? const Color(0xFF151515) : Colors.white,
        child: ClipOval(
          child: SizedBox(
            width: 92,
            height: 92,
            child: _isUploadingPhoto
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.green.shade700,
                      strokeWidth: 3,
                    ),
                  )
                : _hasValidProfileUrl
                    ? Image.network(
                        _profileUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Icon(
                            Icons.person_rounded,
                            size: 44,
                            color: Colors.green.shade700,
                          );
                        },
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 44,
                        color: Colors.green.shade700,
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFarmer = _userRole.toLowerCase() == 'farmer';
    final roleColor =
        isFarmer ? Colors.green.shade700 : Colors.orange.shade600;
    final roleBg =
        isDark ? roleColor.withOpacity(0.16) : roleColor.withOpacity(0.10);

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF1A1A1A),
                      const Color(0xFF202522),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF4F9F5),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.30)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _isUploadingPhoto ? null : _showImageSourceSheet,
                child: Stack(
                  children: [
                    _buildProfileAvatar(isDark),
                    if (!_isUploadingPhoto)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _nameController.text.trim().isEmpty
                    ? 'SAMS Market User'
                    : _nameController.text.trim(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111B15),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: roleBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: roleColor.withOpacity(0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: roleColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Verified $_userRole',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_phoneController.text.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _phoneController.text.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _locationController.text.trim().isEmpty
                          ? 'Location not set'
                          : _locationController.text.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(color: Colors.green.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF121212) : const Color(0xFFF7FAF8);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: scaffoldBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Text(
          'My Profile',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111B15),
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.35,
          ),
        ),
      ),
      body: _isLoadingProfile
          ? _buildLoading()
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadProfile,
                color: Colors.green.shade700,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            _buildHeroHeader(),
                            const SizedBox(height: 22),
                            _buildSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(
                                    'Account Details',
                                    'Update your public farmer information and contact details.',
                                  ),
                                  _buildEditField(
                                    'Display Name',
                                    Icons.badge_outlined,
                                    _nameController,
                                  ),
                                  _buildEditField(
                                    'Phone Number',
                                    Icons.phone_outlined,
                                    _phoneController,
                                    readOnly: true,
                                  ),
                                  _buildEditField(
                                    'Location / District',
                                    Icons.location_on_outlined,
                                    _locationController,
                                  ),
                                  if (_locationStatus != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _locationStatus!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isSavingData ? null : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 17,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: _isSavingData
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.8,
                                              ),
                                            )
                                          : const Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(
                                    'Appearance',
                                    'Choose how SAMS Market looks across the app.',
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF161616)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Row(
                                      children: [
                                        _themeOption(
                                          'system',
                                          Icons.brightness_auto_rounded,
                                          'System',
                                          isDark,
                                        ),
                                        const SizedBox(width: 6),
                                        _themeOption(
                                          'light',
                                          Icons.wb_sunny_rounded,
                                          'Light',
                                          isDark,
                                        ),
                                        const SizedBox(width: 6),
                                        _themeOption(
                                          'dark',
                                          Icons.nightlight_round,
                                          'Dark',
                                          isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(
                                    'Support & Info',
                                    'Helpful resources and product information.',
                                  ),
                                  _buildSupportTile(
                                    icon: Icons.support_agent_rounded,
                                    color: Colors.orange.shade600,
                                    title: 'Help & Support',
                                    subtitle:
                                        'Get assistance with your account and marketplace activity.',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSupportTile(
                                    icon: Icons.info_outline_rounded,
                                    color: Colors.blue.shade600,
                                    title: 'About SAMS Market',
                                    subtitle: 'Developed by GROUP 5.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(
                                    'Session',
                                    'Manage your current account access securely.',
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton.icon(
                                      onPressed: _showLogoutConfirmationSheet,
                                      icon: Icon(
                                        Icons.logout_rounded,
                                        color: Colors.red.shade600,
                                      ),
                                      label: Text(
                                        'Sign Out',
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        backgroundColor: isDark
                                            ? Colors.red.withOpacity(0.1)
                                            : Colors.red.shade50,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}