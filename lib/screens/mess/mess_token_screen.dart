import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/mess_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/mess_token_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessTokenScreen extends StatefulWidget {
  @override
  _MessTokenScreenState createState() => _MessTokenScreenState();
}

class _MessTokenScreenState extends State<MessTokenScreen> {
  MessTokenModel? _currentToken;
  bool _isLoading = true;
  String? _noTokenReason;
  
  // Meal preferences
  Set<String> _selectedMeals = {};
  List<String> _availableMeals = [];
  bool _savingPreferences = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _loadMealPreferences();
  }

  Future<void> _loadToken() async {
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messProvider = Provider.of<MessProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      final userId = authProvider.user!.uid!;
      await messProvider.loadCurrentToken(userId);
      String? reason;
      if (messProvider.currentToken == null) {
        reason = await _resolveNoTokenReason(userId);
      }
      setState(() {
        _currentToken = messProvider.currentToken;
        _noTokenReason = reason;
        _isLoading = false;
      });
    } else {
      setState(() {
        _currentToken = null;
        _noTokenReason = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMealPreferences() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;
      
      final studentId = authProvider.user!.uid!;
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Load available meals from Hostel Settings
      final settingsDoc = await FirebaseFirestore.instance
          .collection('hostelSettings')
          .doc('settings')
          .get();
      final settings = settingsDoc.data() ?? <String, dynamic>{};
      final activeMealsRaw = settings['messActiveMealTypes'];
      final availableMeals = activeMealsRaw is List
          ? activeMealsRaw.map((e) => e.toString().toLowerCase()).toList()
          : ['breakfast', 'lunch', 'dinner'];

      // Load current subscription
      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('mealSubscriptions')
          .doc('${studentId}_$monthKey')
          .get();

      Set<String> selectedMeals = {};
      if (subscriptionDoc.exists) {
        final data = subscriptionDoc.data() ?? <String, dynamic>{};
        final subscribedMeals = (data['subscribedMeals'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
            const <String>[];
        selectedMeals = Set.from(subscribedMeals);
      }

      if (mounted) {
        setState(() {
          _availableMeals = availableMeals;
          _selectedMeals = selectedMeals;
        });
      }
    } catch (e) {
      print('Error loading meal preferences: $e');
    }
  }

  Future<void> _saveMealPreferences(String mealType, bool isSelected) async {
    setState(() => _savingPreferences = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;
      
      final studentId = authProvider.user!.uid!;
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final docId = '${studentId}_$monthKey';

      if (isSelected) {
        _selectedMeals.add(mealType);
      } else {
        _selectedMeals.remove(mealType);
      }

      await FirebaseFirestore.instance
          .collection('mealSubscriptions')
          .doc(docId)
          .set({
            'studentId': studentId,
            'month': monthKey,
            'subscribedMeals': _selectedMeals.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _savingPreferences = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${mealType[0].toUpperCase()}${mealType.substring(1)} subscription updated'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingPreferences = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preference: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _resolveNoTokenReason(String studentId) async {
    try {
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final dateKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final settingsDoc = await FirebaseFirestore.instance.collection('hostelSettings').doc('settings').get();
      final settings = settingsDoc.data() ?? <String, dynamic>{};
      final messTimings = Map<String, dynamic>.from(settings['messTimings'] ?? {});
      final activeMealsRaw = settings['messActiveMealTypes'];
      final activeMeals = activeMealsRaw is List
          ? activeMealsRaw.map((e) => e.toString().toLowerCase()).toList()
          : messTimings.keys.map((e) => e.toString().toLowerCase()).toList();

      String? activeMealKey;
      for (final mealKey in ['breakfast', 'lunch', 'dinner']) {
        if (!activeMeals.contains(mealKey)) continue;
        final window = Map<String, dynamic>.from(messTimings[mealKey] ?? {});
        final start = _parseTimeForToday(window['start']?.toString());
        final end = _parseTimeForToday(window['end']?.toString());
        if (start == null || end == null) continue;
        final isActive = !now.isBefore(start) && !now.isAfter(end);
        if (isActive) {
          activeMealKey = mealKey;
          break;
        }
      }

      if (activeMealKey == null) {
        return 'No active meal window right now. Please check configured flexible timings.';
      }

      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('mealSubscriptions')
          .doc('${studentId}_$monthKey')
          .get();

      if (!subscriptionDoc.exists) {
        return 'No subscription found for ${_capitalize(activeMealKey)} in $monthKey.';
      }

      final subscriptionData = subscriptionDoc.data() ?? <String, dynamic>{};
      final subscribedMeals = (subscriptionData['subscribedMeals'] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          const <String>[];
      if (!subscribedMeals.contains(activeMealKey)) {
        return 'You are not subscribed to ${_capitalize(activeMealKey)} for this month.';
      }

      DocumentSnapshot<Map<String, dynamic>> studentDoc =
          await FirebaseFirestore.instance.collection('students').doc(studentId).get();
      Map<String, dynamic> studentData = studentDoc.data() ?? <String, dynamic>{};
      if (studentData.isEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(studentId).get();
        studentData = userDoc.data() ?? <String, dynamic>{};
      }

      final messSelected = studentData['messMonthlyFeeSelected'] == true ||
          studentData['feePlan']?.toString() == 'messMonthly' ||
          studentData['feePlan']?.toString() == 'hostelSemester+messMonthly';
      if (!messSelected) {
        return 'Mess monthly plan is not selected for your account.';
      }

      final monthlyFees = studentData['messMonthlyFees'] is Map
          ? Map<String, dynamic>.from(studentData['messMonthlyFees'] as Map)
          : <String, dynamic>{};
      if (monthlyFees[monthKey] != true) {
        return 'Mess fee is unpaid for $monthKey.';
      }

      final cycle = '$dateKey-$activeMealKey';
      final tokenDocs = await FirebaseFirestore.instance
          .collection('messTokens')
          .where('studentId', isEqualTo: studentId)
          .where('mealCycle', isEqualTo: cycle)
          .limit(1)
          .get();

      if (tokenDocs.docs.isEmpty) {
        return '${_capitalize(activeMealKey)} is active, but token has not been generated yet. Ask admin to click Generate Tokens Now.';
      }

      final tokenData = tokenDocs.docs.first.data();
      final status = tokenData['status']?.toString() ?? 'unknown';
      if (tokenData['isUsed'] == true) {
        return 'Your ${_capitalize(activeMealKey)} token is already used.';
      }
      return 'Token exists but is not active (status: $status).';
    } catch (e) {
      return 'Unable to load token reason: $e';
    }
  }

  DateTime? _parseTimeForToday(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Token'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/meal-history');
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            onPressed: () {
              Navigator.pushNamed(context, '/mess-menu');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadToken,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildMealPreferencesSection(),
                    const SizedBox(height: 24),
                    if (_currentToken != null) ...[
                      _buildTokenCard(),
                      const SizedBox(height: 24),
                      _buildMealInfo(),
                    ] else ...[
                      _buildNoTokenState(),
                    ],
                    const SizedBox(height: 24),
                    _buildTodayMealStatus(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMealPreferencesSection() {
    if (_availableMeals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Your Meals',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_savingPreferences)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.grey200,
                    ),
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose meals for this month',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableMeals.map((meal) {
              final isSelected = _selectedMeals.contains(meal);
              final mealLabel =
                  '${meal[0].toUpperCase()}${meal.substring(1)}';

              return GestureDetector(
                onTap: _savingPreferences
                    ? null
                    : () => _saveMealPreferences(meal, !isSelected),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white,
                            width: 2,
                          ),
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mealLabel,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCard() {
    bool isValid = _currentToken?.isValid ?? false;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isValid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.cancel,
                  color: isValid ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isValid ? 'Active Token' : 'Token Expired',
                  style: TextStyle(
                    color: isValid ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grey200, width: 2),
            ),
            child: QrImageView(
              data: _currentToken!.qrData ?? '',
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            _currentToken!.mealTypeString,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Valid until ${_formatTime(_currentToken!.validUntil)}',
            style: TextStyle(
              color: isValid ? AppColors.grey600 : Colors.red,
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Token refreshes at ${_getNextMealTime()}',
                  style: TextStyle(
                    color: AppColors.grey700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Show this QR code at the mess counter',
            style: TextStyle(
              color: AppColors.grey600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meal Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentToken!.statusString,
                  style: TextStyle(
                    color: _currentToken!.statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Token ID', _currentToken!.tokenCode ?? ''),
          _buildInfoRow('Date', _formatDate(_currentToken!.mealDate)),
          _buildInfoRow('Valid From', _formatTime(_currentToken!.validFrom)),
          _buildInfoRow('Valid Until', _formatTime(_currentToken!.validUntil)),
          if (_currentToken!.isUsed == true) ...[
            _buildInfoRow('Used At', _formatTime(_currentToken!.usedAt)),
            _buildInfoRow('Scanned By', _currentToken!.usedBy ?? ''),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.grey600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTokenState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 80,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Token',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _noTokenReason ??
                'There is no active meal token right now.\nAsk admin to generate tokens for your active meal types.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loadToken,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMealStatus() {
    return Consumer<MessProvider>(
      builder: (context, provider, child) {
        final status = provider.todayMealStatus;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Meal Status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMealStatusItem('Breakfast', status['breakfast'] ?? false),
                  _buildMealStatusItem('Lunch', status['lunch'] ?? false),
                  _buildMealStatusItem('Dinner', status['dinner'] ?? false),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMealStatusItem(String meal, bool taken) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: taken ? Colors.green.withOpacity(0.1) : AppColors.grey100,
            border: Border.all(
              color: taken ? Colors.green : AppColors.grey300,
              width: 2,
            ),
          ),
          child: Icon(
            taken ? Icons.check : Icons.restaurant,
            color: taken ? Colors.green : AppColors.grey500,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          meal,
          style: TextStyle(
            fontSize: 12,
            fontWeight: taken ? FontWeight.bold : FontWeight.normal,
            color: taken ? Colors.green : AppColors.grey600,
          ),
        ),
      ],
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getNextMealTime() {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour < 9) return '12:00 PM';
    if (hour < 14) return '7:00 PM';
    if (hour < 21) return '7:00 AM';
    return '7:00 AM';
  }
}