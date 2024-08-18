import 'dart:async';

import 'package:alazkar/src/core/extension/extension_object.dart';
import 'package:alazkar/src/core/helpers/db_helper.dart';
import 'package:alazkar/src/features/quran/data/models/verse_model.dart';
import 'package:sqflite/sqflite.dart';

UthmaniRepository uthmaniRepository = UthmaniRepository();

class UthmaniRepository {
  ///|*| ************* Variables ************* *|

  static const String name = "quran.ar.uthmani.v2";
  static const String dbName = "$name.db";
  static const int dbVersion = 2;

  static UthmaniRepository? _databaseHelper;
  static Database? _database;
  static late final DBHelper _dbHelper;

  ///|*| ************* Singleton Constructor ************* *|
  factory UthmaniRepository() {
    _dbHelper = DBHelper(dbName: dbName, dbVersion: dbVersion);
    _databaseHelper ??= UthmaniRepository._createInstance();
    return _databaseHelper!;
  }

  UthmaniRepository._createInstance();

  Future<Database> get database async {
    if (_database == null || !(_database?.isOpen ?? false)) {
      _database = await _dbHelper.initDatabase();
    }
    return _database!;
  }

  Future<void> init() async {
    // Ensure the database is initialized
    await database;
  }

  ///|*| ************* Functions ************* |

  Future<String> getArabicText({
    required int sura,
    required int startAyah,
    required int endAyah,
  }) async {
    final Database db = await database;

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
SELECT * FROM arabic_text 
WHERE sura = ? AND ayah BETWEEN ? AND ? 
ORDER BY ayah;
''',
      [sura, startAyah, endAyah],
    );

    if (maps.isEmpty) return "";

    return maps.map((e) => Verse.fromMap(e)).fold(
          "",
          (previousValue, element) =>
              "$previousValue ${element.text} ${element.ayah.toArabicNumber()}",
        );
  }

  /// Close database
  Future close() async {
    final db = await database;
    db.close();
  }
}
