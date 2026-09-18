import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vedic_panchanga_dart/vedic_panchanga_dart.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PanchangaService.initialize(ayanamsaMode: 'LAHIRI');
  runApp(const SbcTransitApp());
}

class SbcTransitApp extends StatelessWidget {
  const SbcTransitApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SBC Transit',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const HomePage(),
  );
}

const nakshatras = <String>[
  'Ashwini','Bharani','Krittika','Rohini','Mrigashira','Ardra','Punarvasu',
  'Pushya','Ashlesha','Magha','Purva Phalguni','Uttara Phalguni','Hasta',
  'Chitra','Swati','Vishakha','Anuradha','Jyeshtha','Mula','Purva Ashadha',
  'Uttara Ashadha','Shravana','Dhanishtha','Shatabhisha','Purva Bhadrapada',
  'Uttara Bhadrapada','Revati'
];

const planetOrder = <String>[
  'Sun','Moon','Mars','Mercury','Jupiter','Venus','Saturn','Rahu','Ketu'
];

class PlanetTransit {
  final String name;
  final double longitude;
  final double speed;
  final bool retrograde;
  final String nakshatra;
  final int pada;
  PlanetTransit({
    required this.name, required this.longitude, required this.speed,
    required this.retrograde, required this.nakshatra, required this.pada,
  });
}

class VedhaRule {
  final String front, right, left;
  VedhaRule(this.front, this.right, this.left);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final place = Place('India', 26.2389, 73.0243, 5.5);
  DateTime selected = DateTime.now();
  bool loading = true;
  String error = '';
  List<PlanetTransit> planets = [];
  Map<String, VedhaRule> rules = {};
  late TabController tabs;

  @override void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
    loadRules().then((_) => calculate());
  }

  Future<void> loadRules() async {
    final raw = await rootBundle.loadString('lib/data/sbc_rules.json');
    final list = jsonDecode(raw) as List;
    for (final x in list) {
      final m = x as Map<String,dynamic>;
      rules['${m["nakshatra"]}|${m["pada"]}'] =
        VedhaRule(m['front'], m['right'], m['left']);
    }
  }

  String nakshatraFor(double longitude) {
    final x = (longitude % 360 + 360) % 360;
    final n = (x / (360 / 27)).floor().clamp(0,26);
    return nakshatras[n];
  }

  int padaFor(double longitude) {
    final x = (longitude % 360 + 360) % 360;
    final within = x % (360 / 27);
    return (within / (360 / 108)).floor() + 1;
  }

  Future<void> calculate() async {
    setState(() { loading=true; error=''; });
    try {
      final jd = PanchangaUtils.gregorianToJd(
        selected.year, selected.month, selected.day,
        hour: selected.hour, minute: selected.minute, second: selected.second);
      final raw = PanchangaService.planetPositions(jd, place);
      final out=<PlanetTransit>[];
      for (final p in raw) {
        // PlanetPosition from vedic_panchanga_dart exposes these fields.
        final name = p.name.toString();
        final lon = (p.longitude as num).toDouble();
        out.add(PlanetTransit(
          name: name,
          longitude: lon,
          speed: (p.speed as num).toDouble(),
          retrograde: p.retrograde == true,
          nakshatra: nakshatraFor(lon),
          pada: padaFor(lon),
        ));
      }
      out.sort((a,b) {
        final ai=planetOrder.indexOf(a.name), bi=planetOrder.indexOf(b.name);
        return (ai<0?99:ai).compareTo(bi<0?99:bi);
      });
      setState(() { planets=out; loading=false; });
    } catch(e) {
      setState(() { error=e.toString(); loading=false; });
    }
  }

  List<Map<String,String>> vedhasFor(PlanetTransit p) {
    final rule=rules['${p.nakshatra}|${p.pada}'];
    if (rule==null) return [];
    return [
      {'direction':'Front','nakshatra':rule.front},
      {'direction':'Right','nakshatra':rule.right},
      {'direction':'Left','nakshatra':rule.left},
    ];
  }

  List<String> planetsIn(String nak) =>
    planets.where((p)=>p.nakshatra==nak).map((p)=>'${p.name} P${p.pada}').toList();

  @override void dispose(){tabs.dispose();super.dispose();}

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sarvatobhadra Transit'),
      actions:[IconButton(onPressed:calculate, icon:const Icon(Icons.refresh))],
      bottom: TabBar(controller:tabs,tabs:const[
        Tab(text:'आज का Transit'), Tab(text:'Search')
      ]),
    ),
    body: TabBarView(controller:tabs,children:[
      buildToday(), buildSearch()
    ]),
  );

  Widget buildToday() {
    if(loading) return const Center(child:CircularProgressIndicator());
    if(error.isNotEmpty) return Center(child:Padding(
      padding:const EdgeInsets.all(20), child:Text('Calculation error:\n$error')));
    return ListView(
      padding:const EdgeInsets.all(12),
      children:[
        Card(child:ListTile(
          title:Text('Sidereal • Lahiri • ${selected.day}-${selected.month}-${selected.year}'),
          subtitle:Text('Calculation location: ${place.name} • UTC +${place.timezone}'),
          trailing:IconButton(icon:const Icon(Icons.calendar_month),onPressed:pickDate),
        )),
        const Padding(padding:EdgeInsets.only(top:8,bottom:4),
          child:Text('Planet → Nakshatra → Pada',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),
        ...planets.map(buildPlanetCard),
      ],
    );
  }

  Widget buildPlanetCard(PlanetTransit p) {
    final vh=vedhasFor(p);
    final targets=<String>{...vh.map((x)=>x['nakshatra']!)};
    return Card(
      child:ExpansionTile(
        leading:CircleAvatar(child:Text(p.name.isEmpty?'?':p.name[0])),
        title:Text('${p.name} • ${p.nakshatra} Pada ${p.pada}'),
        subtitle:Text('${p.longitude.toStringAsFixed(4)}°  ${p.retrograde?'Retrograde':'Direct'}'),
        children:[
          if(vh.isEmpty) const ListTile(title:Text('इस Pada के लिए loaded SBC rule उपलब्ध नहीं है.')),
          ...vh.map((v){
            final occupants=planetsIn(v['nakshatra']!);
            return ListTile(
              title:Text('${v["direction"]} Vedha → ${v["nakshatra"]}'),
              subtitle:Text(occupants.isEmpty
                ? 'इस Nakshatra में अभी कोई transit planet नहीं'
                : 'वहाँ: ${occupants.join(", ")}'),
            );
          }),
          if(targets.isNotEmpty) Padding(
            padding:const EdgeInsets.fromLTRB(16,0,16,12),
            child:Text('Detail: Vedha target Nakshatra में कौन है, ऊपर दिखाया गया है.')),
        ],
      ),
    );
  }

  Widget buildSearch() => SearchPane(
    planets:planets, rules:rules, onRefresh:calculate,
    nakshatraFor:nakshatraFor, padaFor:padaFor,
  );

  Future<void> pickDate() async {
    final d=await showDatePicker(context:context,firstDate:DateTime(1900),lastDate:DateTime(2100),initialDate:selected);
    if(d!=null){ setState(()=>selected=DateTime(d.year,d.month,d.day,selected.hour,selected.minute)); calculate(); }
  }
}

