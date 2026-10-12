
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum ResourceKind { wood, stone, iron, food, gold }

class GameState {
  static const saveKey = 'harb_al_muluk_save_v2';
  static late SharedPreferences _prefs;

  int wood = 650;
  int stone = 520;
  int iron = 260;
  int food = 800;
  int gold = 50;
  int soldiers = 12;
  int archers = 0;
  int cavalry = 0;
  int hall = 1;
  int lumber = 1;
  int quarry = 1;
  int mine = 1;
  int farm = 1;
  int barracks = 1;
  int wall = 1;
  int battlesWon = 0;
  int battlesLost = 0;
  int totalCollections = 0;
  int dailyMissionsClaimed = 0;
  String rulerName = 'ملك الفجر';
  DateTime? upgradeEndsAt;
  String? upgradingId;
  DateTime? lastCollection;
  String? lastDayKey;
  bool sound = false;

  static Future<GameState> load() async {
    _prefs = await SharedPreferences.getInstance();
    final state = GameState();
    final raw = _prefs.getString(saveKey);
    if (raw != null) {
      try { state._fromMap(jsonDecode(raw) as Map<String, dynamic>); } catch (_) {}
    }
    state._applyOfflineProduction();
    state._dailyResetIfNeeded();
    await state.save();
    return state;
  }

  void _fromMap(Map<String, dynamic> m) {
    int val(String key, int fallback) => (m[key] as num?)?.toInt() ?? fallback;
    wood = val('wood', wood); stone = val('stone', stone); iron = val('iron', iron);
    food = val('food', food); gold = val('gold', gold);
    soldiers = val('soldiers', soldiers); archers = val('archers', archers);
    cavalry = val('cavalry', cavalry); hall = val('hall', hall);
    lumber = val('lumber', lumber); quarry = val('quarry', quarry);
    mine = val('mine', mine); farm = val('farm', farm);
    barracks = val('barracks', barracks); wall = val('wall', wall);
    battlesWon = val('battlesWon', battlesWon); battlesLost = val('battlesLost', battlesLost);
    totalCollections = val('totalCollections', totalCollections);
    dailyMissionsClaimed = val('dailyMissionsClaimed', dailyMissionsClaimed);
    rulerName = m['rulerName'] as String? ?? rulerName;
    upgradingId = m['upgradingId'] as String?;
    final upgrade = m['upgradeEndsAt'] as String?;
    upgradeEndsAt = upgrade == null ? null : DateTime.tryParse(upgrade);
    final collection = m['lastCollection'] as String?;
    lastCollection = collection == null ? null : DateTime.tryParse(collection);
    lastDayKey = m['lastDayKey'] as String?;
    sound = m['sound'] as bool? ?? sound;
  }

  void _applyOfflineProduction() {
    final last = lastCollection;
    final now = DateTime.now();
    if (last == null) { lastCollection = now; return; }
    final minutes = now.difference(last).inMinutes.clamp(0, 480);
    if (minutes > 0) {
      wood += minutes * (2 + lumber);
      stone += minutes * (1 + quarry);
      iron += minutes * (1 + mine);
      food += minutes * (3 + farm);
      lastCollection = now;
    }
  }

  void _dailyResetIfNeeded() {
    final now = DateTime.now();
    final key = '${now.year}-${now.month}-${now.day}';
    if (lastDayKey != key) {
      dailyMissionsClaimed = 0;
      lastDayKey = key;
    }
  }

  Future<void> save() async {
    await _prefs.setString(saveKey, jsonEncode({
      'wood': wood, 'stone': stone, 'iron': iron, 'food': food, 'gold': gold,
      'soldiers': soldiers, 'archers': archers, 'cavalry': cavalry,
      'hall': hall, 'lumber': lumber, 'quarry': quarry, 'mine': mine,
      'farm': farm, 'barracks': barracks, 'wall': wall,
      'battlesWon': battlesWon, 'battlesLost': battlesLost,
      'totalCollections': totalCollections, 'dailyMissionsClaimed': dailyMissionsClaimed,
      'rulerName': rulerName, 'upgradingId': upgradingId,
      'upgradeEndsAt': upgradeEndsAt?.toIso8601String(),
      'lastCollection': lastCollection?.toIso8601String(),
      'lastDayKey': lastDayKey, 'sound': sound,
    }));
  }

  void reset() {
    wood=650; stone=520; iron=260; food=800; gold=50;
    soldiers=12; archers=0; cavalry=0; hall=1; lumber=1; quarry=1;
    mine=1; farm=1; barracks=1; wall=1; battlesWon=0; battlesLost=0;
    totalCollections=0; dailyMissionsClaimed=0; rulerName='ملك الفجر';
    upgradeEndsAt=null; upgradingId=null; lastCollection=DateTime.now();
  }

  int get totalArmy => soldiers + archers + cavalry;
  int get power => soldiers * 10 + archers * 12 + cavalry * 22 + wall * 30 + hall * 25;

  int amount(String id) => switch (id) {
    'wood' => wood, 'stone' => stone, 'iron' => iron, 'food' => food, 'gold' => gold, _ => 0
  };
  void spend({int woodCost=0, int stoneCost=0, int ironCost=0, int foodCost=0, int goldCost=0}) {
    wood-=woodCost; stone-=stoneCost; iron-=ironCost; food-=foodCost; gold-=goldCost;
  }
  bool canAfford({int woodCost=0, int stoneCost=0, int ironCost=0, int foodCost=0, int goldCost=0}) =>
    wood>=woodCost && stone>=stoneCost && iron>=ironCost && food>=foodCost && gold>=goldCost;
}
