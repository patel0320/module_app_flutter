// Tests for parsing the device's system log (`get_page_configuration`
// "system" page, `system_logs` section) into [SystemLogPage].
import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/models/models.dart';

void main() {
  Map<String, dynamic> result() => {
        'device_family': 'dimmer',
        'page': 'system',
        'sections': [
          {
            'key': 'system_information',
            'title': 'System Information',
            'rows': [],
            'fields': [],
            'columns': [],
          },
          {
            'key': 'system_logs',
            'title': 'System Logs',
            'description': 'Most recent device events (3661 total).',
            'can_delete': true,
            'total_pages': 367,
            'page_size': 10,
            'page': 1,
            'total_count': 3661,
            'columns': [
              {'key': 'date_time', 'label': 'Date / Time'},
              {'key': 'tag', 'label': 'Tag'},
              {'key': 'state', 'label': 'Status'},
              {'key': 'note', 'label': 'Note'},
            ],
            'rows': [
              {
                'note': 'Duty Set',
                'date_time': '2026/09/17 17:25:26',
                'state': 'ON',
                'tag': 'Out-1',
              },
              {
                'note': 'Request from Web',
                'date_time': '2026/09/17 17:11:26',
                'state': 'OFF',
                'tag': 'Out-2',
              },
            ],
          },
        ],
      };

  test('parses rows, columns and pagination from the system_logs section', () {
    final logs = SystemLogPage.fromResult(result());
    expect(logs, isNotNull);
    expect(logs!.rows, hasLength(2));
    expect(logs.rows.first.note, 'Duty Set');
    expect(logs.rows.first.dateTime, '2026/09/17 17:25:26');
    expect(logs.rows.first.state, 'ON');
    expect(logs.rows.first.tag, 'Out-1');
    expect(logs.rows[1].note, 'Request from Web');
    expect(logs.columns, hasLength(4));
    expect(
        logs.columns.map((c) => c.key), ['date_time', 'tag', 'state', 'note']);
    expect(logs.columns.map((c) => c.label),
        ['Date / Time', 'Tag', 'Status', 'Note']);
    expect(logs.page, 1);
    expect(logs.pageSize, 10);
    expect(logs.totalPages, 367);
    expect(logs.totalCount, 3661);
    expect(logs.hasMore, isTrue);
  });

  test('hasMore is false on the last page', () {
    final lastPage = SystemLogPage.fromResult({
      'sections': [
        {
          'key': 'system_logs',
          'page': 367,
          'page_size': 10,
          'total_pages': 367,
          'total_count': 3661,
          'rows': <Object>[],
          'columns': <Object>[],
        },
      ],
    });
    expect(lastPage!.page, 367);
    expect(lastPage.hasMore, isFalse);
  });

  test('returns null when the system_logs section is missing', () {
    expect(SystemLogPage.fromResult({'sections': <Object>[]}), isNull);
    expect(SystemLogPage.fromResult(null), isNull);
    expect(SystemLogPage.fromResult({'page': 'system'}), isNull);
  });
}
