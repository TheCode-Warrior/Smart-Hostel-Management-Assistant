class AppConstants {
  static const String appName = 'Hostel Management System';
  static const String appVersion = '1.0.0';
  
  // Collection names
  static const String usersCollection = 'users';
  static const String studentsCollection = 'students';
  static const String roomsCollection = 'rooms';
  static const String attendanceCollection = 'attendance';
  static const String messTokensCollection = 'messTokens';
  static const String mealRecordsCollection = 'mealRecords';
  static const String feesCollection = 'fees';
  static const String complaintsCollection = 'complaints';
  static const String chatbotCollection = 'chatbotConversations';
  static const String staffCollection = 'staff';
  static const String notificationsCollection = 'notifications';
  static const String announcementsCollection = 'announcements';
  static const String hostelSettingsCollection = 'hostelSettings';
  static const String messMenuCollection = 'messMenu';
  
  // Shared preferences keys
  static const String themePrefKey = 'theme_mode';
  static const String userLoggedInKey = 'user_logged_in';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  
  // QR code settings
  static const int qrCodeExpirySeconds = 30;
  static const int messTokenValidMinutes = 120; // 2 hours
  
  // Geo-fencing
  static const double defaultGeoFenceRadius = 500; // meters
  
  // Pagination
  static const int pageSize = 20;
  
  // Date formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'hh:mm a';
  static const String dateTimeFormat = 'dd/MM/yyyy hh:mm a';
}

class AppStrings {
  // Auth
  static const String login = 'Login';
  static const String signup = 'Sign Up';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String dontHaveAccount = 'Don\'t have an account? ';
  static const String alreadyHaveAccount = 'Already have an account? ';
  
  // Dashboard
  static const String dashboard = 'Dashboard';
  static const String attendance = 'Attendance';
  static const String mess = 'Mess';
  static const String students = 'Students';
  static const String rooms = 'Rooms';
  static const String fees = 'Fees';
  static const String complaints = 'Complaints';
  static const String chatbot = 'Chatbot';
  static const String notifications = 'Notifications';
  static const String profile = 'Profile';
  static const String settings = 'Settings';
  
  // Attendance
  static const String markAttendance = 'Mark Attendance';
  static const String checkIn = 'Check In';
  static const String checkOut = 'Check Out';
  static const String scanQR = 'Scan QR Code';
  static const String useGPS = 'Use GPS';
  static const String attendanceHistory = 'Attendance History';
  
  // Mess
  static const String messToken = 'Mess Token';
  static const String scanForMess = 'Scan for Mess';
  static const String mealHistory = 'Meal History';
  static const String todayMenu = 'Today\'s Menu';
  static const String validUntil = 'Valid until';
  static const String tokenUsed = 'Token Used';
  
  // Complaints
  static const String raiseComplaint = 'Raise Complaint';
  static const String myComplaints = 'My Complaints';
  static const String complaintStatus = 'Complaint Status';
  static const String assignComplaint = 'Assign Complaint';
  static const String resolution = 'Resolution';
  
  // Common
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String view = 'View';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String loading = 'Loading...';
  static const String noData = 'No data found';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String warning = 'Warning';
  static const String confirm = 'Confirm';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String submit = 'Submit';
}