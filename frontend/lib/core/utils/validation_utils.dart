class ValidationUtils {
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Please enter a valid number';
    }
    if (amount <= 0) {
      return 'Amount must be greater than zero';
    }
    
    // Check for more than 2 decimal places
    if (value.contains('.')) {
      final decimals = value.split('.')[1];
      if (decimals.length > 2) {
        return 'Maximum 2 decimal places allowed';
      }
    }
    
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateSelection(dynamic value, String fieldName) {
    if (value == null) {
      return 'Please select a $fieldName';
    }
    return null;
  }
}
