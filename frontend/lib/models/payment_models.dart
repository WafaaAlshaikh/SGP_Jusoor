class PaymentMethod {
  final String id;
  final String name;
  final String description;
  final String icon;
  final double processingFee;
  final double estimatedTotal;
  final bool available;
  final List<String> features;
  final String? verificationTime;
  final bool? requiresPhysicalPresence;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.processingFee,
    required this.estimatedTotal,
    required this.available,
    required this.features,
    this.verificationTime,
    this.requiresPhysicalPresence,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'credit_card',
      // ⬇️⬇️⬇️ إصلاح تحويل String إلى double
      processingFee: _parseDouble(json['processing_fee']),
      estimatedTotal: _parseDouble(json['estimated_total']),
      available: json['available'] ?? true,
      features: List<String>.from(json['features'] ?? []),
      verificationTime: json['verification_time'],
      requiresPhysicalPresence: json['requires_physical_presence'],
    );
  }

  // ⬇️⬇️⬇️ أضف دالة التحويل المساعدة
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value.toString().replaceAll('\$', '').replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'processing_fee': processingFee,
      'estimated_total': estimatedTotal,
      'available': available,
      'features': features,
      'verification_time': verificationTime,
      'requires_physical_presence': requiresPhysicalPresence,
    };
  }
}

class Invoice {
  final int invoiceId;
  final int sessionId;
  final String invoiceNumber;
  final double amount;
  final double taxAmount;
  final double totalAmount;
  final String status;
  final DateTime dueDate;
  final DateTime? paidDate;
  final DateTime issuedDate;

  Invoice({
    required this.invoiceId,
    required this.sessionId,
    required this.invoiceNumber,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    required this.status,
    required this.dueDate,
    this.paidDate,
    required this.issuedDate,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      invoiceId: json['invoice_id'] ?? 0,
      sessionId: json['session_id'] ?? 0,
      invoiceNumber: json['invoice_number'] ?? '',
      // ⬇️⬇️⬇️ استخدم دالة التحويل المساعدة
      amount: _parseDouble(json['amount']),
      taxAmount: _parseDouble(json['tax_amount']),
      totalAmount: _parseDouble(json['total_amount']),
      status: json['status'] ?? 'Pending',
      dueDate: DateTime.parse(json['due_date'] ?? DateTime.now().toString()),
      paidDate: json['paid_date'] != null ? DateTime.parse(json['paid_date']) : null,
      issuedDate: DateTime.parse(json['issued_date'] ?? DateTime.now().toString()),
    );
  }

  // ⬇️⬇️⬇️ نفس دالة التحويل المساعدة
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value.toString().replaceAll('\$', '').replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'session_id': sessionId,
      'invoice_number': invoiceNumber,
      'amount': amount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'status': status,
      'due_date': dueDate.toIso8601String(),
      'paid_date': paidDate?.toIso8601String(),
      'issued_date': issuedDate.toIso8601String(),
    };
  }
}

class PaymentResponse {
  final bool success;
  final String message;
  final String? transactionId;
  final String? paymentId;
  final Map<String, dynamic>? data;

  PaymentResponse({
    required this.success,
    required this.message,
    this.transactionId,
    this.paymentId,
    this.data,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      transactionId: json['data']?['transaction_id'],
      paymentId: json['data']?['payment_id']?.toString(),
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'transaction_id': transactionId,
      'payment_id': paymentId,
      'data': data,
    };
  }
}

class BankDetails {
  final String bankName;
  final String branch;
  final String accountName;
  final String accountNumber;
  final String iban;
  final String swiftCode;
  final String currency;

  BankDetails({
    required this.bankName,
    required this.branch,
    required this.accountName,
    required this.accountNumber,
    required this.iban,
    required this.swiftCode,
    required this.currency,
  });

  factory BankDetails.fromJson(Map<String, dynamic> json) {
    return BankDetails(
      bankName: json['bank_name'] ?? '',
      branch: json['branch'] ?? '',
      accountName: json['account_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      iban: json['iban'] ?? '',
      swiftCode: json['swift_code'] ?? '',
      currency: json['currency'] ?? 'JOD',
    );
  }
}