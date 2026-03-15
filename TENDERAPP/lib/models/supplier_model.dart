class Supplier {
  int? id;
  String name;
  String? contactPerson;
  String? phone;
  String? email;
  String? address;
  String? lastVisit; // ISO 8601 string

  Supplier({
    this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.lastVisit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'last_visit': lastVisit,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      contactPerson: map['contact_person'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      lastVisit: map['last_visit'],
    );
  }
}