class SearchPane extends StatefulWidget {
  final List<PlanetTransit> planets;
  final Map<String,VedhaRule> rules;
  final VoidCallback onRefresh;
  final String Function(double) nakshatraFor;
  final int Function(double) padaFor;
  const SearchPane({super.key,required this.planets,required this.rules,required this.onRefresh,
    required this.nakshatraFor,required this.padaFor});
  @override State<SearchPane> createState()=>_SearchPaneState();
}

class _SearchPaneState extends State<SearchPane>{
  final q=TextEditingController();
  String query='';
  @override Widget build(BuildContext context){
    final allPlanets=widget.planets.where((p){
      final s='${p.name} ${p.nakshatra} ${p.pada} ${p.longitude}'.toLowerCase();
      return query.isEmpty || s.contains(query.toLowerCase());
    }).toList();
    final nakMatches=nakshatras.where((n)=>query.isNotEmpty && n.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(padding:const EdgeInsets.all(12),children:[
      TextField(controller:q,decoration:InputDecoration(
        labelText:'Planet / Nakshatra / Pada खोजें',
        prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(icon:const Icon(Icons.clear),onPressed:()=>setState(()=>{q.clear(),query=''})) ),
        onChanged:(v)=>setState(()=>query=v)),
      const SizedBox(height:12),
      if(query.isNotEmpty) ...[
        const Text('Planet results',style:TextStyle(fontWeight:FontWeight.bold)),
        ...allPlanets.map((p)=>ListTile(
          title:Text('${p.name} → ${p.nakshatra} Pada ${p.pada}'),
          subtitle:Text('Longitude ${p.longitude.toStringAsFixed(4)}°'),
        )),
        const SizedBox(height:8),
        const Text('Nakshatra results',style:TextStyle(fontWeight:FontWeight.bold)),
        ...nakMatches.map((n){
          final occ=widget.planets.where((p)=>p.nakshatra==n).toList();
          return Card(child:ExpansionTile(
            title:Text(n),subtitle:Text(occ.isEmpty?'No transit planet':'${occ.length} planet(s)'),
            children:occ.map((p)=>ListTile(title:Text('${p.name} • Pada ${p.pada}'))).toList(),
          ));
        }),
      ] else const Padding(
        padding:EdgeInsets.all(24),child:Text('उदाहरण: "Jyeshtha", "Ashwini", "Moon", या "P1" लिखें.')),
    ]);
  }
}
