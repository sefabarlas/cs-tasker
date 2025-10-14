import 'package:timezone/timezone.dart' as tz;

class TimeService {
  tz.TZDateTime localToTz(String tzId, DateTime local) {
    final loc = tz.getLocation(tzId);
    // local (DateTime) saat/dakika kullanıcı seçimi; bunu TZDateTime’a projekte ediyoruz
    return tz.TZDateTime.from(local, loc);
  }

  DateTime toUtcFromLocal(String tzId, DateTime local) {
    final tzdt = localToTz(tzId, local);
    return tzdt.toUtc();
  }
}
