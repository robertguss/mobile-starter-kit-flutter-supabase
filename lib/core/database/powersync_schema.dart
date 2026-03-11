import 'package:powersync/powersync.dart';

const appPowerSyncSchema = Schema([
  Table(
    'notes',
    [
      Column.text('user_id'),
      Column.text('title'),
      Column.text('body'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
  ),
  Table(
    'subscriptions',
    [
      Column.text('user_id'),
      Column.text('status'),
      Column.text('product_id'),
      Column.text('expires_at'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
  ),
]);
