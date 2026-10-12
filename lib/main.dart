
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'game_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await GameState.load();
  runApp(KingsWarApp(state: state));
}

class KingsWarApp extends StatelessWidget {
  const KingsWarApp({super.key, required this.state});
  final GameState state;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'حرب الملوك',
    debugShowCheckedModeBanner: false,
    theme: GameTheme.dark,
    home: GameShell(state: state),
  );
}

class GameShell extends StatefulWidget {
  const GameShell({super.key, required this.state});
  final GameState state;
  @override State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int tab = 0;
  late Timer timer;
  DateTime now = DateTime.now();
  GameState get s => widget.state;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        now = DateTime.now();
        if (s.upgradeEndsAt != null && !now.isBefore(s.upgradeEndsAt!)) {
          _finishUpgrade();
        }
      });
    });
  }
  @override
  void dispose() { timer.cancel(); super.dispose(); }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _persist() async { await s.save(); if (mounted) setState(() {}); }

  Future<void> _collect() async {
    s.wood += 60 + s.lumber * 12;
    s.stone += 45 + s.quarry * 10;
    s.iron += 25 + s.mine * 8;
    s.food += 75 + s.farm * 14;
    s.totalCollections++;
    s.lastCollection = DateTime.now();
    await _persist();
    _toast('تم جمع موارد المملكة بنجاح');
  }

  List<BuildingInfo> get buildings => [
    BuildingInfo('hall','مبنى القيادة','مركز المملكة ويزيد قوة قريتك',Icons.castle,180,140,50,18,s.hall,()=>s.hall++),
    BuildingInfo('lumber','منشرة الخشب','ترفع إنتاج الخشب مع مرور الوقت',Icons.forest,110,60,20,12,s.lumber,()=>s.lumber++),
    BuildingInfo('quarry','محجر الحجر','يزيد إنتاج الحجر',Icons.landscape,100,100,20,12,s.quarry,()=>s.quarry++),
    BuildingInfo('mine','منجم الحديد','يزيد إنتاج الحديد',Icons.hardware,130,80,40,14,s.mine,()=>s.mine++),
    BuildingInfo('farm','المزرعة','تنتج الطعام اللازم للجيش',Icons.agriculture,90,100,15,10,s.farm,()=>s.farm++),
    BuildingInfo('barracks','الثكنة','مركز تدريب قوات المشاة والرماة والفرسان',Icons.shield,150,100,80,16,s.barracks,()=>s.barracks++),
    BuildingInfo('wall','السور الدفاعي','يرفع قوة دفاع المملكة',Icons.fort,220,240,40,20,s.wall,()=>s.wall++),
  ];

  Future<void> _startUpgrade(BuildingInfo b) async {
    if (s.upgradingId != null) { _toast('يوجد مبنى آخر قيد التطوير.'); return; }
    final multiplier = b.level;
    final wc = b.woodCost * multiplier;
    final sc = b.stoneCost * multiplier;
    final ic = b.ironCost * multiplier;
    if (!s.canAfford(woodCost:wc,stoneCost:sc,ironCost:ic)) {
      _toast('الموارد غير كافية. اجمع الموارد أولًا.'); return;
    }
    s.spend(woodCost:wc,stoneCost:sc,ironCost:ic);
    s.upgradingId = b.id;
    s.upgradeEndsAt = DateTime.now().add(Duration(seconds:b.seconds + (b.level * 4)));
    await _persist();
    _toast('بدأ تطوير ${b.name}');
  }

  Future<void> _finishUpgrade() async {
    final id = s.upgradingId;
    if (id == null) return;
    final matches = buildings.where((x)=>x.id==id).toList();
    final b = matches.isEmpty ? null : matches.first;
    if (b != null) b.levelUp();
    s.upgradingId = null;
    s.upgradeEndsAt = null;
    await s.save();
    if (mounted) _toast('اكتمل التطوير بنجاح!');
  }

  Future<void> _train(String unit) async {
    int wc=0, ic=0, fc=0;
    if (unit=='مشاة') { wc=35; ic=15; fc=45; }
    if (unit=='رماة') { wc=45; ic=20; fc=35; }
    if (unit=='فرسان') { wc=70; ic=45; fc=60; }
    if (!s.canAfford(woodCost:wc,ironCost:ic,foodCost:fc)) {
      _toast('الموارد لا تكفي لتدريب هذه الوحدة.'); return;
    }
    s.spend(woodCost:wc,ironCost:ic,foodCost:fc);
    if(unit=='مشاة') s.soldiers++;
    if(unit=='رماة') s.archers++;
    if(unit=='فرسان') s.cavalry++;
    await _persist();
    _toast('تم تدريب $unit جديد');
  }

  Future<void> _battle() async {
    final enemy = 70 + Random().nextInt(180);
    final strength = s.power + Random().nextInt(100);
    final won = strength >= enemy;
    if (won) {
      s.battlesWon++;
      s.wood += 90 + Random().nextInt(80);
      s.stone += 70 + Random().nextInt(60);
      s.food += 100;
      s.gold += 2;
      final loss = min(s.soldiers, Random().nextInt(3));
      s.soldiers -= loss;
    } else {
      s.battlesLost++;
      s.soldiers = max(1, s.soldiers - min(s.soldiers-1, 2 + Random().nextInt(4)));
    }
    await _persist();
    if (!mounted) return;
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(won?'انتصار! 🏆':'تراجع الجيش'),
      content:Text(won
        ? 'انتصرت قواتك على الحامية المعادية وعادت بالغنائم. هذه معركة تدريبية محلية.'
        : 'كانت الحامية أقوى هذه المرة. طوّر جيشك وحاول مجددًا. هذه معركة تدريبية محلية.'),
      actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('متابعة'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_village(), _buildingsPage(), _armyPage(), _worldPage(), _kingdomPage()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('حرب الملوك',style:TextStyle(fontWeight:FontWeight.w900)),
        actions: [
          IconButton(tooltip:'جمع الموارد',onPressed:_collect,icon:const Icon(Icons.savings_outlined)),
          PopupMenuButton<String>(
            onSelected:(v) async {
              if(v=='save'){await _persist();_toast('تم حفظ تقدمك');}
              if(v=='reset'){
                final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
                  title:const Text('إعادة المملكة؟'),
                  content:const Text('سيتم حذف التقدم المحلي الحالي.'),
                  actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('إعادة'))],
                ));
                if(yes==true){s.reset();await _persist();_toast('بدأت مملكة جديدة');}
              }
            },
            itemBuilder:(_)=>const [
              PopupMenuItem(value:'save',child:Text('حفظ الآن')),
              PopupMenuItem(value:'reset',child:Text('إعادة البداية')),
            ],
          )
        ],
      ),
      body:SafeArea(child:pages[tab]),
      bottomNavigationBar:NavigationBar(
        selectedIndex:tab,
        onDestinationSelected:(v)=>setState(()=>tab=v),
        destinations:const [
          NavigationDestination(icon:Icon(Icons.castle_outlined),selectedIcon:Icon(Icons.castle),label:'قريتي'),
          NavigationDestination(icon:Icon(Icons.construction_outlined),selectedIcon:Icon(Icons.construction),label:'المباني'),
          NavigationDestination(icon:Icon(Icons.shield_outlined),selectedIcon:Icon(Icons.shield),label:'الجيش'),
          NavigationDestination(icon:Icon(Icons.map_outlined),selectedIcon:Icon(Icons.map),label:'الخريطة'),
          NavigationDestination(icon:Icon(Icons.flag_outlined),selectedIcon:Icon(Icons.flag),label:'المملكة'),
        ],
      ),
    );
  }

  Widget _resources() => Card(child:Padding(
    padding:const EdgeInsets.symmetric(vertical:12,horizontal:8),
    child:Wrap(spacing:4,runSpacing:12,alignment:WrapAlignment.spaceAround,children:[
      _resource('خشب',s.wood,Icons.forest,const Color(0xFFC28B54)),
      _resource('حجر',s.stone,Icons.landscape,const Color(0xFFB9C7CE)),
      _resource('حديد',s.iron,Icons.hardware,const Color(0xFFE48B79)),
      _resource('طعام',s.food,Icons.restaurant,const Color(0xFF76C78D)),
      _resource('ذهب',s.gold,Icons.monetization_on,GameTheme.gold),
    ]),
  ));
  Widget _resource(String label,int amount,IconData icon,Color color)=>SizedBox(width:60,child:Column(children:[
    Icon(icon,color:color,size:21),const SizedBox(height:4),
    Text('$amount',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:14)),
    Text(label,style:const TextStyle(fontSize:11,color:Colors.white70)),
  ]));

  Widget _village() => ListView(padding:const EdgeInsets.all(14),children:[
    _resources(),const SizedBox(height:12),
    Container(
      height:265,
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF527D55),Color(0xFF203A31)]),border:Border.all(color:GameTheme.gold.withOpacity(.5))),
      child:Stack(children:[
        const Positioned(top:14,left:0,right:0,child:Center(child:Text('مملكة الفجر',style:TextStyle(fontWeight:FontWeight.w900,fontSize:23)))),
        Positioned.fill(child:CustomPaint(painter:VillagePainter())),
        Positioned(left:20,top:70,child:_mapBuilding(Icons.forest,'المنشرة',const Color(0xFF7B5838))),
        Positioned(right:22,top:74,child:_mapBuilding(Icons.agriculture,'المزرعة',const Color(0xFF7A9B4D))),
        Positioned(left:42,bottom:26,child:_mapBuilding(Icons.shield,'الثكنة',const Color(0xFF647C9A))),
        Positioned(right:40,bottom:26,child:_mapBuilding(Icons.fort,'السور',const Color(0xFF9B8D79))),
        Positioned(left:0,right:0,top:74,child:Center(child:Container(width:108,height:108,decoration:BoxDecoration(color:const Color(0xFF273D4A),borderRadius:BorderRadius.circular(24),border:Border.all(color:GameTheme.gold,width:2),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.25),blurRadius:12)]),child:const Icon(Icons.castle,size:70,color:GameTheme.gold)))),
        Positioned(left:0,right:0,bottom:8,child:Center(child:Text('مبنى القيادة مستوى ${s.hall}',style:const TextStyle(fontWeight:FontWeight.bold)))),
      ]),
    ),
    const SizedBox(height:12),
    Card(child:ListTile(leading:const Icon(Icons.auto_awesome,color:GameTheme.gold),title:const Text('أهلًا أيها القائد'),subtitle:Text('قوة المملكة ${s.power} • إجمالي الجيش ${s.totalArmy} جندي'),trailing:IconButton(onPressed:_collect,icon:const Icon(Icons.add_circle,color:GameTheme.green)))),
    const SizedBox(height:12),
    Row(children:[
      Expanded(child:FilledButton.tonalIcon(onPressed:()=>setState(()=>tab=1),icon:const Icon(Icons.construction),label:const Text('تطوير'))),
      const SizedBox(width:8),
      Expanded(child:FilledButton.tonalIcon(onPressed:()=>setState(()=>tab=2),icon:const Icon(Icons.shield),label:const Text('الجيش'))),
    ]),
    const SizedBox(height:16),
    Text('نظرة سريعة',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
    const SizedBox(height:8),
    ...buildings.take(4).map((b)=>_buildingCard(b,compact:true)),
  ]);

  Widget _mapBuilding(IconData icon,String label,Color color)=>Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:47,height:43,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white30),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.25),blurRadius:5)]),child:Icon(icon,color:Colors.white,size:27)),
    const SizedBox(height:3),Text(label,style:const TextStyle(fontSize:10,fontWeight:FontWeight.bold,shadows:[Shadow(color:Colors.black,blurRadius:4)])),
  ]);

  Widget _buildingsPage()=>ListView(padding:const EdgeInsets.all(14),children:[
    Text('إدارة المباني',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
    const SizedBox(height:5),const Text('كل تطوير يرفع مستوى مبانيك وقدرات المملكة.',style:TextStyle(color:Colors.white70)),
    const SizedBox(height:12),_resources(),const SizedBox(height:12),
    if(s.upgradingId!=null)_upgradeTimerCard(),
    ...buildings.map((b)=>_buildingCard(b)),
  ]);

  Widget _buildingCard(BuildingInfo b,{bool compact=false}) {
    final active=s.upgradingId==b.id;
    final remaining=s.upgradeEndsAt?.difference(now).inSeconds ?? 0;
    final wc=b.woodCost*b.level, sc=b.stoneCost*b.level, ic=b.ironCost*b.level;
    return Card(margin:const EdgeInsets.only(bottom:9),child:Padding(padding:const EdgeInsets.all(13),child:Row(children:[
      Container(width:48,height:48,decoration:BoxDecoration(color:GameTheme.gold.withOpacity(.12),borderRadius:BorderRadius.circular(14)),child:Icon(b.icon,color:GameTheme.gold,size:27)),
      const SizedBox(width:11),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(b.name,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),
        Text('المستوى ${b.level} • ${b.description}',style:const TextStyle(color:Colors.white70,fontSize:11)),
        if(!compact) Text('🪵 $wc  🪨 $sc  ⚙️ $ic',style:const TextStyle(color:GameTheme.gold,fontSize:12)),
        if(active) Text('متبقي ${max(0,remaining)} ثانية',style:const TextStyle(color:GameTheme.green,fontWeight:FontWeight.bold)),
      ])),
      if(!compact)IconButton(onPressed:active?null:()=>_startUpgrade(b),icon:Icon(active?Icons.hourglass_top:Icons.upgrade,color:GameTheme.gold)),
    ])));
  }

  Widget _upgradeTimerCard()=>Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(
    leading:const Icon(Icons.hourglass_top,color:GameTheme.green),
    title:Text('تطوير ${buildings.where((b)=>b.id==s.upgradingId).isEmpty ? 'مبنى' : buildings.where((b)=>b.id==s.upgradingId).first.name}'),
    subtitle:Text('الوقت المتبقي: ${max(0,s.upgradeEndsAt?.difference(now).inSeconds ?? 0)} ثانية'),
  ));

  Widget _armyPage()=>ListView(padding:const EdgeInsets.all(14),children:[
    Text('الجيش والتدريب',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
    const SizedBox(height:12),_resources(),const SizedBox(height:12),
    Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),gradient:const LinearGradient(colors:[Color(0xFF263B4A),Color(0xFF18242D)])),child:Column(children:[
      const Icon(Icons.shield,size:68,color:GameTheme.gold),
      const Text('قوة جيشك',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      Text('${s.totalArmy} وحدة',style:const TextStyle(fontSize:31,fontWeight:FontWeight.w900,color:GameTheme.green)),
      Text('قوة قتالية: ${s.power}',style:const TextStyle(color:Colors.white70)),
    ])),
    const SizedBox(height:12),
    _unitCard('مشاة',Icons.shield,s.soldiers,'35 خشب • 15 حديد • 45 طعام',()=>_train('مشاة')),
    _unitCard('رماة',Icons.gps_fixed,s.archers,'45 خشب • 20 حديد • 35 طعام',()=>_train('رماة')),
    _unitCard('فرسان',Icons.directions_run,s.cavalry,'70 خشب • 45 حديد • 60 طعام',()=>_train('فرسان')),
    const SizedBox(height:12),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('معركة تدريبية',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      const SizedBox(height:6),const Text('اختبر قوة جيشك ضد حامية افتراضية واحصل على غنائم عند الفوز.',style:TextStyle(color:Colors.white70)),
      const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_battle,icon:const Icon(Icons.sports_martial_arts),label:const Text('بدء المعركة'))),
      const SizedBox(height:8),Text('انتصارات ${s.battlesWon} • هزائم ${s.battlesLost}',style:const TextStyle(color:GameTheme.gold)),
    ]))),
  ]);

  Widget _unitCard(String name,IconData icon,int count,String cost,VoidCallback train)=>Card(margin:const EdgeInsets.only(bottom:9),child:ListTile(
    leading:CircleAvatar(backgroundColor:GameTheme.gold.withOpacity(.12),child:Icon(icon,color:GameTheme.gold)),
    title:Text(name,style:const TextStyle(fontWeight:FontWeight.bold)),
    subtitle:Text('$count وحدة • $cost',style:const TextStyle(fontSize:11,color:Colors.white70)),
    trailing:FilledButton.tonal(onPressed:train,child:const Text('تدريب')),
  ));

  Widget _worldPage()=>ListView(padding:const EdgeInsets.all(14),children:[
    Text('خريطة المملكة',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
    const SizedBox(height:8),
    const Text('خريطة تجريبية محلية. مواقع الممالك الأخرى هنا رموز تدريبية وليست لاعبين متصلين.',style:TextStyle(color:Colors.white70)),
    const SizedBox(height:12),
    Container(height:340,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:Border.all(color:GameTheme.gold.withOpacity(.35))),child:CustomPaint(painter:WorldPainter(),child:Stack(children:[
      Positioned(top:14,right:14,child:_mapLabel('مملكتك',Icons.castle,GameTheme.gold)),
      Positioned(top:85,left:22,child:_mapLabel('قلعة الشمال',Icons.castle,Colors.lightBlueAccent)),
      Positioned(bottom:78,right:20,child:_mapLabel('حصن الرمال',Icons.fort,Colors.orangeAccent)),
      Positioned(bottom:20,left:18,child:_mapLabel('غابة الظلال',Icons.forest,GameTheme.green)),
    ]))),
    const SizedBox(height:12),
    Card(child:ListTile(leading:const Icon(Icons.public,color:GameTheme.gold),title:const Text('العالم المشترك'),subtitle:const Text('لإظهار لاعبين حقيقيين ومعارك عبر الإنترنت يلزم خادم وقاعدة بيانات واتصال API. هذه النسخة تحفظ التقدم على جهازك فقط.'))),
  ]);
  Widget _mapLabel(String label,IconData icon,Color color)=>Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:GameTheme.bg.withOpacity(.85),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(.8))),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:color,size:18),const SizedBox(width:5),Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold))]));

  Widget _kingdomPage()=>ListView(padding:const EdgeInsets.all(14),children:[
    Text('إحصائيات المملكة',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
    const SizedBox(height:12),
    Card(child:Column(children:[
      ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(s.rulerName),subtitle:const Text('قائد مملكة الفجر')),
      const Divider(height:1),
      _stat('قوة المملكة','${s.power}',Icons.bolt),
      _stat('إجمالي الجيش','${s.totalArmy}',Icons.shield),
      _stat('الانتصارات','${s.battlesWon}',Icons.emoji_events),
      _stat('الهزائم','${s.battlesLost}',Icons.flag),
      _stat('مرات جمع الموارد','${s.totalCollections}',Icons.savings),
    ])),
    const SizedBox(height:12),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('مهام يومية',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      const SizedBox(height:10),
      _mission('اجمع الموارد 3 مرات',s.totalCollections>=3,'مكافأة 30 خشب و30 طعام',()=>_claimMission(0)),
      _mission('درّب 5 وحدات',s.totalArmy>=17,'مكافأة 40 خشب و20 حديد',()=>_claimMission(1)),
      _mission('حقق انتصارًا',s.battlesWon>=1,'مكافأة 5 ذهب',()=>_claimMission(2)),
    ]))),
    const SizedBox(height:12),
    Card(child:ListTile(leading:const Icon(Icons.info_outline),title:const Text('حول النسخة'),subtitle:const Text('نسخة لعب فردي قابلة للتجربة، مع حفظ محلي. لا تتضمن حاليًا خادمًا متعدد اللاعبين أو مزامنة بين الأجهزة.'))),
  ]);

  Future<void> _claimMission(int id) async {
    // Claim state is stored via dailyMissionsClaimed as a simple bitmask.
    final bit = 1 << id;
    if ((s.dailyMissionsClaimed & bit) != 0) { _toast('استلمت مكافأة هذه المهمة بالفعل اليوم.'); return; }
    final available = id==0 ? s.totalCollections>=3 : id==1 ? s.totalArmy>=17 : s.battlesWon>=1;
    if(!available){_toast('أكمل المهمة أولًا.');return;}
    s.dailyMissionsClaimed |= bit;
    if(id==0){s.wood+=30;s.food+=30;}
    if(id==1){s.wood+=40;s.iron+=20;}
    if(id==2){s.gold+=5;}
    await _persist();
    _toast('تم استلام مكافأة المهمة!');
  }

  Widget _mission(String title,bool complete,String reward,VoidCallback claim)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[
    Icon(complete?Icons.check_circle:Icons.radio_button_unchecked,color:complete?GameTheme.green:Colors.white38),
    const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),Text(reward,style:const TextStyle(color:Colors.white60,fontSize:11))])),
    TextButton(onPressed:claim,child:const Text('استلام')),
  ]));
  Widget _stat(String label,String value,IconData icon)=>ListTile(leading:Icon(icon,color:GameTheme.gold),title:Text(label),trailing:Text(value,style:const TextStyle(fontWeight:FontWeight.w900,color:GameTheme.green)));
}

