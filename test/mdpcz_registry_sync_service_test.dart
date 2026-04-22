import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zimdoctors/services/mdpcz_registry_sync_service.dart';

void main() {
  test('fetchPage parses table rows and last page', () async {
    const html = '''
<!doctype html>
<html>
  <body>
    <table>
      <thead>
        <tr>
          <th>Name</th>
          <th>Gender</th>
          <th>Registration Number</th>
          <th>Qualification</th>
          <th>Specialty</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Aaron Rumbidzayi</td>
          <td>Female</td>
          <td>D Ther 802624</td>
          <td>D.Ther (ZIMB) 2018</td>
          <td>Dental Therapist</td>
        </tr>
        <tr>
          <td>  </td>
          <td>Male</td>
          <td>Dp 999999</td>
          <td>BDS</td>
          <td>Dental Practitioner</td>
        </tr>
      </tbody>
    </table>
    <button wire:click="gotoPage(1, 'page')">1</button>
    <button wire:click="gotoPage(17, 'page')">17</button>
    <button wire:click="gotoPage(415, 'page')">415</button>
  </body>
</html>
''';

    final client = MockClient((req) async {
      expect(req.url.host, 'mdpcz.co.zw');
      expect(req.url.path, '/public_register');
      expect(req.url.queryParameters['page'], '2');
      return http.Response(html, 200, headers: {'content-type': 'text/html'});
    });

    final svc = MdpczRegistrySyncService(client: client);
    final res = await svc.fetchPage(2);

    expect(res.page, 2);
    expect(res.lastPage, 415);
    expect(res.entries.length, 1);

    final entry = res.entries.single;
    expect(entry.fullName, 'Aaron Rumbidzayi');
    expect(entry.gender, 'Female');
    expect(entry.registrationNumber, 'D Ther 802624');
    expect(entry.registrationNumberNormalized, 'DTHER802624');
    expect(entry.specialty, 'Dental Therapist');
    expect(entry.sourcePage, 2);
    expect(entry.sourceUrl, contains('page=2'));
    expect(entry.nameTokens, containsAll(<String>['aaron', 'rumbidzayi']));
  });

  test('normalizeRegistrationNumber strips spaces and punctuation', () {
    expect(
      MdpczRegistrySyncService.normalizeRegistrationNumber(' M 056016 '),
      'M056016',
    );
    expect(
      MdpczRegistrySyncService.normalizeRegistrationNumber('Int 806223'),
      'INT806223',
    );
    expect(
      MdpczRegistrySyncService.normalizeRegistrationNumber('MCZ/123-45'),
      'MCZ_123-45',
    );
  });
}

