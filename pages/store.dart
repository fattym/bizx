class Store {
  final String name;
  final String location;
  final String phone;
  final String city;

  Store({
    required this.name,
    required this.location,
    required this.phone,
    required this.city,
  });
}

// Data extracted from deheus.co.ke
final List<Store> deHeusStores = [
  Store(
    name: "KuKuCow Max Feeds Nakuru",
    city: "Nakuru",
    location: "Near MEAS Club, Government Road",
    phone: "+254702828327",
  ),
  Store(
    name: "KuKuCow Max Feeds Nyahururu",
    city: "Nyahururu",
    location: "Opposite Chieni Supermarket",
    phone: "+254796887946",
  ),
  Store(
    name: "Royal Dutch Feeds Ruiru",
    city: "Ruiru",
    location: "Kiwazi Place, opposite Membley Estate",
    phone: "+254791522782",
  ),
  Store(
    name: "Royal Dutch Feeds Kitengela",
    city: "Kitengela",
    location: "GXG4+VV9, Kitengela",
    phone: "+254708326618",
  ),
  Store(
    name: "KuKuCow Max Feeds Embu",
    city: "Embu",
    location: "Next to Kirimari Agrovet",
    phone: "+254702828142",
  ),
  Store(
    name: "Royal Dutch Feeds Githunguri",
    city: "Githunguri",
    location: "Opposite Delta filling station",
    phone: "+254791858428",
  ),
  Store(
    name: "Royal Dutch Feeds Machakos",
    city: "Machakos",
    location: "Junction of Chumvi - Kitui Rd",
    phone: "+254759516980",
  ),
];
