class AppUser {
  final String username;
  final String password;
  final String displayName;
  final String role; // admin | manager | user

  AppUser({
    required this.username,
    required this.password,
    required this.displayName,
    required this.role,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isManager => role.toLowerCase() == 'manager';
  bool get isAdminOrManager => isAdmin || isManager;

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'displayName': displayName,
        'role': role,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        username: (j['username'] ?? '').toString(),
        password: (j['password'] ?? '').toString(),
        displayName: (j['displayName'] ?? j['username'] ?? '').toString(),
        role: (j['role'] ?? 'user').toString(),
      );
}

class Employee {
  final String id;
  final String name;
  final String role;

  Employee({required this.id, required this.name, required this.role});

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: (j['id'] ?? j['empId'] ?? '').toString(),
        name: (j['name'] ?? j['empName'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
      );
}

class StatusRecord {
  final String empId;
  final String empName;
  final String role;
  final String siteName;
  final String workType;
  final String scopeOfWork;
  final String status;
  final String date;
  final String workDone;
  final String completionPct;
  final String workRemarks;
  final String nextVisitRequired;
  final String nextVisitDate;
  final String instructionFrom;
  final String inspectedBy;
  final String customerName;
  final String designation;
  final String phone;
  final String email;

  StatusRecord({
    required this.empId,
    required this.empName,
    required this.role,
    required this.siteName,
    required this.workType,
    required this.scopeOfWork,
    required this.status,
    required this.date,
    this.workDone = '',
    this.completionPct = '',
    this.workRemarks = '',
    this.nextVisitRequired = '',
    this.nextVisitDate = '',
    this.instructionFrom = '',
    this.inspectedBy = '',
    this.customerName = '',
    this.designation = '',
    this.phone = '',
    this.email = '',
  });

  factory StatusRecord.fromJson(Map<String, dynamic> j) => StatusRecord(
        empId: (j['empId'] ?? '').toString(),
        empName: (j['empName'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        siteName: (j['siteName'] ?? '').toString(),
        workType: (j['workType'] ?? '').toString(),
        scopeOfWork: (j['scopeOfWork'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        workDone: (j['workDone'] ?? '').toString(),
        completionPct: (j['completionPct'] ?? '').toString(),
        workRemarks: (j['workRemarks'] ?? '').toString(),
        nextVisitRequired: (j['nextVisitRequired'] ?? '').toString(),
        nextVisitDate: (j['nextVisitDate'] ?? '').toString(),
        instructionFrom: (j['instructionFrom'] ?? '').toString(),
        inspectedBy: (j['inspectedBy'] ?? '').toString(),
        customerName: (j['customerName'] ?? '').toString(),
        designation: (j['designation'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
      );
}

class Site {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String contactName;
  final String contactPhone;
  final String contactEmail;

  Site({
    required this.id,
    required this.name,
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.contactName = '',
    this.contactPhone = '',
    this.contactEmail = '',
  });

  factory Site.fromJson(Map<String, dynamic> j) => Site(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
        state: (j['state'] ?? '').toString(),
        zipCode: (j['zipCode'] ?? '').toString(),
        contactName: (j['contactName'] ?? '').toString(),
        contactPhone: (j['contactPhone'] ?? '').toString(),
        contactEmail: (j['contactEmail'] ?? '').toString(),
      );
}

class InventoryItem {
  final String itemId;
  final String name;
  final String category;
  final num qty;
  final num minStock;
  final String unit;
  final String location;
  final String description;
  final String lastUpdated;
  final String updatedBy;

  InventoryItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.qty,
    required this.minStock,
    this.unit = '',
    this.location = '',
    this.description = '',
    this.lastUpdated = '',
    this.updatedBy = '',
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        itemId: (j['itemId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        qty: num.tryParse((j['qty'] ?? '0').toString()) ?? 0,
        minStock: num.tryParse((j['minStock'] ?? '0').toString()) ?? 0,
        unit: (j['unit'] ?? '').toString(),
        location: (j['location'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        lastUpdated: (j['lastUpdated'] ?? '').toString(),
        updatedBy: (j['updatedBy'] ?? '').toString(),
      );
}

class SerialNumber {
  final String serialNo;
  final String itemId;
  final String itemName;
  final String status;
  final String siteName;
  final String issuedTo;
  final String date;

  SerialNumber({
    required this.serialNo,
    required this.itemId,
    required this.itemName,
    this.status = 'Available',
    this.siteName = '',
    this.issuedTo = '',
    this.date = '',
  });

  factory SerialNumber.fromJson(Map<String, dynamic> j) => SerialNumber(
        serialNo: (j['serialNo'] ?? '').toString(),
        itemId: (j['itemId'] ?? '').toString(),
        itemName: (j['itemName'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        siteName: (j['siteName'] ?? '').toString(),
        issuedTo: (j['issuedTo'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
      );
}

class InventoryLogEntry {
  final String logId;
  final String itemId;
  final String itemName;
  final num qty;
  final String type;
  final String siteName;
  final String empName;
  final String date;
  final String remarks;
  final String purpose;

  InventoryLogEntry({
    required this.logId,
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.type,
    this.siteName = '',
    this.empName = '',
    this.date = '',
    this.remarks = '',
    this.purpose = '',
  });

  factory InventoryLogEntry.fromJson(Map<String, dynamic> j) =>
      InventoryLogEntry(
        logId: (j['logId'] ?? '').toString(),
        itemId: (j['itemId'] ?? '').toString(),
        itemName: (j['itemName'] ?? '').toString(),
        qty: num.tryParse((j['qty'] ?? '0').toString()) ?? 0,
        type: (j['type'] ?? '').toString(),
        siteName: (j['siteName'] ?? '').toString(),
        empName: (j['empName'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        remarks: (j['remarks'] ?? '').toString(),
        purpose: (j['purpose'] ?? '').toString(),
      );
}