class BuildingInfo {
  BuildingInfo(this.id,this.name,this.description,this.icon,this.woodCost,this.stoneCost,this.ironCost,this.seconds,this.level,this._levelUp);
  final String id,name,description;
  final IconData icon;
  final int woodCost,stoneCost,ironCost,seconds;
  int level;
  final VoidCallback _levelUp;
  void levelUp()=>_levelUp();
}

class VillagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas,Size size) {
    final p=Paint()..style=PaintingStyle.fill;
    // stylized paths and plots to give the village scene a lightweight game-map feel
    p.color=const Color(0xFF8DAE65);
    final path=Path()..moveTo(size.width*.5,size.height*.18)..lineTo(size.width*.94,size.height*.52)..lineTo(size.width*.5,size.height*.88)..lineTo(size.width*.06,size.height*.52)..close();
    canvas.drawPath(path,p);
    p.color=const Color(0xFFB9A77C);
    final road=Path()..moveTo(size.width*.48,size.height*.43)..lineTo(size.width*.52,size.height*.43)..lineTo(size.width*.86,size.height*.9)..lineTo(size.width*.76,size.height*.9)..close();
    canvas.drawPath(road,p);
    p.color=const Color(0xFF3D6947);
    for(int i=0;i<18;i++){
      final x=(i*47.0+17)%max(1,size.width);
      final y=(i*29.0+22)%max(1,size.height);
      if((x-size.width*.5).abs()<75 && y>70 && y<size.height-40) continue;
      canvas.drawCircle(Offset(x,y),4+(i%3)*1.5,p);
    }
    p.color=const Color(0xFFDFD0A8);
    for(int i=0;i<5;i++){
      final x=size.width*.2+i*size.width*.14;
      canvas.drawOval(Rect.fromCenter(center:Offset(x,size.height*.57),width:28,height:10),p);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class WorldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas,Size size) {
    final p=Paint()..style=PaintingStyle.fill;
    p.color=const Color(0xFF294C3A);canvas.drawRect(Offset.zero&size,p);
    final rnd=Random(7);
    for(int i=0;i<150;i++){
      final x=rnd.nextDouble()*size.width,y=rnd.nextDouble()*size.height;
      p.color=[const Color(0xFF355F43),const Color(0xFF3C6748),const Color(0xFF4A744B)][i%3];
      canvas.drawCircle(Offset(x,y),2+rnd.nextDouble()*7,p);
    }
    p.color=const Color(0xFFB5A17A);
    final road=Path()..moveTo(0,size.height*.52)..cubicTo(size.width*.3,size.height*.35,size.width*.62,size.height*.74,size.width,size.height*.43);
    p.style=PaintingStyle.stroke;p.strokeWidth=9;canvas.drawPath(road,p);
    p.color=const Color(0xFF657D8A);p.strokeWidth=3;
    final river=Path()..moveTo(size.width*.15,0)..cubicTo(size.width*.32,size.height*.25,size.width*.08,size.height*.7,size.width*.35,size.height);
    canvas.drawPath(river,p);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}